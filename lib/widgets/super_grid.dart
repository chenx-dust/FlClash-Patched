import 'dart:async';
import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/activate_box.dart';
import 'package:fl_clash/widgets/card.dart';
import 'package:fl_clash/widgets/grid.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Kept in one notifier so a builder that reads part of it also rebuilds when
/// the rest changes.
typedef _DragState = ({int index, Size size, bool landing});

const _idleDrag = (index: -1, size: Size.zero, landing: false);

class SuperGrid extends StatefulWidget {
  final List<GridItem> children;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final int crossAxisCount;
  final VoidCallback? onUpdate;

  const SuperGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 1,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.onUpdate,
  });

  @override
  State<SuperGrid> createState() => SuperGridState();
}

class SuperGridState extends State<SuperGrid> with TickerProviderStateMixin {
  static const _reorderDuration = Duration(milliseconds: 420);
  static const _shakeDuration = Duration(milliseconds: 480);
  static const _reorderCurve = Cubic(0.22, 0.72, 0.24, 1.08);

  static const _hoverDelay = Duration(milliseconds: 120);

  /// Matches the default CommonCard shape, so the lift's shadow traces the card
  /// it is drawn behind.
  static const _cardShape = AppShape.md;

  late final ValueNotifier<List<GridItem>> _childrenNotifier;
  List<GridItem> children = [];
  List<GridItem>? _pendingChildren;

  List<GridItem> get snapshotChildren =>
      List<GridItem>.unmodifiable(_pendingChildren ?? children);

  int get length => _childrenNotifier.value.length;
  int get crossCount => widget.crossAxisCount;

  List<int> _tempIndexList = [];

  /// One stable key per slot, so item elements survive a reorder.
  final List<GlobalKey> _itemKeys = [];
  final List<FocusNode> _itemFocusNodes = [];

  Size _containerSize = Size.zero;
  int _targetIndex = -1;
  Offset _targetOffset = Offset.zero;
  List<Size> _sizes = [];
  List<Offset> _offsets = [];
  Offset _parentOffset = Offset.zero;

  EdgeDraggingAutoScroller? _edgeDraggingAutoScroller;
  Scrollable? _scrollable;
  Rect _dragRect = Rect.zero;
  bool _isDragging = false;
  Timer? _hoverTimer;

  final ValueNotifier<_DragState> _dragNotifier = ValueNotifier(_idleDrag);
  int? _heldIndex;
  int? _liftIndex;
  int? _topIndex;
  int? _fadeOutIndex;
  List<GridItem>? _heldOrigin;
  bool _heldMoved = false;

  late AnimationController _transformController;
  late CurvedAnimation _reorderCurveAnimation;
  late AnimationController _liftController;
  Map<int, Animation<Offset>> _transformAnimationMap = {};

  Future<bool> get isTransformCompleter =>
      _transformCompleter?.future ?? Future<bool>.value(true);
  Completer<bool>? _transformCompleter;

  late AnimationController _landingController;
  Animation<Offset>? _landingAnimation;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    children = List<GridItem>.of(widget.children);
    _childrenNotifier = ValueNotifier(children)
      ..addListener(_handleChildrenChanged);
    _tempIndexList = List.generate(length, (index) => index);
    _syncItemKeys();

    _landingController = AnimationController.unbounded(vsync: this);

    _shakeController = AnimationController(
      vsync: this,
      duration: _shakeDuration,
    )..repeat();

    _transformController = AnimationController(
      vsync: this,
      duration: _reorderDuration,
    )..addStatusListener(_handleReorderStatus);
    _reorderCurveAnimation = CurvedAnimation(
      parent: _transformController,
      curve: _reorderCurve,
    );
    _liftController = AnimationController(vsync: this, duration: midDuration)
      ..addStatusListener(_handleLiftStatus);
    _resetDragState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final scrollable = context.findAncestorWidgetOfExactType<Scrollable>();
    if (scrollable == null) {
      _stopAutoScroll();
      _scrollable = null;
      _edgeDraggingAutoScroller = null;
      return;
    }
    if (_scrollable == scrollable) {
      return;
    }
    _stopAutoScroll();
    _scrollable = scrollable;
    late final EdgeDraggingAutoScroller autoScroller;
    autoScroller = EdgeDraggingAutoScroller(
      Scrollable.of(context),
      onScrollViewScrolled: () {
        if (!mounted ||
            !_isDragging ||
            !identical(_edgeDraggingAutoScroller, autoScroller)) {
          return;
        }
        autoScroller.startAutoScrollIfNecessary(_dragRect);
      },
      velocityScalar: 40,
    );
    _edgeDraggingAutoScroller = autoScroller;
  }

  @override
  void dispose() {
    _isDragging = false;
    _stopAutoScroll();
    _edgeDraggingAutoScroller = null;
    _scrollable = null;
    _hoverTimer?.cancel();
    _hoverTimer = null;
    final completer = _transformCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
    _transformCompleter = null;
    _childrenNotifier.removeListener(_handleChildrenChanged);
    _childrenNotifier.value = const [];
    children = const [];
    _pendingChildren = null;
    _itemKeys.clear();
    for (final node in _itemFocusNodes) {
      node.dispose();
    }
    _itemFocusNodes.clear();
    _sizes = [];
    _offsets = [];
    _transformAnimationMap.clear();
    _landingAnimation = null;
    _reorderCurveAnimation.dispose();
    _liftController.dispose();
    _landingController.dispose();
    _shakeController.dispose();
    _transformController.dispose();
    _dragNotifier.dispose();
    _childrenNotifier.dispose();
    super.dispose();
  }

  void handleAdd(GridItem gridItem) {
    _clearHold();
    _lowerLift();
    _topIndex = null;
    _childrenNotifier.value = [..._childrenNotifier.value, gridItem];
  }

  bool get isHolding => _heldIndex != null;

  /// Restores the order from before the keyboard hold. Returns false when
  /// nothing is held, so the edit layer can exit instead.
  bool cancelHeldMove() {
    final origin = _heldOrigin;
    final held = _heldIndex;
    if (held == null || origin == null) {
      return false;
    }
    final item = _childrenNotifier.value[held];
    final restoreIndex = origin.indexOf(item);
    _clearHold();
    if (restoreIndex >= 0) {
      _liftIndex = restoreIndex;
      _topIndex = restoreIndex;
    }
    _lowerLift();
    _slideChildren(List<GridItem>.of(origin));
    if (!_transformController.isAnimating) {
      setState(() => _topIndex = null);
    }
    if (restoreIndex >= 0) {
      _requestSlotFocus(restoreIndex);
    }
    return true;
  }

  void _clearHold() {
    _heldIndex = null;
    _heldOrigin = null;
    _heldMoved = false;
  }

  void _handleReorderStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted || _heldIndex != null) {
      return;
    }
    if (_topIndex == null) {
      return;
    }
    setState(() => _topIndex = null);
  }

  void _handleLiftStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted || _heldIndex != null) {
      return;
    }
    if (_liftIndex == null) {
      return;
    }
    setState(() => _liftIndex = null);
  }

  void _raiseLift(int index) {
    _liftIndex = index;
    _liftController.forward();
  }

  void _lowerLift() {
    if (_liftController.value == 0) {
      _liftIndex = null;
      return;
    }
    _liftController.reverse();
  }

  bool _ensureSlotMetrics() {
    if (_transformController.isAnimating &&
        _sizes.length == length &&
        _offsets.length == length &&
        !_containerSize.isEmpty) {
      return true;
    }
    return _captureLayout();
  }

  /// Commits [next] immediately and slides from the pixels on screen, so a
  /// second move can start from the in-flight translation.
  void _slideChildren(List<GridItem> next) {
    final current = _childrenNotifier.value;
    if (!listEquals(current, next)) {
      if (_ensureSlotMetrics() &&
          _sizes.length == current.length &&
          _offsets.length == current.length) {
        final visuals = <GridItem, Offset>{
          for (var i = 0; i < current.length; i++)
            current[i]:
                _offsets[i] + (_transformAnimationMap[i]?.value ?? Offset.zero),
        };
        final sizes = <GridItem, Size>{
          for (var i = 0; i < current.length; i++) current[i]: _sizes[i],
        };
        final nextSizes = [for (final item in next) sizes[item]!];
        final geometry = _packSlots(next, nextSizes);
        final newOffsets = <Offset>[
          for (final slot in geometry.slots)
            Offset(slot.crossAxisIndex * geometry.stride, slot.mainAxisOffset),
        ];
        final map = <int, Animation<Offset>>{};
        for (var i = 0; i < next.length; i++) {
          final begin = visuals[next[i]]! - newOffsets[i];
          if (begin.distance < 0.5) {
            continue;
          }
          map[i] = Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(_reorderCurveAnimation);
        }
        _offsets = newOffsets;
        _sizes = nextSizes;
        _transformAnimationMap = map;
        if (map.isNotEmpty) {
          _transformController.forward(from: 0);
        } else {
          _transformController.value = 0;
        }
      } else {
        _transformAnimationMap = {};
      }
    }
    _childrenNotifier.value = next;
  }

  void _stopAutoScroll() {
    _edgeDraggingAutoScroller?.stopAutoScroll();
  }

  void _handleChildrenChanged() {
    children = List<GridItem>.of(_childrenNotifier.value);
    _tempIndexList = List.generate(length, (index) => index);
    _syncItemKeys();
    widget.onUpdate?.call();
  }

  /// Grows or trims [_itemKeys] without replacing existing entries, so a slot
  /// keeps its key across reorders and its element is never rebuilt.
  void _syncItemKeys() {
    while (_itemKeys.length < length) {
      _itemKeys.add(
        GlobalKey(debugLabel: 'super_grid_item_${_itemKeys.length}'),
      );
    }
    while (_itemFocusNodes.length < length) {
      _itemFocusNodes.add(FocusNode());
    }
    while (_itemFocusNodes.length > length) {
      _itemFocusNodes.removeLast().dispose();
    }
    if (_itemKeys.length > length) {
      _itemKeys.removeRange(length, _itemKeys.length);
    }
  }

  void _resetDragState() {
    _transformController.value = 0;
    _sizes = List.generate(length, (index) => Size.zero);
    _offsets = [];
    _transformAnimationMap.clear();
    _containerSize = Size.zero;
    _dragNotifier.value = _idleDrag;
    _targetOffset = Offset.zero;
    _parentOffset = Offset.zero;
    _dragRect = Rect.zero;
    _targetIndex = -1;
  }

  bool _captureLayout() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }
    if (_itemKeys.length != length) {
      return false;
    }
    final parentOffset = renderObject.localToGlobal(Offset.zero);
    final sizes = <Size>[];
    final offsets = <Offset>[];
    for (final key in _itemKeys) {
      final itemRenderObject = key.currentContext?.findRenderObject();
      if (itemRenderObject is! RenderBox || !itemRenderObject.hasSize) {
        return false;
      }
      sizes.add(itemRenderObject.size);
      offsets.add(itemRenderObject.localToGlobal(Offset.zero) - parentOffset);
    }
    _sizes = sizes;
    _offsets = offsets;
    _parentOffset = parentOffset;
    _containerSize = renderObject.size;
    return true;
  }

  GridGeometry _packSlots(List<GridItem> items, List<Size> sizes) {
    return packGridSlots(
      crossAxisCellCounts: [for (final item in items) item.crossAxisCellCount],
      mainAxisExtents: [for (final size in sizes) size.height],
      crossAxisCount: crossCount,
      crossAxisExtent: _containerSize.width,
      crossAxisSpacing: widget.crossAxisSpacing,
      mainAxisSpacing: widget.mainAxisSpacing,
    );
  }

  Future<bool> _transform() async {
    if (_sizes.length != length ||
        _offsets.length != length ||
        _containerSize.isEmpty) {
      return false;
    }
    final items = _childrenNotifier.value;
    final geometry = _packSlots(
      [for (final index in _tempIndexList) items[index]],
      [for (final index in _tempIndexList) _sizes[index]],
    );

    final transformAnimationMap = <int, Animation<Offset>>{};
    for (var slotIndex = 0; slotIndex < _tempIndexList.length; slotIndex++) {
      final index = _tempIndexList[slotIndex];
      final slot = geometry.slots[slotIndex];
      final nextOffset = Offset(
        slot.crossAxisIndex * geometry.stride,
        slot.mainAxisOffset,
      );
      if (slotIndex == _targetIndex) {
        _targetOffset = nextOffset;
      }
      transformAnimationMap[index] = Tween<Offset>(
        // Continue from where the item is, so an interrupted reorder does not
        // jump back to its resting place.
        begin: _transformAnimationMap[index]?.value ?? Offset.zero,
        end: nextOffset - _offsets[index],
      ).animate(_reorderCurveAnimation);
    }
    _transformAnimationMap = transformAnimationMap;

    try {
      await _transformController.forward(from: 0).orCancel;
      return true;
    } on TickerCanceled {
      return false;
    }
  }

  void _handleDragStarted(int index) {
    _clearHold();
    _liftController.stop();
    _liftIndex = null;
    _topIndex = null;
    _resetDragState();
    if (!_captureLayout()) {
      return;
    }
    _isDragging = true;
    _targetIndex = index;
    _targetOffset = _offsets[index];
    _dragNotifier.value = (index: index, size: _sizes[index], landing: false);
    _dragRect = Rect.fromLTWH(
      _targetOffset.dx + _parentOffset.dx,
      _targetOffset.dy + _parentOffset.dy,
      _sizes[index].width,
      _sizes[index].height,
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) {
      return;
    }
    _dragRect = _dragRect.shift(details.delta);
    _edgeDraggingAutoScroller?.startAutoScrollIfNecessary(_dragRect);
  }

  Future<void> _handleDragEnd(DraggableDetails details) async {
    _isDragging = false;
    _stopAutoScroll();
    _hoverTimer?.cancel();
    final dragIndex = _dragNotifier.value.index;
    if (_targetIndex < 0 ||
        _targetIndex >= length ||
        dragIndex < 0 ||
        dragIndex >= length) {
      _resetDragState();
      return;
    }

    final nextChildren = List<GridItem>.of(_childrenNotifier.value);
    nextChildren.insert(_targetIndex, nextChildren.removeAt(dragIndex));
    children = nextChildren;

    const tolerance = Tolerance(distance: 0.001, velocity: 0.01);
    const spring = SpringDescription(mass: 1, stiffness: 180, damping: 18);
    final simulation = SpringSimulation(spring, 0, 1, 0, tolerance: tolerance);
    _landingAnimation = Tween<Offset>(
      begin: details.offset - _parentOffset,
      end: _targetOffset,
    ).animate(_landingController);
    _dragNotifier.value = (
      index: dragIndex,
      size: _dragNotifier.value.size,
      landing: true,
    );

    final completer = Completer<bool>();
    _transformCompleter = completer;
    try {
      await _landingController.animateWith(simulation).orCancel;
      if (!mounted) {
        return;
      }
      _landingAnimation = null;
      _transformAnimationMap.clear();
      _childrenNotifier.value = nextChildren;
      _resetDragState();
      completer.complete(true);
    } on TickerCanceled {
      if (mounted) {
        _landingAnimation = null;
        _resetDragState();
      }
    } finally {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      if (identical(_transformCompleter, completer)) {
        _transformCompleter = null;
      }
    }
  }

  void _scheduleHover(int index) {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(_hoverDelay, () => _handleHover(index));
  }

  Future<void> _handleHover(int index) async {
    if (!mounted || !_isDragging) {
      return;
    }
    final dragIndex = _dragNotifier.value.index;
    if (dragIndex < 0 || dragIndex >= _offsets.length) {
      return;
    }
    final targetIndex = _tempIndexList.indexOf(index);
    if (targetIndex < 0 || _targetIndex == targetIndex) {
      return;
    }
    _tempIndexList = List.generate(length, (i) {
      if (i == targetIndex) return dragIndex;
      if (_targetIndex > targetIndex && i > targetIndex && i <= _targetIndex) {
        return _tempIndexList[i - 1];
      }
      if (_targetIndex < targetIndex && i >= _targetIndex && i < targetIndex) {
        return _tempIndexList[i + 1];
      }
      return _tempIndexList[i];
    });

    _targetIndex = targetIndex;

    await _transform();
  }

  Future<void> _handleDelete(int index) async {
    // One removal at a time: a second one would overwrite _pendingChildren and
    // cancel the first transform, silently dropping a deletion.
    if (_pendingChildren != null || _isDragging) {
      return;
    }
    _fadeOutIndex = null;
    _clearHold();
    _liftController.stop();
    _liftIndex = null;
    _topIndex = null;
    if (!_ensureSlotMetrics()) {
      setState(() {});
      return;
    }
    final slotIndex = _tempIndexList.indexOf(index);
    if (slotIndex < 0) {
      return;
    }
    _tempIndexList = List<int>.of(_tempIndexList)..removeAt(slotIndex);
    final nextChildren = List<GridItem>.of(_childrenNotifier.value)
      ..removeAt(index);
    _pendingChildren = nextChildren;
    final completed = await _transform();
    if (!completed || !mounted) {
      _pendingChildren = null;
      return;
    }
    _childrenNotifier.value = nextChildren;
    _pendingChildren = null;
    _resetDragState();
  }

  void _toggleHold(int index) {
    if (_isDragging || _pendingChildren != null || _fadeOutIndex != null) {
      return;
    }
    if (_heldIndex == null) {
      _heldOrigin = List<GridItem>.of(_childrenNotifier.value);
      _heldIndex = index;
      _heldMoved = false;
      _topIndex = index;
      _raiseLift(index);
      setState(() {});
      _requestSlotFocus(index);
      return;
    }
    if (_heldIndex != index) {
      return;
    }
    if (_heldMoved) {
      _clearHold();
      _lowerLift();
      if (!_transformController.isAnimating) {
        _topIndex = null;
      }
      setState(() {});
      return;
    }
    _clearHold();
    setState(() => _fadeOutIndex = index);
  }

  KeyEventResult _onGridKey(FocusNode node, KeyEvent event) {
    if (_heldIndex == null ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      _ => null,
    };
    if (direction == null) {
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    _moveHeld(direction);
    return KeyEventResult.handled;
  }

  void _moveHeld(TraversalDirection direction) {
    final from = _heldIndex;
    if (from == null) {
      return;
    }
    _heldMoved = true;
    final target = _neighborIndex(from, direction);
    if (target == null || target == from) {
      setState(() {});
      return;
    }
    final next = List<GridItem>.of(_childrenNotifier.value);
    final item = next[from];
    next[from] = next[target];
    next[target] = item;
    _heldIndex = target;
    _liftIndex = target;
    _topIndex = target;
    _slideChildren(next);
    _requestSlotFocus(target);
  }

  int? _neighborIndex(int from, TraversalDirection direction) {
    if (!_ensureSlotMetrics()) {
      return null;
    }
    final items = _childrenNotifier.value;
    final geometry = _packSlots(items, _sizes);
    if (from < 0 || from >= geometry.slots.length) {
      return null;
    }
    final heldSlot = geometry.slots[from];
    final heldCross = heldSlot.crossAxisIndex.toDouble();
    final heldSpan = items[from].crossAxisCellCount.clamp(1, crossCount);
    final heldMain = heldSlot.mainAxisOffset;
    final heldMainEnd = heldMain + _sizes[from].height;
    int? best;
    var bestPrimary = double.infinity;
    var bestSecondary = double.infinity;
    for (var index = 0; index < geometry.slots.length; index++) {
      if (index == from) {
        continue;
      }
      final slot = geometry.slots[index];
      final span = items[index].crossAxisCellCount.clamp(1, crossCount);
      final cross = slot.crossAxisIndex.toDouble();
      final crossEnd = cross + span;
      final main = slot.mainAxisOffset;
      final mainEnd = main + _sizes[index].height;
      final primary = switch (direction) {
        TraversalDirection.right => cross - (heldCross + heldSpan),
        TraversalDirection.left => heldCross - crossEnd,
        TraversalDirection.down => main - heldMainEnd,
        TraversalDirection.up => heldMain - mainEnd,
      };
      final secondary = switch (direction) {
        TraversalDirection.right ||
        TraversalDirection.left => (main - heldMain).abs(),
        TraversalDirection.down ||
        TraversalDirection.up => (cross - heldCross).abs(),
      };
      if (primary < -0.5) {
        continue;
      }
      if (primary < bestPrimary - 0.5 ||
          (primary <= bestPrimary + 0.5 && secondary < bestSecondary)) {
        best = index;
        bestPrimary = primary;
        bestSecondary = secondary;
      }
    }
    return best;
  }

  void _requestSlotFocus(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && index >= 0 && index < _itemFocusNodes.length) {
        _itemFocusNodes[index].requestFocus();
      }
    });
  }

  /// [t] is 1 while the item is held and eases to 0 as it settles, so the drag
  /// feedback and the landing widget are one surface at two depths.
  Widget _buildLiftedSurface(Widget child, double t) {
    return Transform.scale(
      scale: 1 + 0.03 * t,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: _cardShape,
          shadows: BoxShadow.lerpList(
            const <BoxShadow>[],
            kElevationToShadow[8]!,
            t.clamp(0.0, 1.0),
          )!,
        ),
        child: child,
      ),
    );
  }

  Widget _buildDragSizeBox(Widget child) {
    return ValueListenableBuilder(
      valueListenable: _dragNotifier,
      builder: (_, drag, child) {
        return SizedBox.fromSize(size: drag.size, child: child!);
      },
      child: child,
    );
  }

  Widget _buildTransform(Widget rawChild, int index) {
    return ValueListenableBuilder(
      valueListenable: _dragNotifier,
      builder: (_, drag, child) {
        // The landing widget paints it on the way home; hold its space open.
        if (drag.landing && drag.index == index) {
          return _buildDragSizeBox(const SizedBox.shrink());
        }
        return child!;
      },
      child: AnimatedBuilder(
        animation: _transformController.view,
        builder: (_, child) {
          return Transform.translate(
            offset: _transformAnimationMap[index]?.value ?? Offset.zero,
            child: child,
          );
        },
        child: rawChild,
      ),
    );
  }

  Widget _buildShake(Widget child, int index) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (_, child) {
        // An irregular phase step keeps neighbours from shaking in unison.
        final phase = index * 1.7;
        final angle = sin(_shakeController.value * 2 * pi + phase) * 0.01;
        return Transform.rotate(angle: angle, child: child!);
      },
      child: child,
    );
  }

  Widget _buildDraggable({
    required Widget childWhenDragging,
    required Widget feedback,
    required Widget item,
    required int index,
  }) {
    // onDragEnd resolves the drop from _targetIndex, so this target never
    // accepts; it only reports which item the pointer is over.
    final target = DragTarget<int>(
      builder: (_, _, _) {
        return AbsorbPointer(child: item);
      },
      onWillAcceptWithDetails: (_) {
        _scheduleHover(index);
        return false;
      },
    );

    final decoratedTarget = ValueListenableBuilder(
      valueListenable: _dragNotifier,
      builder: (_, drag, child) {
        if (drag.landing || drag.index == index) {
          return child!;
        }
        return _buildShake(
          _DeletableContainer(
            focusNode: _itemFocusNodes[index],
            content: item,
            showDelete: _heldIndex != index || !_heldMoved,
            deleteArmed: _heldIndex == index && !_heldMoved,
            fadeOut: _fadeOutIndex == index,
            onDelete: () {
              _handleDelete(index);
            },
            onActivate: () {
              _toggleHold(index);
            },
            child: AnimatedBuilder(
              animation: _liftController,
              builder: (context, child) {
                final t = _liftIndex == index
                    ? Curves.easeInOutCubic.transform(_liftController.value)
                    : 0.0;
                return _buildLiftedSurface(child!, t);
              },
              child: child,
            ),
          ),
          index,
        );
      },
      child: target,
    );

    void onDragStarted() => _handleDragStarted(index);
    void onDragUpdate(DragUpdateDetails details) => _handleDragUpdate(details);
    void onDragEnd(DraggableDetails details) => _handleDragEnd(details);

    return system.isDesktop
        ? Draggable(
            childWhenDragging: childWhenDragging,
            data: index,
            feedback: feedback,
            onDragStarted: onDragStarted,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
            child: decoratedTarget,
          )
        : LongPressDraggable(
            childWhenDragging: childWhenDragging,
            data: index,
            feedback: feedback,
            onDragStarted: onDragStarted,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
            child: decoratedTarget,
          );
  }

  Widget _builderItem(int index) {
    final gridItem = _childrenNotifier.value[index];
    final child = gridItem.child;
    // The children already render their own CommonCard; do not add a second.
    final childWhenDragging = ActivateBox(
      child: Opacity(opacity: 0.4, child: _buildDragSizeBox(child)),
    );
    final feedback = ActivateBox(
      child: _buildDragSizeBox(_buildLiftedSurface(child, 1)),
    );
    return GridItem(
      mainAxisCellCount: gridItem.mainAxisCellCount,
      crossAxisCellCount: gridItem.crossAxisCellCount,
      child: KeyedSubtree(
        key: _itemKeys[index],
        child: _buildTransform(
          // The shake never stops while edit mode is open, and without a
          // boundary here its markNeedsPaint reaches the scroll viewport, so
          // every frame repaints the whole grid instead of one item.
          RepaintBoundary(
            child: _buildDraggable(
              childWhenDragging: childWhenDragging,
              feedback: feedback,
              item: child,
              index: index,
            ),
          ),
          index,
        ),
      ),
    );
  }

  /// The dragged item springing back into the grid, drawn above it so it can
  /// overlap its neighbours on the way in.
  Widget _buildLandingWidget() {
    return ValueListenableBuilder(
      valueListenable: _dragNotifier,
      builder: (_, drag, _) {
        final animation = _landingAnimation;
        if (!drag.landing || animation == null || drag.index == -1) {
          return const SizedBox.shrink();
        }
        return SizedBox.fromSize(
          size: drag.size,
          child: AnimatedBuilder(
            animation: animation,
            builder: (_, child) {
              // Fade the lift out on the spring's own curve, so the item
              // settles instead of popping.
              final lift = (1 - _landingController.value).clamp(0.0, 1.0);
              return Transform.translate(
                offset: animation.value,
                child: _buildLiftedSurface(child!, lift),
              );
            },
            child: ActivateBox(
              child: _childrenNotifier.value[drag.index].child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onGridKey,
      child: DeferredPointerHandler(
        // Delete buttons sit outside their item's bounds and the landing widget
        // casts a shadow past the grid, so nothing here may be clipped.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ValueListenableBuilder(
              valueListenable: _dragNotifier,
              builder: (_, drag, child) {
                // Freeze interaction with the grid while an item is landing.
                return drag.landing ? ActivateBox(child: child!) : child!;
              },
              child: ValueListenableBuilder(
                valueListenable: _childrenNotifier,
                builder: (_, children, _) {
                  return Grid(
                    axisDirection: AxisDirection.down,
                    crossAxisCount: crossCount,
                    crossAxisSpacing: widget.crossAxisSpacing,
                    mainAxisSpacing: widget.mainAxisSpacing,
                    foregroundIndex: _topIndex,
                    children: [
                      for (int i = 0; i < children.length; i++) _builderItem(i),
                    ],
                  );
                },
              ),
            ),
            _buildLandingWidget(),
          ],
        ),
      ),
    );
  }
}

class _DeletableContainer extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;
  final Widget content;
  final bool showDelete;
  final bool deleteArmed;
  final bool fadeOut;
  final VoidCallback onDelete;
  final VoidCallback onActivate;

  const _DeletableContainer({
    required this.focusNode,
    required this.content,
    required this.showDelete,
    required this.deleteArmed,
    required this.fadeOut,
    required this.onDelete,
    required this.onActivate,
    required this.child,
  });

  @override
  State<_DeletableContainer> createState() => _DeletableContainerState();
}

class _DeletableContainerState extends State<_DeletableContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _deleting = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: midDuration);
    _scaleAnimation = Tween(
      begin: 1.0,
      end: 0.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _fadeAnimation = Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void didUpdateWidget(_DeletableContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A parent rebuild builds a new child widget. Only a different card resets.
    if (!identical(oldWidget.content, widget.content)) {
      setState(() {
        _controller.value = 0;
        _deleting = false;
      });
      return;
    }
    if (widget.fadeOut && !oldWidget.fadeOut) {
      unawaited(_handleDel());
    }
  }

  Future<void> _handleDel() async {
    if (_deleting) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await _controller.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) {
      return;
    }
    widget.onDelete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _controller.view,
          builder: (_, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(opacity: _fadeAnimation.value, child: child!),
            );
          },
          child: CardPressOverride(
            onPressed: widget.onActivate,
            focusNode: widget.focusNode,
            child: widget.child,
          ),
        ),
        if (!_deleting && widget.showDelete)
          Positioned(
            top: -8,
            right: -8,
            child: DeferPointer(
              child: ExcludeFocus(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: midDuration,
                          decoration: ShapeDecoration(
                            color: widget.deleteArmed || _hovered
                                ? context.colorScheme.error
                                : context.colorScheme.primary,
                            shape: AppShape.circle,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: context.appLocalizations.remove,
                        iconSize: 20,
                        padding: const EdgeInsets.all(2),
                        onHover: (hovered) {
                          if (_hovered == hovered) {
                            return;
                          }
                          setState(() => _hovered = hovered);
                        },
                        style: ButtonStyle(
                          animationDuration: midDuration,
                          backgroundColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                          overlayColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) =>
                                widget.deleteArmed ||
                                    states.contains(WidgetState.hovered)
                                ? context.colorScheme.onError
                                : context.colorScheme.onPrimary,
                          ),
                        ),
                        onPressed: _handleDel,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/widgets/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const Object snackBarHitMarker = Object();

const _actionMinDuration = Duration(seconds: 6);
const _maxBufferedMessages = 8;
const _mobileMaxVisibleMessages = 2;
const _desktopMaxVisibleMessages = 4;
const _messageEnterDuration = Duration(milliseconds: 500);
const _messageExitDuration = Duration(milliseconds: 400);
const _messageCollapseDuration = Duration(milliseconds: 200);
const _messageEnterOffset = Offset(0.32, 0);
const _messageMaxWidth = 500.0;
const _messageMinHeight = 54.0;

class StatusManager extends ConsumerStatefulWidget {
  final Widget child;

  const StatusManager({super.key, required this.child});

  @override
  ConsumerState<StatusManager> createState() => StatusManagerState();
}

class StatusManagerState extends ConsumerState<StatusManager> {
  final _entriesNotifier = ValueNotifier<List<_MessageEntry>>([]);
  final _bufferMessages = Queue<CommonMessage>();
  final _activeTimers = <String, Timer>{};
  final _hoveredIds = <String>{};
  final _expiredIds = <String>{};
  final _snackBarMessengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _draggingId;
  bool _hasFallbackSnackBar = false;
  int _snackBarRevision = 0;

  @override
  void dispose() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _hoveredIds.clear();
    _expiredIds.clear();
    _bufferMessages.clear();
    _entriesNotifier.dispose();
    super.dispose();
  }

  void showSnackBar(SnackBar snackBar) {
    final revision = ++_snackBarRevision;
    if (!_hasFallbackSnackBar) {
      setState(() {
        _hasFallbackSnackBar = true;
      });
    }
    final messenger = _snackBarMessengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger.removeCurrentSnackBar();
    final controller = messenger.showSnackBar(snackBar);
    unawaited(
      controller.closed.whenComplete(() {
        if (mounted && _snackBarRevision == revision && _hasFallbackSnackBar) {
          setState(() {
            _hasFallbackSnackBar = false;
          });
        }
      }),
    );
  }

  void clearSnackBar() {
    _snackBarRevision++;
    _snackBarMessengerKey.currentState?.removeCurrentSnackBar();
    if (_hasFallbackSnackBar && mounted) {
      setState(() {
        _hasFallbackSnackBar = false;
      });
    }
  }

  int get _maxVisibleMessages => ref.read(isMobileViewProvider)
      ? _mobileMaxVisibleMessages
      : _desktopMaxVisibleMessages;

  List<_MessageEntry> get _entries => _entriesNotifier.value;

  Iterable<_MessageEntry> get _visibleEntries =>
      _entries.where((entry) => entry.visible);

  void message(
    String text, {
    MessageLevel level = MessageLevel.info,
    MessageActionState? actionState,
    bool allowCopy = false,
  }) {
    if (text.isEmpty) {
      return;
    }
    final commonMessage = CommonMessage(
      id: uuidV4,
      text: text,
      level: level,
      duration: _resolveDuration(level, actionState),
      actionState: actionState,
      allowCopy: allowCopy,
    );
    commonPrint.log('message: $text');
    if (_mergeMessage(commonMessage)) {
      return;
    }
    _bufferMessages.add(commonMessage);
    _trimBuffer();
    _processQueue();
  }

  Duration _resolveDuration(
    MessageLevel level,
    MessageActionState? actionState,
  ) {
    final duration = level.duration;
    if (actionState == null || duration >= _actionMinDuration) {
      return duration;
    }
    return _actionMinDuration;
  }

  bool _isSameMessage(CommonMessage a, CommonMessage b) =>
      a.text == b.text && a.level == b.level;

  bool _mergeMessage(CommonMessage message) {
    final entries = _entries;
    final index = entries.indexWhere(
      (entry) => entry.visible && _isSameMessage(entry.message, message),
    );
    if (index != -1) {
      final merged = message.copyWith(id: entries[index].message.id);
      _entriesNotifier.value = List<_MessageEntry>.from(entries)
        ..[index] = entries[index].copyWith(message: merged);
      _expiredIds.remove(merged.id);
      _startTimer(merged);
      return true;
    }
    final buffered = _bufferMessages.toList(growable: false);
    final bufferedIndex = buffered.indexWhere(
      (item) => _isSameMessage(item, message),
    );
    if (bufferedIndex == -1) {
      return false;
    }
    buffered[bufferedIndex] = message.copyWith(id: buffered[bufferedIndex].id);
    _bufferMessages
      ..clear()
      ..addAll(buffered);
    return true;
  }

  void _trimBuffer() {
    while (_bufferMessages.length > _maxBufferedMessages) {
      final dropped =
          _bufferMessages.firstWhereOrNull(
            (message) => message.level != MessageLevel.error,
          ) ??
          _bufferMessages.first;
      _bufferMessages.remove(dropped);
    }
  }

  void _processQueue() {
    if (_draggingId != null) {
      return;
    }
    while (_bufferMessages.isNotEmpty) {
      final visible = _visibleEntries.toList();
      if (visible.length < _maxVisibleMessages) {
        _showMessage(_bufferMessages.removeFirst());
        continue;
      }
      final error = _bufferMessages.firstWhereOrNull(
        (message) => message.level == MessageLevel.error,
      );
      if (error == null) {
        return;
      }
      final preempted =
          visible.lastWhereOrNull(
            (entry) =>
                entry.message.level != MessageLevel.error &&
                !_hoveredIds.contains(entry.id),
          ) ??
          visible.lastWhereOrNull(
            (entry) => entry.message.level != MessageLevel.error,
          );
      if (preempted == null) {
        return;
      }
      _hideMessage(preempted.id);
      _bufferMessages.remove(error);
      _showMessage(error);
    }
  }

  void _showMessage(CommonMessage message) {
    _entriesNotifier.value = List<_MessageEntry>.from(_entries)
      ..insert(0, _MessageEntry(message: message, visible: true));
    _startTimer(message);
  }

  void _startTimer(CommonMessage message) {
    _activeTimers.remove(message.id)?.cancel();
    if (_draggingId != null) {
      return;
    }
    _activeTimers[message.id] = Timer(message.duration, () {
      _activeTimers.remove(message.id);
      if (_draggingId != null || _hoveredIds.isNotEmpty) {
        _expiredIds.add(message.id);
        return;
      }
      _hideMessage(message.id);
      _processQueue();
    });
  }

  void _hideMessage(String id, {bool swiped = false}) {
    _activeTimers.remove(id)?.cancel();
    _expiredIds.remove(id);
    _hoveredIds.remove(id);
    final entries = _entries;
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index == -1 || !entries[index].visible) {
      return;
    }
    _entriesNotifier.value = List<_MessageEntry>.from(entries)
      ..[index] = entries[index].copyWith(visible: false, swiped: swiped);
  }

  void _cancelMessage(String id, {bool swiped = false}) {
    if (_draggingId == id) {
      _draggingId = null;
    }
    _bufferMessages.removeWhere((message) => message.id == id);
    _hideMessage(id, swiped: swiped);
    _resumeTimers();
    _flushExpired();
    _processQueue();
  }

  void _flushExpired() {
    if (_draggingId != null || _hoveredIds.isNotEmpty || _expiredIds.isEmpty) {
      return;
    }
    final expired = _expiredIds.toList(growable: false);
    _expiredIds.clear();
    for (final id in expired) {
      _hideMessage(id);
    }
  }

  void _setHovering(String id, bool hovering) {
    if (hovering) {
      if (_visibleEntries.any((entry) => entry.id == id)) {
        _hoveredIds.add(id);
      }
      return;
    }
    if (!_hoveredIds.remove(id)) {
      return;
    }
    if (_hoveredIds.isEmpty && _draggingId == null) {
      _flushExpired();
      _processQueue();
    }
  }

  void _setDragging(String id, bool dragging) {
    if (dragging) {
      if (_draggingId == id) {
        return;
      }
      _draggingId = id;
      _expiredIds.clear();
      for (final timer in _activeTimers.values) {
        timer.cancel();
      }
      _activeTimers.clear();
      return;
    }
    if (_draggingId != id) {
      return;
    }
    _draggingId = null;
    _resumeTimers();
    _processQueue();
  }

  void _resumeTimers() {
    for (final entry in _visibleEntries.toList()) {
      if (_activeTimers.containsKey(entry.id)) {
        continue;
      }
      _startTimer(entry.message);
    }
  }

  void _removeMessage(String id) {
    if (!mounted) {
      return;
    }
    final entries = _entries;
    if (!entries.any((entry) => entry.id == id)) {
      return;
    }
    _entriesNotifier.value = entries
        .where((entry) => entry.id != id)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Offstage(
            offstage: !_hasFallbackSnackBar,
            child: IgnorePointer(
              ignoring: !_hasFallbackSnackBar,
              child: ScaffoldMessenger(
                key: _snackBarMessengerKey,
                child: const _SnackBarHitPassThrough(
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    primary: false,
                    resizeToAvoidBottomInset: false,
                  ),
                ),
              ),
            ),
          ),
        ),
        Consumer(
          builder: (_, ref, child) {
            final top = ref.watch(overlayTopOffsetProvider);
            return Container(
              margin: EdgeInsets.only(
                top: top + MediaQuery.viewPaddingOf(context).top + 8,
              ),
              child: child,
            );
          },
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ValueListenableBuilder(
                valueListenable: _entriesNotifier,
                builder: (_, entries, _) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final entry in entries)
                        _MessageTransition(
                          key: Key(entry.id),
                          visible: entry.visible,
                          swiped: entry.swiped,
                          onHidden: () => _removeMessage(entry.id),
                          child: _MessageCard(
                            message: entry.message,
                            onDismiss: _cancelMessage,
                            onDragging: _setDragging,
                            onHovering: _setHovering,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageEntry {
  const _MessageEntry({
    required this.message,
    required this.visible,
    this.swiped = false,
  });

  final CommonMessage message;
  final bool visible;
  final bool swiped;

  String get id => message.id;

  _MessageEntry copyWith({
    CommonMessage? message,
    bool? visible,
    bool? swiped,
  }) {
    return _MessageEntry(
      message: message ?? this.message,
      visible: visible ?? this.visible,
      swiped: swiped ?? this.swiped,
    );
  }
}

class _MessageTransition extends StatefulWidget {
  const _MessageTransition({
    super.key,
    required this.visible,
    required this.swiped,
    required this.onHidden,
    required this.child,
  });

  final bool visible;
  final bool swiped;
  final VoidCallback onHidden;
  final Widget child;

  @override
  State<_MessageTransition> createState() => _MessageTransitionState();
}

class _MessageTransitionState extends State<_MessageTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _size;
  late final CurvedAnimation _opacity;
  late final CurvedAnimation _slide;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _messageEnterDuration,
      reverseDuration: _messageExitDuration,
      vsync: this,
    )..addStatusListener(_handleAnimationStatus);
    _size = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.8, curve: Easing.emphasizedDecelerate),
      reverseCurve: const Interval(0, 0.65, curve: Easing.emphasizedAccelerate),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.4, curve: Curves.easeOut),
      reverseCurve: const Interval(0.5, 1, curve: Curves.easeIn),
    );
    _slide = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.85, curve: Easing.emphasizedDecelerate),
      reverseCurve: const Interval(0.45, 1, curve: Curves.easeInCubic),
    );
    _offset = _slide.drive(Tween(begin: _messageEnterOffset, end: Offset.zero));
    if (widget.visible) {
      _controller.forward();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.visible) {
        widget.onHidden();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _MessageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) {
      return;
    }
    if (widget.visible) {
      _controller.forward();
      return;
    }
    if (widget.swiped) {
      _size.reverseCurve = Easing.emphasizedAccelerate;
      _controller.reverseDuration = _messageCollapseDuration;
    }
    _controller.reverse();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !widget.visible) {
      widget.onHidden();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _size.dispose();
    _opacity.dispose();
    _slide.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: SizeTransition(
        sizeFactor: _size,
        alignment: AlignmentDirectional.topEnd,
        child: FadeTransition(
          opacity: _opacity,
          child: IgnorePointer(ignoring: !widget.visible, child: widget.child),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.onDismiss,
    required this.onDragging,
    required this.onHovering,
  });

  final CommonMessage message;
  final void Function(String id, {bool swiped}) onDismiss;
  final void Function(String id, bool dragging) onDragging;
  final void Function(String id, bool hovering) onHovering;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 8),
      child: MouseRegion(
        onEnter: (_) => onHovering(message.id, true),
        onExit: (_) => onHovering(message.id, false),
        child: Dismissible(
          key: ValueKey(message.id),
          resizeDuration: null,
          onUpdate: (details) {
            onDragging(message.id, details.progress > 0);
          },
          onDismissed: (_) {
            onDismiss(message.id, swiped: true);
          },
          child: Card(
            margin: EdgeInsets.zero,
            shape: AppShape.lg,
            clipBehavior: Clip.antiAlias,
            elevation: 6,
            color: message.level.containerColor(context),
            child: InkWell(
              onLongPress: message.allowCopy
                  ? () {
                      Clipboard.setData(ClipboardData(text: message.text));
                    }
                  : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _messageMinHeight,
                  maxWidth: _messageMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _MessageContent(
                    message: message,
                    onDismiss: onDismiss,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message, required this.onDismiss});

  final CommonMessage message;
  final void Function(String id, {bool swiped}) onDismiss;

  @override
  Widget build(BuildContext context) {
    final actionState = message.actionState;
    final level = message.level;
    final icon = level.icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: level.iconColor(context)),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(
            message.text,
            maxLines: 3,
            style: context.textTheme.labelLarge?.copyWith(
              color: level.contentColor(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionState != null) ...[
          const SizedBox(width: 16),
          CommonMinFilledButtonTheme(
            child: FilledButton.tonal(
              onPressed: () {
                onDismiss(message.id);
                actionState.action();
              },
              child: Text(actionState.actionText),
            ),
          ),
        ],
      ],
    );
  }
}

class _SnackBarHitPassThrough extends SingleChildRenderObjectWidget {
  const _SnackBarHitPassThrough({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSnackBarHitPassThrough();
  }
}

class _RenderSnackBarHitPassThrough extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final currentChild = child;
    if (!size.contains(position) || currentChild == null) {
      return false;
    }
    final probe = BoxHitTestResult();
    if (!currentChild.hitTest(probe, position: position)) {
      return false;
    }
    final hitSnackBar = probe.path.any((entry) {
      final target = entry.target;
      return target is RenderMetaData &&
          identical(target.metaData, snackBarHitMarker);
    });
    if (!hitSnackBar) {
      return false;
    }
    return currentChild.hitTest(result, position: position);
  }
}

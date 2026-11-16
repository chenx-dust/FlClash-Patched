import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/status_manager.dart';
import 'package:fl_clash/models/state.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _snackBarDuration = Duration(milliseconds: 1500);

extension BuildContextExtension on BuildContext {
  CommonScaffoldState? get commonScaffoldState {
    return findAncestorStateOfType<CommonScaffoldState>();
  }

  bool get isMobileView {
    return ProviderScope.containerOf(
      this,
      listen: false,
    ).read(isMobileViewProvider);
  }

  void safeNestedPop<T extends Object?>([T? result]) {
    final nestedPop = SheetProvider.of(this)?.nestedNavigatorPop;
    if (nestedPop != null) {
      return nestedPop(result);
    } else {
      return Navigator.of(this).pop(result);
    }
  }

  // This scaffold paints the app bar outside the body, so nothing overlays it.
  double get appBarInset => 0;

  double get sheetTopPadding {
    final sheetType = SheetProvider.of(this)!.type;
    if (sheetType == SheetType.bottomSheet) {
      return sheetAppBarHeight;
    } else {
      return 10;
    }
  }

  void showNotifier(
    String text, {
    MessageLevel level = MessageLevel.info,
    MessageActionState? actionState,
    bool allowCopy = false,
  }) {
    return findAncestorStateOfType<StatusManagerState>()?.message(
      text,
      level: level,
      actionState: actionState,
      allowCopy: allowCopy,
    );
  }

  void showSnackBar(String message, {SnackBarAction? action, bool? persist}) {
    final content = Text(message);
    final snackBar = (persist ?? action != null)
        ? _PersistentSnackBar(content: content, action: action)
        : _TimedSnackBar(
            content: content,
            action: action,
            deadline: _SnackBarDeadline(),
          );
    _presentSnackBar(this, snackBar);
  }

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  bool get disableAnimations => MediaQuery.disableAnimationsOf(this);

  Duration motionDuration(Duration duration) =>
      disableAnimations ? Duration.zero : duration;

  TextTheme get textTheme => Theme.of(this).textTheme;

  AppLocalizations get appLocalizations => AppLocalizations.of(this);

  T? findLastStateOfType<T extends State>() {
    T? state;

    void visitor(Element element) {
      if (!element.mounted) {
        return;
      }
      if (element is StatefulElement) {
        if (element.state is T) {
          state = element.state as T;
        }
      }
      element.visitChildren(visitor);
    }

    visitor(this as Element);
    return state;
  }
}

void _presentSnackBar(BuildContext context, SnackBar snackBar) {
  final statusManager = context.findAncestorStateOfType<StatusManagerState>();
  final ancestorCommon = context.findAncestorStateOfType<CommonScaffoldState>();
  if (ancestorCommon != null && ancestorCommon.isActiveMessengerHost) {
    statusManager?.clearSnackBar();
    ancestorCommon.showSnackBar(snackBar);
    return;
  }
  final searchRoot =
      rootNavigatorKey.currentContext ??
      Navigator.maybeOf(context, rootNavigator: true)?.context ??
      context;
  final activeCommon =
      _findActiveCommonScaffold(context) ??
      (identical(searchRoot, context)
          ? null
          : _findActiveCommonScaffold(searchRoot));
  if (activeCommon != null) {
    statusManager?.clearSnackBar();
    activeCommon.showSnackBar(snackBar);
    return;
  }
  if (statusManager != null) {
    statusManager.showSnackBar(snackBar);
    return;
  }
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(snackBar);
}

CommonScaffoldState? _findActiveCommonScaffold(BuildContext root) {
  CommonScaffoldState? match;

  void visit(Element element) {
    if (match != null || !element.mounted) {
      return;
    }
    final widget = element.widget;
    if (widget is Offstage && widget.offstage) {
      return;
    }
    if (widget is PageActivityScope && !widget.isActive) {
      return;
    }
    if (widget is RouteCurrentScope && !widget.isCurrent) {
      return;
    }
    if (element is StatefulElement) {
      final state = element.state;
      if (state is CommonScaffoldState && state.isActiveMessengerHost) {
        match = state;
        return;
      }
    }
    element.visitChildren(visit);
  }

  visit(root as Element);
  return match;
}

class _PersistentSnackBar extends SnackBar {
  const _PersistentSnackBar({
    super.key,
    required super.content,
    super.action,
    super.animation,
  }) : super(persist: true, behavior: SnackBarBehavior.fixed);

  @override
  SnackBar withAnimation(Animation<double> newAnimation, {Key? fallbackKey}) {
    return _PersistentSnackBar(
      key: key ?? fallbackKey,
      content: content,
      action: action,
      animation: newAnimation,
    );
  }

  @override
  State<SnackBar> createState() => _PersistentSnackBarState();
}

class _PersistentSnackBarState extends State<SnackBar> {
  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: snackBarHitMarker,
      child: SnackBar(
        content: widget.content,
        action: widget.action,
        animation: widget.animation,
        persist: true,
        behavior: SnackBarBehavior.fixed,
        duration: _snackBarDuration,
      ),
    );
  }
}

class _SnackBarDeadline {
  Timer? _timer;
  final _hoveredTokens = <Object>{};
  final _listeners = <VoidCallback>{};
  var _expired = false;
  var _closed = false;

  void attach(VoidCallback onDismiss) {
    _listeners.add(onDismiss);
  }

  void detach(Object token, VoidCallback onDismiss) {
    _hoveredTokens.remove(token);
    _listeners.remove(onDismiss);
    if (_listeners.isEmpty) {
      _timer?.cancel();
      _timer = null;
    } else if (_hoveredTokens.isEmpty && _expired && !_closed) {
      _dismiss();
    }
  }

  void start() {
    if (_closed) {
      return;
    }
    _timer ??= Timer(_snackBarDuration, () {
      _expired = true;
      if (_hoveredTokens.isEmpty) {
        _dismiss();
      }
    });
  }

  void setHovering(Object token, bool hovering) {
    if (hovering) {
      _hoveredTokens.add(token);
      return;
    }
    if (!_hoveredTokens.remove(token)) {
      return;
    }
    if (_hoveredTokens.isEmpty && _expired) {
      _dismiss();
    }
  }

  void _dismiss() {
    if (_closed || _hoveredTokens.isNotEmpty || !_expired) {
      return;
    }
    _closed = true;
    for (final listener in _listeners.toList(growable: false)) {
      listener();
      break;
    }
  }
}

class _TimedSnackBar extends SnackBar {
  const _TimedSnackBar({
    super.key,
    required super.content,
    super.action,
    super.animation,
    required this.deadline,
  }) : super(persist: true, behavior: SnackBarBehavior.fixed);

  final _SnackBarDeadline deadline;

  @override
  SnackBar withAnimation(Animation<double> newAnimation, {Key? fallbackKey}) {
    return _TimedSnackBar(
      key: key ?? fallbackKey,
      content: content,
      action: action,
      animation: newAnimation,
      deadline: deadline,
    );
  }

  @override
  State<SnackBar> createState() => _TimedSnackBarState();
}

class _TimedSnackBarState extends State<_TimedSnackBar> {
  _SnackBarDeadline get _deadline => widget.deadline;

  @override
  void initState() {
    super.initState();
    _deadline.attach(_handleDismiss);
  }

  @override
  void didUpdateWidget(covariant _TimedSnackBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.deadline, _deadline)) {
      oldWidget.deadline.detach(this, _handleDismiss);
      _deadline.attach(_handleDismiss);
    }
  }

  void _handleDismiss() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
  }

  @override
  void dispose() {
    _deadline.detach(this, _handleDismiss);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: snackBarHitMarker,
      child: MouseRegion(
        onEnter: (_) => _deadline.setHovering(this, true),
        onExit: (_) => _deadline.setHovering(this, false),
        child: SnackBar(
          content: widget.content,
          action: widget.action,
          animation: widget.animation,
          persist: true,
          behavior: SnackBarBehavior.fixed,
          onVisible: _deadline.start,
        ),
      ),
    );
  }
}

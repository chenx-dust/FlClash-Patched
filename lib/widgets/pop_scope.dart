import 'dart:async';

import 'package:fl_clash/manager/back_manager.dart';
import 'package:flutter/widgets.dart';

import 'inherited.dart';
import 'tv_back.dart';

class CommonPopScopeAttemptNotification extends Notification {
  final Future<void> completion;

  const CommonPopScopeAttemptNotification(this.completion);
}

class CommonPopScope extends StatelessWidget {
  final Widget child;
  final bool? canPop;
  final FutureOr<bool> Function(BuildContext context)? onPop;
  final FutureOr<void> Function()? onPopSuccess;

  const CommonPopScope({
    super.key,
    required this.child,
    this.canPop,
    this.onPop,
    this.onPopSuccess,
  });

  Future<void> _handlePop(BuildContext context) async {
    final res = await onPop!(context);
    if (!context.mounted || !res) {
      return;
    }
    Navigator.of(context).pop();
    if (onPopSuccess != null) {
      await onPopSuccess!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final hasBackLayer = route?.willHandlePopInternally == true;
    return PopScope(
      canPop: canPop ?? (onPop == null || hasBackLayer),
      onPopInvokedWithResult: onPop == null
          ? null
          : (didPop, _) async {
              if (didPop) {
                return;
              }
              if (TvBackScope.consume(context)) {
                return;
              }
              final completion = _handlePop(context);
              CommonPopScopeAttemptNotification(completion).dispatch(context);
              await completion;
            },
      child: child,
    );
  }
}

class BackLayerScope extends StatefulWidget {
  final Widget child;

  /// Called when this layer is popped. Return true to keep capturing back.
  final bool Function() onBack;
  final VoidCallback? onDeactivate;
  @visibleForTesting
  final void Function(void Function(Duration) callback)?
  schedulePostFrameCallback;

  const BackLayerScope({
    super.key,
    required this.onBack,
    this.onDeactivate,
    required this.child,
    @visibleForTesting this.schedulePostFrameCallback,
  });

  @override
  State<BackLayerScope> createState() => _BackLayerScopeState();
}

class _BackLayerScopeState extends State<BackLayerScope> {
  ModalRoute<dynamic>? _route;
  LocalHistoryEntry? _entry;
  bool _isDetaching = false;
  bool _isPageActive = true;
  int _syncRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final isPageActive = PageActivityScope.isActiveOf(context);
    if (identical(_route, route) && _isPageActive == isPageActive) {
      return;
    }
    _detach();
    _route = route;
    _isPageActive = isPageActive;
    final revision = ++_syncRevision;
    final schedulePostFrameCallback =
        widget.schedulePostFrameCallback ??
        WidgetsBinding.instance.addPostFrameCallback;
    schedulePostFrameCallback((_) {
      if (!mounted || revision != _syncRevision) {
        return;
      }
      if (!_isPageActive) {
        if (widget.onDeactivate case final onDeactivate?) {
          onDeactivate();
        } else {
          widget.onBack();
        }
        return;
      }
      if (route == null) {
        return;
      }
      _installEntry(route);
    });
  }

  void _installEntry(ModalRoute<dynamic> route) {
    if (_entry != null) {
      return;
    }
    final entry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: _handleRemove,
    );
    _entry = entry;
    route.addLocalHistoryEntry(entry);
    _notifyNavigation(route);
  }

  void _notifyNavigation(ModalRoute<dynamic> route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeContext = route.subtreeContext;
      if (routeContext == null || !routeContext.mounted || !route.isCurrent) {
        return;
      }
      // Local history changes do not emit Flutter navigation notifications.
      NavigationNotification(
        canHandlePop: route.popDisposition == RoutePopDisposition.doNotPop,
      ).dispatch(routeContext);
    });
  }

  void _handleRemove() {
    _entry = null;
    if (_route case final route?) {
      _notifyNavigation(route);
    }
    if (!_isDetaching && mounted) {
      final retain = widget.onBack();
      if (retain && mounted && _isPageActive && _route != null) {
        _installEntry(_route!);
      }
    }
  }

  void _detach() {
    final entry = _entry;
    if (entry == null) {
      return;
    }
    _entry = null;
    _isDetaching = true;
    entry.remove();
    _isDetaching = false;
  }

  @override
  void dispose() {
    _syncRevision++;
    _detach();
    _route = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: backShortcuts,
      child: Actions(
        actions: {
          BackIntent: CallbackAction<BackIntent>(
            onInvoke: (_) => Navigator.of(context).maybePop(),
          ),
        },
        child: widget.child,
      ),
    );
  }
}

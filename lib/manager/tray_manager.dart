import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/common/window.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray/tray.dart';

class TrayManager extends ConsumerStatefulWidget {
  final Widget child;
  final bool? isMacOS;
  final Future<void> Function()? openMenu;

  const TrayManager({
    super.key,
    required this.child,
    this.isMacOS,
    this.openMenu,
  });

  @override
  ConsumerState<TrayManager> createState() => _TrayManagerState();
}

class _TrayManagerState extends ConsumerState<TrayManager> {
  StreamSubscription<TrayEvent>? _subscription;

  bool get _isMacOS => widget.isMacOS ?? system.isMacOS;

  @override
  void initState() {
    super.initState();
    _subscription = Tray.instance.events.listen(_handleTrayEvent);
    ref.listenManual(trayStateProvider, (prev, next) {
      if (prev != next) {
        _reportFailure(ref.read(systemActionProvider.notifier).updateTray());
      }
    });
    ref.listenManual(loadedLocaleProvider, (prev, next) {
      if (prev != null && prev != next) {
        _reportFailure(ref.read(systemActionProvider.notifier).updateTray());
      }
    });
    ref.listenManual(hotKeyActionsProvider, (prev, next) {
      if (!hotKeyActionListEquality.equals(prev, next)) {
        _reportFailure(ref.read(systemActionProvider.notifier).updateTray());
      }
    });
    if (_isMacOS) {
      ref.listenManual(
        trafficsProvider.select(
          (state) => state.list.safeLast(const Traffic()),
        ),
        (prev, next) {
          if (prev != next) {
            final trayState = ref.read(trayStateProvider);
            _reportFailure(
              appTray?.updateTitle(
                showNetworkSpeed: trayState.showNetworkSpeed,
                isStart: trayState.isStart,
                traffic: next,
              ),
            );
          }
        },
      );
    }
  }

  void _reportFailure(Future<void>? operation) {
    if (operation == null) {
      return;
    }
    unawaited(
      operation.onError<Object>((error, stackTrace) {
        commonPrint.log(
          'Tray operation failed: ${compactError(error)}',
          logLevel: LogLevel.error,
        );
      }),
    );
  }

  void _handleTrayEvent(TrayEvent event) {
    switch (event) {
      case TrayIconActivated():
        if (_isMacOS) {
          _openMenu();
        } else {
          window?.show();
        }
      case TrayMenuRequested():
        _openMenu();
      case TrayMenuItemSelected():
        render?.active();
    }
  }

  void _openMenu() {
    _reportFailure(widget.openMenu?.call() ?? Tray.instance.openMenu());
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayManager extends ConsumerStatefulWidget {
  final Widget child;

  const TrayManager({super.key, required this.child});

  @override
  ConsumerState<TrayManager> createState() => _TrayContainerState();
}

class _TrayContainerState extends ConsumerState<TrayManager> with TrayListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    ref.listenManual(trayStateProvider, (prev, next) {
      if (prev != next) {
        unawaited(ref.read(systemActionProvider.notifier).updateTray());
      }
    });
    ref.listenManual(hotKeyActionsProvider, (prev, next) {
      if (!hotKeyActionListEquality.equals(prev, next)) {
        unawaited(ref.read(systemActionProvider.notifier).updateTray());
      }
    });
    ref.listenManual(
      trayStateProvider.select(
        (state) =>
            (showNetworkSpeed: state.showNetworkSpeed, isStart: state.isStart),
      ),
      (prev, next) {
        if (prev != next) {
          unawaited(
            _updateTrayTitle(
              showNetworkSpeed: next.showNetworkSpeed,
              isStart: next.isStart,
            ),
          );
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> _updateTrayTitle({
    required bool showNetworkSpeed,
    required bool isStart,
  }) async {
    try {
      await tray?.updateTrayTitle(
        showNetworkSpeed: showNetworkSpeed,
        isStart: isStart,
      );
    } catch (e) {
      commonPrint.log('update tray title error: $e', logLevel: LogLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconMouseDown() {
    if (system.isMacOS) {
      trayManager.popUpContextMenu();
    } else {
      window?.show();
    }
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }
}

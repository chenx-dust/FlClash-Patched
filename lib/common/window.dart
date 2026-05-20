import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/config.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class Window {
  static Window? _instance;

  Window._internal();

  factory Window() {
    _instance ??= Window._internal();
    return _instance!;
  }

  Future<void> init(int version, WindowProps props) async {
    final acquire = await singleInstanceLock.acquire();
    if (!acquire) {
      exit(0);
    }
    if (system.isWindows) {
      protocol.register('clash');
      protocol.register('clashmeta');
      protocol.register('flclash');
    }
    await windowManager.ensureInitialized();
    // kDebugMode ? Size(680, 580) :
    final WindowOptions windowOptions = WindowOptions(
      size: props.size,
      minimumSize: const Size(380, 400),
    );
    if (!system.isMacOS || version > 10) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    await windowManager.setMaximizable(true);
    await _windowPosition(props);
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
    });
  }

  Future<void> _windowPosition(WindowProps props) async {
    if (!system.isMacOS) {
      final left = props.left ?? 0;
      final top = props.top ?? 0;
      if (left == 0 && top == 0) {
        await windowManager.setAlignment(Alignment.center);
        return;
      }
      final displays = await screenRetriever.getAllDisplays();
      final isPositionValid = displays.any((display) {
        final scaleFactor = display.scaleFactor ?? 1.0;
        // visibleSize is already in logical pixels; fall back to
        // physical size / scaleFactor when visibleSize is unavailable.
        final logicalWidth =
            display.visibleSize?.width ?? display.size.width / scaleFactor;
        final logicalHeight =
            display.visibleSize?.height ?? display.size.height / scaleFactor;
        final displayBounds = Rect.fromLTWH(
          display.visiblePosition!.dx,
          display.visiblePosition!.dy,
          logicalWidth,
          logicalHeight,
        );
        return displayBounds.contains(Offset(left, top));
      });
      if (isPositionValid) {
        await windowManager.setPosition(Offset(left, top));
      } else {
        await windowManager.setAlignment(Alignment.center);
      }
    }
  }

  Future<void> show() async {
    render?.resume();
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
  }

  Future<bool> get isVisible async {
    final value = await windowManager.isVisible();
    commonPrint.log('window visible check: $value');
    return value;
  }

  Future<void> close() async {
    await windowManager.close();
  }

  void forceExit() {
    exit(0);
  }

  Future<void> hide() async {
    render?.pause();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }
}

final window = system.isDesktop ? Window() : null;

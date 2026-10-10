import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/config.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

const _titleBarHeight = 32.0;
const _minTitleBarGrabWidth = 120.0;

class Window implements WindowPort {
  static Window? _instance;
  bool _supportsPosition = false;
  late final WindowVisibilityController _visibility =
      WindowVisibilityController(
        showWindow: _showWindow,
        hideWindow: _hideWindow,
        isWindowVisible: _isWindowVisible,
        setSkipTaskbar: (skip) => windowManager.setSkipTaskbar(skip),
        dockSettleDuration: system.isMacOS
            ? const Duration(seconds: 1)
            : Duration.zero,
      );

  Window._internal();

  factory Window() {
    _instance ??= Window._internal();
    return _instance!;
  }

  Future<void> init(int version, WindowProps props) async {
    if (system.isWindows) {
      for (final scheme in protocolSchemes) {
        protocol.register(scheme);
      }
    }
    if (system.isLinux) {
      unawaited(protocol.registerLinux(protocolSchemes));
    }
    await windowManager.ensureInitialized();
    _supportsPosition = !system.isMacOS;
    if (system.isLinux) {
      _supportsPosition = await windowManager.isPositionSupported();
    }
    final WindowOptions windowOptions = WindowOptions(
      size: props.size,
      minimumSize: const Size(380, 400),
    );
    if (!system.isMacOS || version > 10) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    await windowManager.setMaximizable(true);
    // On Linux the compositor only honors positioning after the window is shown;
    // elsewhere position it pre-show to avoid a visible jump.
    if (!system.isLinux) {
      await _windowPosition(props);
    }
    await windowManager.waitUntilReadyToShow(windowOptions);
    if (system.isLinux) {
      await _windowPosition(props);
    }
    await windowManager.setPreventClose(true);
  }

  Future<void> _windowPosition(WindowProps props) async {
    if (!_supportsPosition) {
      return;
    }
    final position = props.left == null || props.top == null
        ? null
        : restoredWindowPosition(
            props,
            displays: await screenRetriever.getAllDisplays(),
            currentScale: system.isWindows
                ? windowManager.getDevicePixelRatio()
                : null,
          );
    if (position == null) {
      await windowManager.setAlignment(Alignment.center);
    } else {
      await windowManager.setPosition(position);
    }
  }

  @override
  Future<WindowProps?> captureNormalGeometry(WindowProps current) async {
    final states = await Future.wait<bool>([
      windowManager.isMaximized(),
      windowManager.isFullScreen(),
      windowManager.isMinimized(),
    ]);
    if (states.any((state) => state)) {
      return null;
    }

    final bounds = await windowManager.getBounds();
    if (!bounds.width.isFinite ||
        !bounds.height.isFinite ||
        bounds.width <= 0 ||
        bounds.height <= 0) {
      return null;
    }
    final hasValidPosition =
        bounds.left.isFinite && bounds.top.isFinite && _supportsPosition;
    return current.copyWith(
      width: bounds.width,
      height: bounds.height,
      left: hasValidPosition ? bounds.left : current.left,
      top: hasValidPosition ? bounds.top : current.top,
      scale: hasValidPosition && system.isWindows
          ? windowManager.getDevicePixelRatio()
          : current.scale,
    );
  }

  /// Every desktop runner leaves the window hidden until [init] reveals it, so
  /// a failure before that point would leave the error screen with no window.
  Future<void> showInitFailure() async {
    try {
      await windowManager.ensureInitialized();
      if (await windowManager.isVisible()) {
        return;
      }
      await windowManager.waitUntilReadyToShow(
        const WindowOptions(size: Size(680, 580), center: true),
      );
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      commonPrint.log(
        'show init failure window failed ${e.toString()}',
        logLevel: LogLevel.warning,
      );
    }
  }

  @override
  Future<void> show({int? activationTimestamp, String? activationToken}) =>
      _visibility.show(
        activationTimestamp: activationTimestamp,
        activationToken: activationToken,
      );

  @override
  Future<void> hide() => _visibility.hide();

  @override
  Future<void> toggle() => _visibility.toggle();

  Future<void> _showWindow({
    int? activationTimestamp,
    String? activationToken,
  }) async {
    globalState.handleForeground();
    await windowManager.show(
      activationTimestamp: activationTimestamp,
      activationToken: activationToken,
    );
    await windowManager.focus();
  }

  Future<void> _hideWindow() async {
    globalState.handleBackground();
    await windowManager.hide();
  }

  Future<bool> _isWindowVisible() async {
    final value = await windowManager.isVisible();
    commonPrint.log('window visible check: $value');
    return value;
  }

  @override
  Future<void> close() async {
    await windowManager.close();
  }

  @override
  void forceExit() {
    exit(0);
  }
}

/// On Windows window_manager scales by the window's monitor and
/// screen_retriever by each display's own, so only physical pixels compare
/// across mixed scales. A null [currentScale] treats every value as physical.
///
/// A position is kept only while the title bar can still be grabbed: its full
/// height and a draggable stretch of its width lie on one display.
@visibleForTesting
Offset? restoredWindowPosition(
  WindowProps props, {
  required List<Display> displays,
  double? currentScale,
}) {
  final savedScale = currentScale == null ? 1.0 : props.scale ?? currentScale;
  final topLeft = Offset(props.left!, props.top!) * savedScale;
  final titleBar =
      topLeft & Size(props.size.width, _titleBarHeight) * savedScale;
  final minGrabWidth = min(titleBar.width, _minTitleBarGrabWidth * savedScale);
  final isVisible = displays.any((display) {
    final position = display.visiblePosition;
    if (position == null) {
      return false;
    }
    final scale = currentScale == null
        ? 1.0
        : display.scaleFactor?.toDouble() ?? 1.0;
    final bounds = position & (display.visibleSize ?? display.size);
    final physical = Rect.fromLTRB(
      bounds.left * scale,
      bounds.top * scale,
      bounds.right * scale,
      bounds.bottom * scale,
    );
    final visible = physical.intersect(titleBar);
    return titleBar.top >= physical.top &&
        titleBar.bottom <= physical.bottom &&
        visible.width >= minGrabWidth;
  });
  return isVisible ? topLeft / (currentScale ?? 1.0) : null;
}

/// Serializes visibility requests so a burst of hotkey toggles lands in
/// order, and holds back the Dock-hiding activation policy switch while a
/// preceding regular switch settles: flipping regular → accessory → regular
/// within about a second leaves macOS with stray Dock icons.
class WindowVisibilityController {
  WindowVisibilityController({
    required Future<void> Function({
      int? activationTimestamp,
      String? activationToken,
    })
    showWindow,
    required Future<void> Function() hideWindow,
    required Future<bool> Function() isWindowVisible,
    required Future<void> Function(bool skip) setSkipTaskbar,
    required this.dockSettleDuration,
  }) : _showWindow = showWindow,
       _hideWindow = hideWindow,
       _isWindowVisible = isWindowVisible,
       _setSkipTaskbar = setSkipTaskbar;

  final Future<void> Function({
    int? activationTimestamp,
    String? activationToken,
  })
  _showWindow;
  final Future<void> Function() _hideWindow;
  final Future<bool> Function() _isWindowVisible;
  final Future<void> Function(bool skip) _setSkipTaskbar;
  final Duration dockSettleDuration;

  Future<void>? _queue;
  Timer? _dockSettleTimer;
  bool _dockHidePending = false;

  Future<void> show({int? activationTimestamp, String? activationToken}) =>
      _enqueue(
        () => _show(
          activationTimestamp: activationTimestamp,
          activationToken: activationToken,
        ),
      );

  Future<void> hide() => _enqueue(_hide);

  Future<void> toggle() => _enqueue(() async {
    if (await _isWindowVisible()) {
      await _hide();
    } else {
      await _show();
    }
  });

  Future<void> _enqueue(Future<void> Function() step) {
    final previous = _queue;
    final result = previous == null ? step() : previous.then((_) => step());
    final tail = result.catchError((_) {});
    _queue = tail;
    tail.whenComplete(() {
      if (identical(_queue, tail)) {
        _queue = null;
      }
    });
    return result;
  }

  Future<void> _show({
    int? activationTimestamp,
    String? activationToken,
  }) async {
    _dockHidePending = false;
    await _showWindow(
      activationTimestamp: activationTimestamp,
      activationToken: activationToken,
    );
    await _setSkipTaskbar(false);
    _dockSettleTimer?.cancel();
    _dockSettleTimer = dockSettleDuration == Duration.zero
        ? null
        : Timer(dockSettleDuration, _onDockSettled);
  }

  Future<void> _hide() async {
    await _hideWindow();
    if (_dockSettleTimer?.isActive ?? false) {
      _dockHidePending = true;
      return;
    }
    await _setSkipTaskbar(true);
  }

  void _onDockSettled() {
    _dockSettleTimer = null;
    if (!_dockHidePending) {
      return;
    }
    unawaited(
      _enqueue(() async {
        if (!_dockHidePending) {
          return;
        }
        _dockHidePending = false;
        await _setSkipTaskbar(true);
      }),
    );
  }
}

final window = system.isDesktop ? Window() : null;

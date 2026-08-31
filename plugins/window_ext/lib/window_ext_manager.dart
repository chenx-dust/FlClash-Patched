import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'window_ext_listener.dart';

class WindowExtManager {
  WindowExtManager._() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  static final WindowExtManager instance = WindowExtManager._();

  final MethodChannel _channel = const MethodChannel('window_ext');

  final ObserverList<WindowExtListener> _listeners =
      ObserverList<WindowExtListener>();

  Future<void> _methodCallHandler(MethodCall call) async {
    final listeners = List<WindowExtListener>.of(_listeners);
    switch (call.method) {
      case 'windowActivated':
        for (final listener in listeners) {
          await listener.onWindowActivated();
        }
      case 'shouldTerminate':
        for (final listener in listeners) {
          await listener.onShouldTerminate();
        }
      default:
        throw MissingPluginException(
          'Unknown window_ext event: ${call.method}',
        );
    }
  }

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(WindowExtListener listener) {
    _listeners.add(listener);
  }

  void removeListener(WindowExtListener listener) {
    _listeners.remove(listener);
  }

  Future<void> setWindowCornerPreference({required bool round}) async {
    await _channel.invokeMethod('setWindowCornerPreference', {
      'round': round,
    });
  }
}

final windowExtManager = WindowExtManager.instance;

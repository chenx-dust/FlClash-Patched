import 'package:flutter/services.dart';

enum WifiSsidPermission {
  granted,
  denied,
  permanentlyDenied,
}

class WifiSsidManager {
  WifiSsidManager._();

  static final WifiSsidManager instance = WifiSsidManager._();
  static const _timeout = Duration(seconds: 3);

  final MethodChannel _channel = const MethodChannel('wifi_ssid');

  /// Returns the current WiFi SSID, or null if not connected to WiFi.
  Future<String?> getSsid() async {
    try {
      return await _channel
          .invokeMethod<String>('getSsid')
          .timeout(_timeout, onTimeout: () => null);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Checks whether location permission has been granted.
  Future<WifiSsidPermission> checkPermission() async {
    final result = await _invokePermissionMethod('checkPermission');
    return WifiSsidPermission.values[result ?? 1];
  }

  /// Requests location permission from the user.
  Future<WifiSsidPermission> requestPermission() async {
    final result = await _invokePermissionMethod('requestPermission');
    return WifiSsidPermission.values[result ?? 1];
  }

  Future<int?> _invokePermissionMethod(String method) async {
    try {
      return await _channel
          .invokeMethod<int>(method)
          .timeout(_timeout, onTimeout: () => 1);
    } on PlatformException {
      return 1;
    } on MissingPluginException {
      return 1;
    }
  }
}

final wifiSsidManager = WifiSsidManager.instance;

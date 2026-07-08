import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:wifi_ssid/wifi_ssid.dart';

class ConnectivityManager extends StatefulWidget {
  final Function(List<ConnectivityResult> results)? onConnectivityChanged;
  final Widget child;

  const ConnectivityManager({
    super.key,
    this.onConnectivityChanged,
    required this.child,
  });

  @override
  State<ConnectivityManager> createState() => _ConnectivityManagerState();
}

class _ConnectivityManagerState extends State<ConnectivityManager> {
  late StreamSubscription subscription;
  int _ssidRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.wifi)) {
        _updateCurrentSsid();
      } else {
        globalState.container.read(currentSSIDProvider.notifier).value = null;
      }
      if (widget.onConnectivityChanged != null) {
        widget.onConnectivityChanged!(results);
      }
    });
  }

  Future<void> _updateCurrentSsid() async {
    final version = ++_ssidRefreshVersion;
    final permission = await WifiSsidManager.instance.checkPermission();
    if (!mounted || version != _ssidRefreshVersion) {
      return;
    }
    globalState.container.read(locationPermissionsProvider.notifier).value =
        permission;
    if (permission != WifiSsidPermission.granted) {
      globalState.container.read(currentSSIDProvider.notifier).value = null;
      commonPrint.log(
        'Wi-fi SSID skipped: location permission is $permission',
        logLevel: LogLevel.info,
      );
      return;
    }
    final ssid = await WifiSsidManager.instance.getSsid();
    if (!mounted || version != _ssidRefreshVersion) {
      return;
    }
    globalState.container.read(currentSSIDProvider.notifier).value = ssid;
    commonPrint.log('Wi-fi SSID: $ssid ', logLevel: LogLevel.info);
  }

  @override
  void dispose() {
    _ssidRefreshVersion++;
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

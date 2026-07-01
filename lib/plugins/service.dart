import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class ServiceListener {
  void onServiceEvent(CoreEvent event) {}

  void onServiceCrash(String message) {}
}

class Service {
  static Service? _instance;
  late MethodChannel methodChannel;
  ReceivePort? receiver;

  final ObserverList<ServiceListener> _listeners =
      ObserverList<ServiceListener>();

  factory Service() {
    _instance ??= Service._internal();
    return _instance!;
  }

  Service._internal() {
    methodChannel = const MethodChannel('$packageName/service');
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'event':
          final data = call.arguments as String? ?? '';
          final result = ActionResult.fromJson(json.decode(data));
          for (final listener in _listeners) {
            listener.onServiceEvent(CoreEvent.fromJson(result.data));
          }
          break;
        case 'crash':
          final message = call.arguments as String? ?? '';
          for (final listener in _listeners) {
            listener.onServiceCrash(message);
          }
          break;
        default:
          throw MissingPluginException();
      }
    });
  }

  Future<ActionResult?> invokeAction(Action action) async {
    return _invokeAction('invokeAction', action);
  }

  Future<ActionResult?> invokeAppCore(Action action) async {
    return _invokeAction('invokeAppCore', action);
  }

  Future<ActionResult?> invokeNetworkExtensionCore(Action action) async {
    return _invokeAction('invokeNetworkExtensionCore', action);
  }

  Future<ActionResult?> _invokeAction(String method, Action action) async {
    final data = await methodChannel.invokeMethod<String>(
      method,
      json.encode(action),
    );
    if (data == null) {
      return null;
    }
    try {
      final dataJson = await data.commonToJSON<dynamic>();
      return ActionResult.fromJson(dataJson);
    } catch (_) {
      return ActionResult(
        method: action.method,
        data: data,
        id: action.id,
        code: ResultType.error,
      );
    }
  }

  Future<bool> isNetworkExtensionCoreActive() async {
    return await methodChannel.invokeMethod<bool>(
          'isNetworkExtensionCoreActive',
        ) ??
        false;
  }

  Future<bool> start() async {
    return await methodChannel.invokeMethod<bool>('start') ?? false;
  }

  Future<bool> stop() async {
    return await methodChannel.invokeMethod<bool>('stop') ?? false;
  }

  Future<String> init() async {
    return await methodChannel.invokeMethod<String>('init') ?? '';
  }

  Future<String> syncState(SharedState state) async {
    return await methodChannel.invokeMethod<String>(
          'syncState',
          json.encode(state),
        ) ??
        '';
  }

  Future<bool> shutdown() async {
    return await methodChannel.invokeMethod<bool>('shutdown') ?? true;
  }

  Future<String> getAppGroupDir() async {
    return await methodChannel.invokeMethod<String>('getAppGroupDir') ?? '';
  }

  Future<DateTime?> getRunTime() async {
    final ms = await methodChannel.invokeMethod<int>('getRunTime') ?? 0;
    if (ms == 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(ServiceListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ServiceListener listener) {
    _listeners.remove(listener);
  }
}

Service? get service => system.isAndroid || system.isIOS ? Service() : null;

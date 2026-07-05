import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';

import 'interface.dart';
import 'method.dart';

class CoreIOS extends CoreHandlerInterface with ServiceListener {
  static CoreIOS? _instance;

  static const _appCoreMethods = {
    CoreMethod.getIsInit,
    CoreMethod.validateConfig,
    CoreMethod.getConfig,
    CoreMethod.generateAgeKeyPair,
    CoreMethod.convertAgeSecretKeyToPublicKey,
    CoreMethod.deleteFile,
    CoreMethod.updateGeoData,
  };

  Completer<bool> _connectedCompleter = Completer();
  bool _isNetworkExtensionCoreActive = false;

  CoreIOS._internal() {
    service?.addListener(this);
  }

  factory CoreIOS() {
    _instance ??= CoreIOS._internal();
    return _instance!;
  }

  @override
  Future<String> preload() async {
    if (_connectedCompleter.isCompleted) {
      return 'core is connected';
    }
    commonPrint.log('[iOS] preload app core');
    final res = await service?.init();
    if (res?.isEmpty != true) {
      commonPrint.log('[iOS] init app core failed: $res');
      return res ?? '';
    }
    final syncRes = await service?.syncState(
      globalState.container.read(sharedStateProvider),
    );
    if (syncRes?.isEmpty != true) {
      commonPrint.log('[iOS] sync shared state failed: $syncRes');
      return syncRes ?? '';
    }
    _isNetworkExtensionCoreActive =
        await service?.isNetworkExtensionCoreActive() ?? false;
    commonPrint.log('[iOS] app core ready without starting NECore');
    _connectedCompleter.complete(true);
    return '';
  }

  @override
  Future<String> setupConfig(SetupParams setupParams) async {
    final action = CoreMethodCall(id: nextMethodCallId, method: CoreMethod.setupConfig, arguments: setupParams.toJson());
    final appResult = await service?.invokeAppCore(action);
    if (appResult == null) return 'failed to setup config in app core';
    final appResultStr = appResult.unwrap<String>();
    if (!_isNetworkExtensionCoreActive || appResultStr?.isNotEmpty == true) {
      return appResultStr!;
    }

    final neResult = await service?.invokeNetworkExtensionCore(action);
    if (neResult == null) return 'failed to setup config in network extension core';
    final neResultStr = neResult.unwrap<String>();
    return neResultStr ?? '';
  }

  @override
  FutureOr<bool> destroy() async {
    return shutdown(false);
  }

  @override
  Future<bool> shutdown(_) async {
    if (!_connectedCompleter.isCompleted) {
      return false;
    }
    commonPrint.log('[iOS] shutdown NECore');
    _connectedCompleter = Completer();
    return service?.shutdown() ?? true;
  }

  @override
  Future<bool> startListener() async {
    if (_isNetworkExtensionCoreActive) {
      commonPrint.log('[iOS] NECore already active: skip redundant startListener');
      return true;
    }
    final syncRes = await service?.syncState(globalState.container.read(sharedStateProvider));
    if (syncRes?.isEmpty != true) {
      commonPrint.log('[iOS] sync shared state failed: $syncRes');
      return false;
    }
    final started = await service?.start() ?? false;
    commonPrint.log('[iOS] start NECore result: $started');
    _isNetworkExtensionCoreActive = started;
    return started;
  }

  @override
  Future<bool> stopListener() async {
    commonPrint.log('[iOS] stop VPN: stop NECore listener');
    final stopped = await service?.stop() ?? false;
    _isNetworkExtensionCoreActive = false;
    commonPrint.log('[iOS] stop NECore result: $stopped');
    return stopped;
  }

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    final call = CoreMethodCall(
      id: nextMethodCallId,
      method: method,
      arguments: arguments,
    );
    final useNetworkExtensionCore =
        _isNetworkExtensionCoreActive && !_appCoreMethods.contains(method);
    commonPrint.log(
      '[iOS] route ${method.name} to '
      '${useNetworkExtensionCore ? 'NECore' : 'app core'}',
      logLevel: LogLevel.debug,
    );
    final invokeFuture = useNetworkExtensionCore
        ? service?.invokeNetworkExtensionCore(call)
        : service?.invokeAppCore(call);
    final response = await invokeFuture?.withTimeout(
      timeout: timeout,
      onTimeout: () => null,
    );
    return response?.unwrap<T>();
  }

  @override
  Completer get completer => _connectedCompleter;

  @override
  void onServiceCrash(String message) {
    _isNetworkExtensionCoreActive = false;
  }
}

CoreIOS? get coreIOS => system.isIOS ? CoreIOS() : null;

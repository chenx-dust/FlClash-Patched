import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';

import 'interface.dart';
import 'method.dart';

class CoreIOS extends CoreHandlerInterface with ServiceListener {
  static CoreIOS? _instance;

  static const _appCoreMethods = {
    CoreMethod.initClash,
    CoreMethod.getIsInit,
    CoreMethod.validateConfig,
    CoreMethod.getConfig,
    CoreMethod.decryptAgeConfig,
    CoreMethod.generateAgeKeyPair,
    CoreMethod.convertAgeSecretKeyToPublicKey,
    CoreMethod.deleteFile,
    CoreMethod.updateGeoData,
    CoreMethod.getCountryCode,
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
    final res = await service?.init();
    if (res?.isEmpty != true) {
      commonPrint.log('Init app core failed: $res');
      return res ?? '';
    }
    final syncRes = await service?.syncState(
      globalState.container.read(sharedStateProvider),
    );
    if (syncRes?.isEmpty != true) {
      commonPrint.log('Sync shared state failed: $syncRes');
      return syncRes ?? '';
    }
    _isNetworkExtensionCoreActive =
        await service?.isNetworkExtensionCoreActive() ?? false;
    _connectedCompleter.complete(true);
    return '';
  }

  @override
  Future<String> setupConfig(SetupParams setupParams) async {
    _preManualInvoke();
    final appResult = await _invoke<String>(
      useNetworkExtensionCore: false,
      method: CoreMethod.setupConfig,
      arguments: setupParams.toJson(),
    );
    if (appResult == null) return 'failed to setup config in app core';
    if (!_isNetworkExtensionCoreActive || appResult.isNotEmpty) {
      return appResult;
    }

    final neResult = await _invoke<String>(
      useNetworkExtensionCore: true,
      method: CoreMethod.setupConfig,
      arguments: setupParams.toJson(),
    );
    if (neResult == null) {
      return 'failed to setup config in network extension core';
    }
    return neResult;
  }

  @override
  Future<String> updateConfig(UpdateParams updateParams) async {
    _preManualInvoke();
    final appResult = await _invoke<String>(
      useNetworkExtensionCore: false,
      method: CoreMethod.updateConfig,
      arguments: updateParams
          .copyWith(
            externalController: _isNetworkExtensionCoreActive
                ? ExternalControllerStatus.close
                : updateParams.externalController,
          )
          .toJson(),
    );
    if (appResult == null) return 'failed to update config in app core';
    if (!_isNetworkExtensionCoreActive || appResult.isNotEmpty) {
      return appResult;
    }

    final neResult = await _invoke<String>(
      useNetworkExtensionCore: true,
      method: CoreMethod.updateConfig,
      arguments: updateParams.copyWith(geoAutoUpdate: false).toJson(),
    );
    if (neResult == null) {
      return 'failed to update config in network extension core';
    }
    return neResult;
  }

  @override
  FutureOr<bool> destroy() async {
    return true;
  }

  @override
  Future<bool> shutdown(_) async {
    if (!_connectedCompleter.isCompleted) {
      return false;
    }
    _connectedCompleter = Completer();
    return service?.shutdown() ?? true;
  }

  @override
  Future<bool> startListener() async {
    if (_isNetworkExtensionCoreActive) {
      commonPrint.log('NECore already active: skip redundant startListener');
      return true;
    }
    final syncRes = await service?.syncState(
      globalState.container.read(sharedStateProvider),
    );
    if (syncRes?.isEmpty != true) {
      commonPrint.log(
        'Sync shared state failed: $syncRes',
        logLevel: LogLevel.error,
      );
      return false;
    }
    final started = await service?.start() ?? false;
    _isNetworkExtensionCoreActive = started;
    if (started) {
      final updateRes = await updateConfig(
        globalState.container.read(updateParamsProvider),
      );
      if (updateRes.isNotEmpty) {
        commonPrint.log(
          'Update config failed after startListener: $updateRes',
          logLevel: LogLevel.error,
        );
      }
    }
    return started;
  }

  @override
  Future<bool> stopListener() async {
    final stopped = await service?.stop() ?? false;
    _isNetworkExtensionCoreActive = false;
    return stopped;
  }

  Future<T?> _invoke<T>({
    required bool useNetworkExtensionCore,
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    final action = CoreMethodCall(
      id: nextMethodCallId,
      method: method,
      arguments: arguments,
    );
    commonPrint.log(
      'Invoke ${method.name} in '
      '${useNetworkExtensionCore ? 'NECore' : 'app core'}',
      logLevel: LogLevel.debug,
    );
    final invokeFuture = useNetworkExtensionCore
        ? service?.invokeNetworkExtensionCore(action)
        : service?.invokeAppCore(action);
    final response = await invokeFuture?.withTimeout(
      timeout: timeout,
      onTimeout: () {
        commonPrint.log(
          'Invoke action timeout: $method',
          logLevel: LogLevel.error,
        );
        return null;
      },
    );
    if (response == null) {
      return null;
    }
    return response.unwrap<T>();
  }

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    final useNetworkExtensionCore =
        _isNetworkExtensionCoreActive && !_appCoreMethods.contains(method);
    return _invoke(
      useNetworkExtensionCore: useNetworkExtensionCore,
      method: method,
      arguments: arguments,
      timeout: timeout,
    );
  }

  @override
  Completer get completer => _connectedCompleter;

  @override
  void onServiceCrash(String message) {
    _isNetworkExtensionCoreActive = false;
  }

  Future<void> _preManualInvoke() async {
    try {
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      commonPrint.log('Invoke pre timeout $e', logLevel: LogLevel.error);
    }
  }
}

CoreIOS? get coreIOS => system.isIOS ? CoreIOS() : null;

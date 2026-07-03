import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';

import 'interface.dart';

class CoreIOS extends CoreHandlerInterface with ServiceListener {
  static CoreIOS? _instance;

  static const _appCoreMethods = {
    ActionMethod.validateConfig,
    ActionMethod.getConfig,
    ActionMethod.generateAgeKeyPair,
    ActionMethod.convertAgeSecretKeyToPublicKey,
    ActionMethod.deleteFile,
    ActionMethod.updateGeoData,
  };

  Completer<bool> _connectedCompleter = Completer();
  InitParams? _initParams;
  SetupParams? _setupParams;
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
  Future<bool> get isInit async {
    final id = '${ActionMethod.getIsInit.name}#${utils.id}';
    final action = Action(id: id, method: ActionMethod.getIsInit, data: null);
    final result = await service?.invokeAppCore(action);
    if (result == null) return false;
    return parasResult<bool>(result);
  }

  @override
  Future<bool> init(InitParams params) async {
    _initParams = params;
    final id = '${ActionMethod.initClash.name}#${utils.id}';
    final action = Action(
      id: id,
      method: ActionMethod.initClash,
      data: json.encode(params),
    );
    final result = await service?.invokeAppCore(action);
    if (result == null) return false;
    return parasResult<bool>(result);
  }

  @override
  Future<String> setupConfig(SetupParams setupParams) async {
    _setupParams = setupParams;
    return super.setupConfig(setupParams);
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
      commonPrint.log('[iOS] NECore already active: ensure listener is running');
      return await invoke<bool>(
            method: ActionMethod.startListener,
            data: null,
          ) ??
          false;
    }
    commonPrint.log('[iOS] start VPN: stop app core listener before NECore');
    await super.stopListener();
    final started = await service?.start() ?? false;
    commonPrint.log('[iOS] start NECore result: $started');
    if (!started) {
      _isNetworkExtensionCoreActive = false;
      return false;
    }
    _isNetworkExtensionCoreActive = true;
    final setup = await _setupNetworkExtensionCore();
    commonPrint.log('[iOS] setup NECore result: $setup');
    return setup;
  }

  @override
  Future<bool> stopListener() async {
    commonPrint.log('[iOS] stop VPN: stop app core listener and NECore');
    await super.stopListener();
    final stopped = await service?.stop() ?? false;
    _isNetworkExtensionCoreActive = false;
    commonPrint.log('[iOS] stop NECore result: $stopped');
    if (_setupParams != null) {
      await invoke<String>(
        method: ActionMethod.setupConfig,
        data: json.encode(_setupParams),
      );
    }
    return stopped;
  }

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    final id = '${method.name}#${utils.id}';
    final action = Action(id: id, method: method, data: data);
    final useNetworkExtensionCore =
        _isNetworkExtensionCoreActive && !_appCoreMethods.contains(method);
    commonPrint.log(
      '[iOS] route ${method.name} to '
      '${useNetworkExtensionCore ? 'NECore' : 'app core'}',
      logLevel: LogLevel.debug,
    );
    final invokeFuture = useNetworkExtensionCore
        ? service?.invokeNetworkExtensionCore(action)
        : service?.invokeAppCore(action);
    final result = await invokeFuture?.withTimeout(onTimeout: () => null);
    if (result == null) {
      return null;
    }
    return parasResult<T>(result);
  }

  @override
  Completer get completer => _connectedCompleter;

  @override
  void onServiceCrash(String message) {
    _isNetworkExtensionCoreActive = false;
  }

  Future<bool> _setupNetworkExtensionCore() async {
    final initParams = _initParams;
    if (initParams == null) {
      commonPrint.log('[iOS] setup NECore failed: missing init params');
      return false;
    }
    final initialized = await invoke<bool>(
      method: ActionMethod.initClash,
      data: json.encode(initParams),
    );
    if (initialized != true) {
      commonPrint.log('[iOS] init NECore failed: $initialized');
      return false;
    }

    final setupParams = _setupParams;
    if (setupParams == null) {
      commonPrint.log('[iOS] setup NECore skipped: missing setup params');
      return true;
    }
    final message = await invoke<String>(
      method: ActionMethod.setupConfig,
      data: json.encode(setupParams),
    );
    if (message != null &&
        message.isNotEmpty &&
        !message.endsWith('is empty')) {
      commonPrint.log('[iOS] setup NECore failed: $message');
      return false;
    }
    return true;
  }
}

CoreIOS? get coreIOS => system.isIOS ? CoreIOS() : null;

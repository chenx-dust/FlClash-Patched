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
    CoreMethod.validateConfig,
    CoreMethod.asyncTestDelay,
    CoreMethod.getConfig,
    CoreMethod.generateAgeKeyPair,
    CoreMethod.convertAgeSecretKeyToPublicKey,
    CoreMethod.deleteFile,
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
    return await _invokeAppCore<bool>(method: CoreMethod.getIsInit) ?? false;
  }

  @override
  Future<bool> init(InitParams params) async {
    _initParams = params;
    return await _invokeAppCore<bool>(
          method: CoreMethod.initClash,
          arguments: params.toJson(),
        ) ??
        false;
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
      commonPrint.log(
        '[iOS] NECore already active: ensure listener is running',
      );
      return await invokeMethod<bool>(method: CoreMethod.startListener) ??
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

  Future<bool> _setupNetworkExtensionCore() async {
    final initParams = _initParams;
    if (initParams == null) {
      commonPrint.log('[iOS] setup NECore failed: missing init params');
      return false;
    }
    final initialized = await invokeMethod<bool>(
      method: CoreMethod.initClash,
      arguments: initParams.toJson(),
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
    final message = await invokeMethod<String>(
      method: CoreMethod.setupConfig,
      arguments: setupParams.toJson(),
    );
    if (message != null &&
        message.isNotEmpty &&
        !message.endsWith('is empty')) {
      commonPrint.log('[iOS] setup NECore failed: $message');
      return false;
    }
    return true;
  }

  Future<T?> _invokeAppCore<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    final response = await service
        ?.invokeAppCore(
          CoreMethodCall(
            id: nextMethodCallId,
            method: method,
            arguments: arguments,
          ),
        )
        .withTimeout(timeout: timeout, onTimeout: () => null);
    return response?.unwrap<T>();
  }
}

CoreIOS? get coreIOS => system.isIOS ? CoreIOS() : null;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:path/path.dart';

import 'interface.dart';

class CoreIOS extends CoreHandlerInterface {
  static CoreIOS? _instance;

  Completer<bool> _connectedCompleter = Completer();
  InitParams? _initParams;
  SetupParams? _setupParams;

  CoreIOS._internal();

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
    commonPrint.log('[iOS] app core ready without starting NECore');
    _connectedCompleter.complete(true);
    return '';
  }

  @override
  Future<bool> init(InitParams params) async {
    _initParams = params;
    return super.init(params);
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
    commonPrint.log('[iOS] start VPN: stop app core listener before NECore');
    await super.stopListener();
    final started = await service?.start() ?? false;
    commonPrint.log('[iOS] start NECore result: $started');
    if (!started) {
      return false;
    }
    final setup = await _setupNetworkExtensionCore();
    commonPrint.log('[iOS] setup NECore result: $setup');
    return setup;
  }

  @override
  Future<bool> stopListener() async {
    commonPrint.log('[iOS] stop VPN: stop app core listener and NECore');
    await super.stopListener();
    final stopped = await service?.stop() ?? false;
    commonPrint.log('[iOS] stop NECore result: $stopped');
    return stopped;
  }

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    final id = '${method.name}#${utils.id}';
    final result = await service
        ?.invokeAction(Action(id: id, method: method, data: data))
        .withTimeout(onTimeout: () => null);
    if (result == null) {
      return null;
    }
    return parasResult<T>(result);
  }

  @override
  Completer get completer => _connectedCompleter;

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

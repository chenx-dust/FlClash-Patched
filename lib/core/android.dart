import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';

import 'interface.dart';

class CoreAndroid extends CoreHandlerInterface {
  static CoreAndroid? _instance;

  Completer<bool> _connectedCompleter = Completer();

  CoreAndroid._internal();

  @override
  Future<String> preload() async {
    if (_connectedCompleter.isCompleted) {
      return 'core is connected';
    }
    final res = await service?.init();
    if (res?.isEmpty != true) {
      return res ?? '';
    }
    _connectedCompleter.complete(true);
    final syncRes = await service?.syncState(
      globalState.container.read(sharedStateProvider),
    );
    return syncRes ?? '';
  }

  factory CoreAndroid() {
    _instance ??= CoreAndroid._internal();
    return _instance!;
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
    await super.startListener();
    await service?.start();
    return true;
  }

  @override
  Future<bool> stopListener() async {
    await super.stopListener();
    await service?.stop();
    return true;
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
        .withTimeout(
          timeout: timeout,
          onTimeout: () {
            commonPrint.log(
              'Invoke action timeout: $method',
              logLevel: LogLevel.error,
            );
            return null;
          },
        );
    if (result == null) {
      return null;
    }
    return parasResult<T>(result);
  }

  @override
  Completer get completer => _connectedCompleter;
}

CoreAndroid? get coreAndroid => system.isAndroid ? CoreAndroid() : null;

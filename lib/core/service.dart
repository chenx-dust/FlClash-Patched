import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';

import 'event.dart';
import 'interface.dart';
import 'method.dart';
import 'transport.dart';

class CoreService extends CoreHandlerInterface {
  static CoreService? _instance;

  late final IPCCoreTransport _transport;

  Completer<bool> _shutdownCompleter = Completer();

  final Map<String, Completer<Object?>> _responseCompleters = {};

  Process? _process;

  factory CoreService() {
    _instance ??= CoreService._internal();
    return _instance!;
  }

  CoreService._internal() {
    _transport = IPCCoreTransport(
      address: system.isWindows ? windowsPipeName : unixSocketPath,
    );
    _initServer();
  }

  void _handleMethodCall(CoreMethodCall call) {
    if (call.method != CoreMethod.message) {
      commonPrint.log(
        'Unknown core callback method: ${call.method.name}',
        logLevel: LogLevel.warning,
      );
      return;
    }
    for (final event in coreEventsFromData(call.arguments)) {
      coreEventManager.sendEvent(event);
    }
  }

  void _handleResponse(CoreMethodResponse response) {
    final id = response.id;
    final completer = id == null ? null : _responseCompleters.remove(id);
    if (completer == null || completer.isCompleted) {
      return;
    }
    final error = response.error;
    if (error != null) {
      completer.completeError(
        CoreMethodException(
          code: error.code,
          message: error.message,
          details: error.details,
        ),
      );
      return;
    }
    completer.complete(response.result);
  }

  Future<void> _initServer() async {
    await _transport.init();

    _transport.onDisconnect = () {
      _handleInvokeCrashEvent();
      if (!_shutdownCompleter.isCompleted) {
        _shutdownCompleter.complete(true);
      }
    };

    _transport.dataStream
        .transform(uint8ListToListIntConverter)
        .transform(utf8.decoder)
        .listen(
          (data) async {
            try {
              final json = await data
                  .trim()
                  .commonToJSON<Map<String, Object?>>();
              if (json.containsKey('method')) {
                _handleMethodCall(CoreMethodCall.fromJson(json));
              } else {
                _handleResponse(CoreMethodResponse.fromJson(json));
              }
            } catch (e) {
              commonPrint.log(
                'Failed to parse transport data: $e',
                logLevel: LogLevel.error,
              );
            }
          },
          onError: (error) {
            commonPrint.log(
              'Transport data stream error: $error',
              logLevel: LogLevel.error,
            );
          },
        );
  }

  void _handleInvokeCrashEvent() {
    coreEventManager.sendEvent(
      const CoreEvent(type: CoreEventType.crash, data: 'core done'),
    );
  }

  Future<void> start() async {
    if (_process != null) {
      await shutdown(false);
    }
    if (system.isWindows && await system.checkIsAdmin()) {
      final isSuccess = await request.startCoreByHelper(_transport.address);
      if (isSuccess) {
        await _transport.connectionCompleter.future;
        return;
      }
    }
    try {
      _process = await Process.start(appPath.corePath, [_transport.address]);
    } catch (e) {
      commonPrint.log(
        'Failed to start core process: $e',
        logLevel: LogLevel.error,
      );
      _handleInvokeCrashEvent();
      return;
    }
    _process?.stdout.listen((_) {});
    _process?.stderr.listen((e) {
      final error = utf8.decode(e);
      if (error.isNotEmpty) {
        commonPrint.log(error, logLevel: LogLevel.warning);
      }
    });
    await _transport.connectionCompleter.future;
  }

  @override
  FutureOr<bool> destroy() async {
    await shutdown(false);
    await _transport.close();
    return true;
  }

  Future<void> sendMessage(String message) async {
    await _transport.connectionCompleter.future;
    _transport.send(message);
  }

  @override
  Future<bool> shutdown(bool isUser) async {
    _shutdownCompleter = Completer();
    if (system.isWindows) {
      await request.stopCoreByHelper();
    }
    _transport.disconnected();
    _process?.kill();
    _process = null;
    _clearCompleter();
    if (isUser) {
      return _shutdownCompleter.future;
    } else {
      return true;
    }
  }

  void _clearCompleter() {
    for (final completer in _responseCompleters.values) {
      completer.safeCompleter(null);
    }
    _responseCompleters.clear();
  }

  @override
  Future<String> preload() async {
    await start();
    return '';
  }

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    final id = nextMethodCallId;
    final completer = Completer<Object?>();
    _responseCompleters[id] = completer;
    await sendMessage(
      json.encode(CoreMethodCall(id: id, method: method, arguments: arguments)),
    );
    final result = await completer.future.withTimeout(
      timeout: timeout,
      onLast: () {
        final pendingResponse = _responseCompleters.remove(id);
        pendingResponse?.safeCompleter(null);
      },
      tag: id,
      onTimeout: () => null,
    );
    return result as T?;
  }

  @override
  Completer get completer => _transport.connectionCompleter;
}

final coreService = system.isDesktop ? CoreService() : null;

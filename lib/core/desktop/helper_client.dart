import 'dart:async';

import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:rust_api/rust_api.dart' as rust_api;

import 'launcher.dart';
import 'model.dart';

const _helperRequestTimeout = Duration(seconds: 2);

final class HelperCallResult {
  final bool ok;
  final String? sessionId;
  final int? corePid;
  final bool? stopped;
  final String? reason;
  final String? code;
  final String? message;

  const HelperCallResult({
    required this.ok,
    this.sessionId,
    this.corePid,
    this.stopped,
    this.reason,
    this.code,
    this.message,
  });

  factory HelperCallResult.fromBridge(rust_api.HelperRpcResponse response) {
    return HelperCallResult(
      ok: response.ok,
      sessionId: response.sessionId,
      corePid: response.corePid,
      stopped: response.stopped,
      reason: response.reason,
      code: response.code,
      message: response.message,
    );
  }

  @override
  String toString() {
    return 'HelperCallResult(ok: $ok, sessionId: $sessionId, '
        'corePid: $corePid, stopped: $stopped, reason: $reason, '
        'code: $code, message: $message)';
  }
}

typedef HelperPingCall = Future<HelperCallResult> Function();
typedef HelperStartCall =
    Future<HelperCallResult> Function(String address, String sessionId);
typedef HelperStopCall = Future<HelperCallResult> Function(String sessionId);

Future<HelperCallResult> _helperPing() async {
  return HelperCallResult.fromBridge(await rust_api.helperPing());
}

Future<HelperCallResult> _helperStart(String address, String sessionId) async {
  return HelperCallResult.fromBridge(
    await rust_api.helperStartCore(address: address, sessionId: sessionId),
  );
}

Future<HelperCallResult> _helperStop(String sessionId) async {
  return HelperCallResult.fromBridge(
    await rust_api.helperStopCore(sessionId: sessionId),
  );
}

final class HelperStartResponse {
  final String sessionId;
  final int pid;

  const HelperStartResponse({required this.sessionId, required this.pid});
}

final class HelperStopResponse {
  final String sessionId;
  final bool stopped;
  final String? reason;

  const HelperStopResponse({
    required this.sessionId,
    required this.stopped,
    this.reason,
  });
}

final class WindowsHelperException implements Exception {
  final String code;
  final String message;
  final Object? details;

  const WindowsHelperException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'WindowsHelperException($code, $message, $details)';
}

final class WindowsHelperClient {
  final HelperPingCall _ping;
  final HelperStartCall _start;
  final HelperStopCall _stop;

  const WindowsHelperClient({
    HelperPingCall ping = _helperPing,
    HelperStartCall start = _helperStart,
    HelperStopCall stop = _helperStop,
  }) : _ping = ping,
       _start = start,
       _stop = stop;

  Future<bool> isReady({Duration? timeout, bool logFailure = true}) async {
    if (timeout != null && timeout <= Duration.zero) {
      return false;
    }
    try {
      final operation = _ping();
      final response = timeout == null
          ? await operation
          : await operation.timeout(timeout);
      final valid =
          response.ok &&
          response.sessionId == null &&
          response.corePid == null &&
          response.stopped == null &&
          response.reason == null &&
          response.code == null &&
          response.message == null;
      if (!valid) {
        _logPingFailure('helper ping returned an invalid response', logFailure);
      }
      return valid;
    } catch (error) {
      _logPingFailure('helper ping failed: $error', logFailure);
      return false;
    }
  }

  void _logPingFailure(String message, bool enabled) {
    if (enabled) {
      commonPrint.log(message, logLevel: LogLevel.warning);
    }
  }

  Future<HelperStartResponse> start({
    required String address,
    required String sessionId,
  }) async {
    _validateSessionId(sessionId);
    try {
      final response = await _start(
        address,
        sessionId,
      ).timeout(_helperRequestTimeout);
      _throwIfFailed(response, operation: 'start');
      if (response.sessionId != sessionId ||
          response.corePid == null ||
          response.corePid! <= 0 ||
          response.stopped != null ||
          response.reason != null) {
        throw const WindowsHelperException(
          code: 'invalidResponse',
          message: 'Helper returned an invalid start response',
        );
      }
      return HelperStartResponse(
        sessionId: response.sessionId!,
        pid: response.corePid!,
      );
    } on WindowsHelperException {
      rethrow;
    } catch (error) {
      throw WindowsHelperException(
        code: 'transportError',
        message: 'Unable to start Core through Helper',
        details: error.toString(),
      );
    }
  }

  Future<HelperStopResponse> stop(String sessionId) async {
    _validateSessionId(sessionId);
    try {
      final response = await _stop(sessionId).timeout(_helperRequestTimeout);
      _throwIfFailed(response, operation: 'stop');
      final stopped = response.stopped;
      final reason = response.reason;
      if (response.sessionId != sessionId ||
          stopped == null ||
          response.corePid != null ||
          (stopped && reason != null) ||
          (!stopped && reason != 'notRunning')) {
        throw const WindowsHelperException(
          code: 'invalidResponse',
          message: 'Helper returned an invalid stop response',
        );
      }
      return HelperStopResponse(
        sessionId: response.sessionId!,
        stopped: stopped,
        reason: reason,
      );
    } on WindowsHelperException {
      rethrow;
    } catch (error) {
      throw WindowsHelperException(
        code: 'transportError',
        message: 'Unable to stop Core through Helper',
        details: error.toString(),
      );
    }
  }

  void _throwIfFailed(HelperCallResult response, {required String operation}) {
    if (response.ok) {
      if (response.code != null || response.message != null) {
        throw const WindowsHelperException(
          code: 'invalidResponse',
          message: 'Helper returned success with error details',
        );
      }
      return;
    }
    throw WindowsHelperException(
      code: response.code ?? 'helperRequestFailed',
      message: response.message ?? 'Helper $operation request failed',
      details: response,
    );
  }

  void _validateSessionId(String sessionId) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(sessionId)) {
      throw const WindowsHelperException(
        code: 'invalidSessionId',
        message: 'Core session ID must be 128-bit lowercase hexadecimal',
      );
    }
  }
}

final class WindowsHelperLauncher implements CoreProcessLauncher {
  final WindowsHelperClient client;

  const WindowsHelperLauncher(this.client);

  @override
  CoreProcessOwner get owner => CoreProcessOwner.windowsHelper;

  @override
  Future<CoreProcessLease> start({
    required String sessionId,
    required String address,
  }) async {
    try {
      final response = await client.start(
        address: address,
        sessionId: sessionId,
      );
      return HelperCoreLease(
        sessionId: response.sessionId,
        pid: response.pid,
        client: client,
      );
    } catch (error, stackTrace) {
      try {
        await client.stop(sessionId);
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

typedef HelperReadinessProbe = Future<bool> Function();

final class WindowsHelperLauncherResolver
    implements DesktopCoreLauncherResolver {
  final bool isWindows;
  final CoreProcessLauncher directLauncher;
  final CoreProcessLauncher helperLauncher;
  final HelperReadinessProbe helperReady;

  const WindowsHelperLauncherResolver({
    required this.isWindows,
    required this.directLauncher,
    required this.helperLauncher,
    required this.helperReady,
  });

  @override
  Future<CoreProcessLauncher> resolve() async {
    if (isWindows && await helperReady()) {
      return helperLauncher;
    }
    return directLauncher;
  }
}

final class HelperCoreLease implements CoreProcessLease {
  @override
  final String sessionId;

  @override
  final int pid;

  final WindowsHelperClient _client;
  Future<CoreProcessStopResult>? _stopOperation;

  HelperCoreLease({
    required this.sessionId,
    required this.pid,
    required WindowsHelperClient client,
  }) : _client = client;

  @override
  CoreProcessOwner get owner => CoreProcessOwner.windowsHelper;

  @override
  Future<CoreProcessStopResult> stop(Duration timeout) {
    final stopOperation = _stopOperation;
    if (stopOperation != null) {
      return stopOperation;
    }
    final nextOperation = _stop().onError((
      Object error,
      StackTrace stackTrace,
    ) {
      _stopOperation = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    _stopOperation = nextOperation;
    return nextOperation;
  }

  Future<CoreProcessStopResult> _stop() async {
    final response = await _client.stop(sessionId);
    return CoreProcessStopResult(
      stopped: response.stopped,
      exitConfirmed: true,
    );
  }
}

const windowsHelperClient = WindowsHelperClient();

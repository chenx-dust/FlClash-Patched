import 'package:fl_clash/core/desktop/helper_client.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _sessionId = '0123456789abcdef0123456789abcdef';

void main() {
  test(
    'start returns a Helper lease identity with matching session and PID',
    () async {
      var requestedAddress = '';
      var requestedSession = '';
      final client = _client(
        start: (address, sessionId) async {
          requestedAddress = address;
          requestedSession = sessionId;
          return const HelperCallResult(
            ok: true,
            sessionId: _sessionId,
            corePid: 6456,
          );
        },
      );

      final response = await client.start(
        address: r'\\.\pipe\FlClashCore_AAAAAAAAAAAAAAAAAAAAAA',
        sessionId: _sessionId,
      );

      expect(requestedAddress, r'\\.\pipe\FlClashCore_AAAAAAAAAAAAAAAAAAAAAA');
      expect(requestedSession, _sessionId);
      expect(response.pid, 6456);
      expect(response.sessionId, _sessionId);
    },
  );

  test('start rejects a response for another session', () async {
    final client = _client(
      start: (_, _) async => const HelperCallResult(
        ok: true,
        sessionId: 'fedcba9876543210fedcba9876543210',
        corePid: 6456,
      ),
    );

    await expectLater(
      client.start(address: 'test-address', sessionId: _sessionId),
      throwsA(
        isA<WindowsHelperException>().having(
          (error) => error.code,
          'code',
          'invalidResponse',
        ),
      ),
    );
  });

  test('matching stop parses a confirmed response', () async {
    var requestedSession = '';
    final client = _client(
      stop: (sessionId) async {
        requestedSession = sessionId;
        return const HelperCallResult(
          ok: true,
          sessionId: _sessionId,
          stopped: true,
        );
      },
    );

    final response = await client.stop(_sessionId);

    expect(requestedSession, _sessionId);
    expect(response.sessionId, _sessionId);
    expect(response.stopped, isTrue);
    expect(response.reason, isNull);
  });

  test('stop rejects an unknown unconfirmed reason', () async {
    final client = _client(
      stop: (_) async => const HelperCallResult(
        ok: true,
        sessionId: _sessionId,
        stopped: false,
        reason: 'unknown',
      ),
    );

    await expectLater(
      client.stop(_sessionId),
      throwsA(
        isA<WindowsHelperException>().having(
          (error) => error.code,
          'code',
          'invalidResponse',
        ),
      ),
    );
  });

  test('session mismatch is typed and never reported as stopped', () async {
    final client = _client(
      stop: (_) async => const HelperCallResult(
        ok: false,
        code: 'sessionMismatch',
        message: 'another Core session is running',
      ),
    );

    await expectLater(
      client.stop(_sessionId),
      throwsA(
        isA<WindowsHelperException>().having(
          (error) => error.code,
          'code',
          'sessionMismatch',
        ),
      ),
    );
  });

  test('Helper lease stops only its immutable session', () async {
    final requestedSessions = <String>[];
    final client = _client(
      start: (_, _) async => const HelperCallResult(
        ok: true,
        sessionId: _sessionId,
        corePid: 6456,
      ),
      stop: (sessionId) async {
        requestedSessions.add(sessionId);
        return const HelperCallResult(
          ok: true,
          sessionId: _sessionId,
          stopped: false,
          reason: 'notRunning',
        );
      },
    );
    final launcher = WindowsHelperLauncher(client);
    final lease = await launcher.start(
      sessionId: _sessionId,
      address: 'test-address',
    );

    final result = await lease.stop(const Duration(seconds: 1));

    expect(lease.owner, CoreProcessOwner.windowsHelper);
    expect(lease.pid, 6456);
    expect(requestedSessions, [_sessionId]);
    expect(result.stopped, isFalse);
    expect(result.exitConfirmed, isTrue);
  });

  test(
    'Helper launcher compensates an uncertain start with exact stop',
    () async {
      final requestedSessions = <String>[];
      final client = _client(
        start: (_, _) async => throw StateError('connection lost'),
        stop: (sessionId) async {
          requestedSessions.add(sessionId);
          return const HelperCallResult(
            ok: true,
            sessionId: _sessionId,
            stopped: false,
            reason: 'notRunning',
          );
        },
      );
      final launcher = WindowsHelperLauncher(client);

      await expectLater(
        launcher.start(sessionId: _sessionId, address: 'test-address'),
        throwsA(
          isA<WindowsHelperException>().having(
            (error) => error.code,
            'code',
            'transportError',
          ),
        ),
      );

      expect(requestedSessions, [_sessionId]);
    },
  );

  test('ping accepts only an empty successful response', () async {
    final ready = _client(ping: () async => const HelperCallResult(ok: true));
    final invalid = _client(
      ping: () async => const HelperCallResult(ok: true, sessionId: _sessionId),
    );

    expect(await ready.isReady(), isTrue);
    expect(await invalid.isReady(logFailure: false), isFalse);
  });

  test('ping failures and expired deadlines report not ready', () async {
    final failed = _client(ping: () async => throw StateError('unavailable'));
    final expired = _client(
      ping: () => Future<HelperCallResult>.delayed(
        const Duration(seconds: 1),
        () => const HelperCallResult(ok: true),
      ),
    );

    expect(await failed.isReady(logFailure: false), isFalse);
    expect(
      await expired.isReady(
        timeout: const Duration(milliseconds: 1),
        logFailure: false,
      ),
      isFalse,
    );
    expect(await expired.isReady(timeout: Duration.zero), isFalse);
  });

  test('invalid session IDs are rejected before the request', () async {
    var startCalls = 0;
    final client = _client(
      start: (_, _) async {
        startCalls++;
        return const HelperCallResult(ok: true);
      },
    );

    await expectLater(
      client.start(address: 'test-address', sessionId: 'ABCDEF'),
      throwsA(isA<WindowsHelperException>()),
    );
    expect(startCalls, 0);
  });

  test(
    'Windows launcher resolver uses Helper only while it is ready',
    () async {
      final direct = FakeLauncher(owner: CoreProcessOwner.direct, pid: 1);
      final helper = FakeLauncher(
        owner: CoreProcessOwner.windowsHelper,
        pid: 2,
      );
      var helperReady = true;
      final resolver = WindowsHelperLauncherResolver(
        isWindows: true,
        directLauncher: direct,
        helperLauncher: helper,
        helperReady: () async => helperReady,
      );

      expect(await resolver.resolve(), same(helper));
      helperReady = false;
      expect(await resolver.resolve(), same(direct));
    },
  );

  test('non-Windows launcher resolver never probes Helper', () async {
    final direct = FakeLauncher(owner: CoreProcessOwner.direct, pid: 1);
    final helper = FakeLauncher(owner: CoreProcessOwner.windowsHelper, pid: 2);
    var readyCalls = 0;
    final resolver = WindowsHelperLauncherResolver(
      isWindows: false,
      directLauncher: direct,
      helperLauncher: helper,
      helperReady: () async {
        readyCalls++;
        return true;
      },
    );

    expect(await resolver.resolve(), same(direct));
    expect(readyCalls, 0);
  });
}

WindowsHelperClient _client({
  HelperPingCall? ping,
  HelperStartCall? start,
  HelperStopCall? stop,
}) {
  return WindowsHelperClient(
    ping: ping ?? () async => const HelperCallResult(ok: true),
    start:
        start ??
        (_, _) async =>
            const HelperCallResult(ok: true, sessionId: _sessionId, corePid: 1),
    stop:
        stop ??
        (_) async => const HelperCallResult(
          ok: true,
          sessionId: _sessionId,
          stopped: true,
        ),
  );
}

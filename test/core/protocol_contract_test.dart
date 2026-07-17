import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCoreHandler extends CoreHandlerInterface {
  final Completer<void> _completer = Completer<void>()..complete();
  final Map<CoreMethod, Object?> calls = {};

  @override
  Completer<void> get completer => _completer;

  @override
  FutureOr<bool> destroy() => true;

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    calls[method] = arguments;
    return switch (method) {
      CoreMethod.initClash => true as T,
      _ => '' as T,
    };
  }

  @override
  Future<String> preload() async => '';

  @override
  Future<bool> shutdown(bool isUser) async => true;
}

void main() {
  test('method call keeps structured arguments', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final call = CoreMethodCall.fromJson(
      Map<String, Object?>.from(fixture['methodCall'] as Map),
    );

    expect(call.method, CoreMethod.updateConfig);
    expect(call.arguments, isA<Map<String, dynamic>>());
    expect((call.arguments as Map)['mixed-port'], 7890);
    expect(call.toJson(), containsPair('arguments', call.arguments));
    expect(call.toJson(), isNot(contains('data')));
  });

  test('core interface sends structured request parameters', () async {
    final handler = _RecordingCoreHandler();

    await handler.init(const InitParams(homeDir: '/tmp/flclash', version: 35));
    await handler.setupConfig(
      const SetupParams(selectedMap: {'GLOBAL': 'DIRECT'}, testUrl: 'test'),
    );
    await handler.changeProxy(
      const ChangeProxyParams(groupName: 'GLOBAL', proxyName: 'DIRECT'),
    );
    await handler.sideLoadExternalProvider(providerName: 'provider', data: 'x');
    await handler.asyncTestDelay('https://example.com', 'DIRECT');

    for (final method in [
      CoreMethod.initClash,
      CoreMethod.setupConfig,
      CoreMethod.changeProxy,
      CoreMethod.sideLoadExternalProvider,
      CoreMethod.asyncTestDelay,
    ]) {
      expect(handler.calls[method], isA<Map>());
    }
  });

  test('event contract accepts batches and legacy single events', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final call = CoreMethodCall.fromJson(
      Map<String, Object?>.from(fixture['eventCall'] as Map),
    );

    final events = coreEventsFromData(call.arguments);
    expect(events, hasLength(2));
    expect(events.first.type, CoreEventType.loaded);
    expect(events.last.type, CoreEventType.delay);

    final legacy = coreEventsFromData({'type': 'loaded', 'data': 'provider-b'});
    expect(legacy.single.data, 'provider-b');
  });

  test('method response separates result and structured errors', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final success = CoreMethodResponse.fromJson(
      Map<String, Object?>.from(fixture['successResponse'] as Map),
    );
    final failure = CoreMethodResponse.fromJson(
      Map<String, Object?>.from(fixture['errorResponse'] as Map),
    );

    expect(success.unwrap<String>(), '');
    expect(success.toJson(), containsPair('result', ''));
    expect(
      () => failure.unwrap<Object?>(),
      throwsA(
        isA<CoreMethodException>()
            .having((error) => error.code, 'code', 'core_error')
            .having((error) => error.message, 'message', 'config not found'),
      ),
    );
    expect(failure.toJson(), contains('error'));
    expect(failure.toJson(), isNot(contains('code')));
  });
}

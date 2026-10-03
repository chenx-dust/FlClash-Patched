import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

class _IpAdapter implements HttpClientAdapter {
  final pending = <Completer<ResponseBody>>[];
  int canceled = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final response = Completer<ResponseBody>();
    pending.add(response);
    cancelFuture?.then((_) => canceled++);
    return response.future;
  }

  void succeed(int index, String ip) {
    pending[index].complete(
      ResponseBody.fromString(
        '{"ip":"$ip","country_code":"US"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ProviderContainer container;
  late ValueNotifier<TunnelState> tunnel;
  late _IpAdapter adapter;
  late HttpClientAdapter originalAdapter;

  void initialize() {
    originalAdapter = request.dio.httpClientAdapter;
    adapter = _IpAdapter();
    request.dio.httpClientAdapter = adapter;
    tunnel = ValueNotifier(TunnelState.pending);
    container = ProviderContainer(
      overrides: [
        initProvider.overrideWithBuild((_, _) => true),
        tunnelStateProvider.overrideWith((ref) {
          tunnel.addListener(ref.invalidateSelf);
          ref.onDispose(() => tunnel.removeListener(ref.invalidateSelf));
          return tunnel.value;
        }),
      ],
    );
    container.listen(networkDetectionProvider, (_, _) {});
  }

  tearDown(() {
    container.dispose();
    tunnel.dispose();
    request.dio.httpClientAdapter = originalAdapter;
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(commonDuration);
    await tester.pump();
  }

  testWidgets('waits through startup and checks automatically when connected', (
    tester,
  ) async {
    initialize();
    final notifier = container.read(networkDetectionProvider.notifier);
    container.read(runTimeProvider.notifier).value = 1;
    notifier.startCheck();
    await settle(tester);
    expect(adapter.pending, isEmpty);

    tunnel.value = TunnelState.pending;
    await settle(tester);
    notifier.startCheck();
    await tester.pump(const Duration(seconds: 15));
    expect(adapter.pending, isEmpty);
    expect(container.read(networkDetectionProvider).isLoading, isTrue);

    tunnel.value = TunnelState.connected;
    await settle(tester);
    expect(adapter.pending, hasLength(7));
    adapter.succeed(0, '1.1.1.1');
    await settle(tester);
    expect(container.read(networkDetectionProvider).ipInfo?.ip, '1.1.1.1');
    expect(container.read(networkDetectionProvider).isLoading, isFalse);
    container.dispose();
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('waits for stop convergence before checking the direct network', (
    tester,
  ) async {
    initialize();
    container.read(runTimeProvider.notifier).value = 1;
    tunnel.value = TunnelState.connected;
    final notifier = container.read(networkDetectionProvider.notifier);
    notifier.startCheck();
    await settle(tester);
    expect(adapter.pending, hasLength(7));

    container.read(runTimeProvider.notifier).value = null;
    await settle(tester);
    expect(adapter.canceled, 7);
    expect(adapter.pending, hasLength(7));
    tunnel.value = TunnelState.pending;
    notifier.startCheck();
    await settle(tester);
    expect(adapter.pending, hasLength(7));

    tunnel.value = TunnelState.disconnected;
    await settle(tester);
    expect(adapter.pending, hasLength(14));
    adapter.succeed(7, '2.2.2.2');
    await settle(tester);
    adapter.succeed(0, '1.1.1.1');
    await settle(tester);
    expect(container.read(networkDetectionProvider).ipInfo?.ip, '2.2.2.2');
    container.dispose();
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets(
    'reassertion cancels detection and reconnect starts a new check',
    (tester) async {
      initialize();
      container.read(runTimeProvider.notifier).value = 1;
      tunnel.value = TunnelState.connected;
      container.read(networkDetectionProvider.notifier).startCheck();
      await settle(tester);

      tunnel.value = TunnelState.pending;
      await settle(tester);
      expect(adapter.canceled, 7);
      adapter.succeed(0, '1.1.1.1');
      await tester.pump(const Duration(seconds: 3));
      expect(container.read(networkDetectionProvider).ipInfo, isNull);
      expect(container.read(networkDetectionProvider).isLoading, isTrue);

      tunnel.value = TunnelState.connected;
      await settle(tester);
      expect(adapter.pending, hasLength(14));
      adapter.succeed(7, '2.2.2.2');
      await settle(tester);
      expect(container.read(networkDetectionProvider).ipInfo?.ip, '2.2.2.2');
      container.dispose();
      await tester.pump(const Duration(seconds: 11));
    },
  );

  testWidgets(
    'failed startup waits for the optimistic running state rollback',
    (tester) async {
      initialize();
      container.read(runTimeProvider.notifier).value = 1;
      tunnel.value = TunnelState.pending;
      container.read(networkDetectionProvider.notifier).startCheck();
      await settle(tester);
      tunnel.value = TunnelState.disconnected;
      await settle(tester);
      expect(adapter.pending, isEmpty);

      container.read(runTimeProvider.notifier).value = null;
      await settle(tester);
      expect(adapter.pending, hasLength(7));
      adapter.succeed(0, '2.2.2.2');
      await settle(tester);
      expect(container.read(networkDetectionProvider).ipInfo?.ip, '2.2.2.2');
      container.dispose();
      await tester.pump(const Duration(seconds: 11));
    },
  );
}

import 'dart:async';

import 'package:fl_clash/common/color.dart';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/networking/networking.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

class _Core extends Mock implements CoreHandlerInterface {}

void main() {
  setUpAll(() {
    registerFallbackValue(const GetOverlayNetworkStatusParams(targets: []));
    registerFallbackValue(OverlayNetworkKind.easytier);
  });

  testWidgets('EasyTier connects explicitly and refreshes expanded details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final core = _Core();
    final requests = <GetOverlayNetworkStatusParams>[];
    final active = ValueNotifier(true);
    addTearDown(active.dispose);
    Completer<List<OverlayNetworkStatus>>? pendingDetails;
    var connected = false;
    var empty = false;
    Completer<OverlayNetworkStatus>? activation;
    OverlayNetworkStatus status(OverlayNetworkTarget target) =>
        OverlayNetworkStatus(
          name: target.name,
          kind: target.kind,
          state: connected
              ? OverlayNetworkState.connected
              : OverlayNetworkState.uninitialized,
          rawState: '',
          networkName: 'private-mesh',
          authUrl: '',
          error: '',
          easyTierDetails:
              target.kind == OverlayNetworkKind.easytier &&
                  target.level == OverlayNetworkDetailLevel.details
              ? EasyTierNetworkDetails(
                  instanceId: 'instance-1',
                  dnsZone: 'mesh.internal',
                  local: const EasyTierNode(
                    hostname: 'local-device',
                    version: '2.6.0',
                    instanceId: 'instance-1',
                    proxyCidrs: ['192.168.10.0/24'],
                    listeners: ['tcp://0.0.0.0:11010'],
                    ipv4: '10.1.0.1',
                  ),
                  peers: empty
                      ? []
                      : const [
                          EasyTierNode(
                            hostname: 'z-peer',
                            ipv4: '10.1.0.3',
                            connectionType: 'relayed',
                            featureFlags: {'is_public_server': true},
                          ),
                          EasyTierNode(
                            hostname: 'a-peer',
                            pathLatencyMs: 40,
                            latencyFirstPathLatencyMs: 25,
                            peerId: 42,
                            version: '2.5.0',
                            nextHop: 42,
                            cost: 1,
                            connectionType: 'direct',
                            proxyCidrs: ['192.168.2.0/24'],
                            connections: [
                              EasyTierConnection(
                                id: 'conn-a',
                                latencyMs: 24,
                                protocol: 'udp',
                                remoteEndpoint: 'udp://192.0.2.1:2000',
                                rxBytes: 1024,
                                txBytes: 2048,
                                rxPackets: 10,
                                txPackets: 20,
                                lossRate: 0.125,
                              ),
                            ],
                            ipv4: '10.1.0.2',
                            latencyMs: 23,
                          ),
                        ],
                )
              : null,
        );
    when(() => core.getOverlayNetworkStatus(any())).thenAnswer((call) async {
      final params =
          call.positionalArguments.single as GetOverlayNetworkStatusParams;
      requests.add(params);
      if (pendingDetails != null &&
          params.targets.every(
            (target) => target.level == OverlayNetworkDetailLevel.details,
          )) {
        return pendingDetails.future;
      }
      return params.targets.map(status).toList();
    });
    when(() => core.activateOverlayNetwork(any(), any())).thenAnswer((_) {
      activation = Completer<OverlayNetworkStatus>();
      return activation!.future;
    });
    final container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1400, 1600));
    container
        .read(groupsProvider.notifier)
        .update(
          (_) => const [
            Group(
              name: 'group',
              type: GroupType.Selector,
              all: [
                Proxy(name: 'mesh', type: 'EasyTier'),
                Proxy(name: 'tailnet', type: 'Tailscale'),
                Proxy(name: 'zero', type: 'ZeroTier'),
              ],
            ),
          ],
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (context, isActive, child) =>
                PageActivityScope(isActive: isActive, child: child!),
            child: const NetworkingView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(3));
    expect(
      find.byKey(const ValueKey('networking-easytier-icon')),
      findsOneWidget,
    );
    expect(requests.single.targets, hasLength(3));
    expect(
      requests.single.targets.every(
        (t) => t.level == OverlayNetworkDetailLevel.summary,
      ),
      isTrue,
    );
    expect(find.textContaining('private-mesh'), findsNothing);
    await tester.tap(find.text('mesh'));
    await tester.pumpAndSettle();
    verifyNever(() => core.activateOverlayNetwork(any(), any()));
    expect(requests.last.targets.single.kind, OverlayNetworkKind.easytier);
    final button = find.descendant(
      of: find.byType(FilledButton),
      matching: find.widgetWithText(FilledButton, 'Initialize'),
    );
    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    activation!.completeError(StateError('activation failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('activation failed'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pump();
    connected = true;
    activation!.complete(
      status(
        const OverlayNetworkTarget(
          name: 'mesh',
          kind: OverlayNetworkKind.easytier,
          level: OverlayNetworkDetailLevel.summary,
        ),
      ),
    );
    await tester.pumpAndSettle();
    verify(
      () => core.activateOverlayNetwork('mesh', OverlayNetworkKind.easytier),
    ).called(2);
    expect(find.textContaining('private-mesh'), findsWidgets);
    expect(find.text('local-device'), findsOneWidget);
    expect(find.text('10.1.0.1'), findsOneWidget);
    expect(find.text('instance-1'), findsNothing);
    expect(find.text('2.6.0'), findsNothing);
    await tester.tap(find.text('private-mesh'));
    await tester.pumpAndSettle();
    expect(find.text('instance-1'), findsOneWidget);
    expect(find.text('2.6.0'), findsOneWidget);
    expect(find.text('mesh.internal'), findsOneWidget);
    expect(find.text('192.168.10.0/24'), findsOneWidget);
    expect(find.text('tcp://0.0.0.0:11010'), findsOneWidget);
    globalState.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('local-device'));
    await tester.pumpAndSettle();
    expect(find.text('instance-1'), findsNothing);
    expect(find.text('2.6.0'), findsNothing);
    expect(find.text('192.168.10.0/24'), findsNothing);
    expect(find.text('tcp://0.0.0.0:11010'), findsNothing);
    globalState.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('a-peer')).dy,
      lessThan(tester.getTopLeft(find.text('z-peer')).dy),
    );
    expect(find.byIcon(Icons.bolt), findsNothing);
    expect(find.text('23 ms'), findsOneWidget);
    expect(find.text('Relayed'), findsOneWidget);
    expect(find.text('10.1.0.3 · Relayed · Public server'), findsOneWidget);
    expect(find.text('Public server'), findsNothing);
    expect(
      tester.widget<Text>(find.text('23 ms')).style?.color,
      getDelayColor(23),
    );
    expect(find.text('0 ms'), findsNothing);
    expect(find.text('10.1.0.2 · Direct'), findsOneWidget);
    await tester.tap(find.text('a-peer'));
    await tester.pumpAndSettle();
    expect(find.text('Peer ID'), findsOneWidget);
    expect(find.text('2.5.0'), findsOneWidget);
    expect(find.text('Minimum direct latency'), findsOneWidget);
    expect(find.text('Path latency (hop-count first)'), findsOneWidget);
    expect(find.text('Path latency (latency first)'), findsOneWidget);
    expect(find.text('40 ms'), findsOneWidget);
    expect(find.text('25 ms'), findsOneWidget);
    expect(find.text('Connection latency'), findsOneWidget);
    expect(find.text('24 ms'), findsOneWidget);
    expect(find.text('Delay'), findsNothing);
    expect(find.text('192.168.2.0/24'), findsOneWidget);
    expect(find.text('udp://192.0.2.1:2000'), findsOneWidget);
    expect(find.text('12.50%'), findsOneWidget);
    expect(find.text('1KB'), findsOneWidget);
    expect(find.text('Feature flags'), findsNothing);
    globalState.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('z-peer'));
    await tester.pumpAndSettle();
    expect(find.text('Feature flags'), findsOneWidget);
    expect(find.text('is_public_server'), findsOneWidget);
    globalState.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    empty = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('No data'), findsNothing);
    expect(find.text('local-device'), findsOneWidget);
    expect(find.text('z-peer'), findsNothing);
    pendingDetails = Completer<List<OverlayNetworkStatus>>();
    requests.clear();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(requests, isNotEmpty);
    active.value = false;
    await tester.pump();
    empty = false;
    pendingDetails.complete([
      status(
        const OverlayNetworkTarget(
          name: 'mesh',
          kind: OverlayNetworkKind.easytier,
          level: OverlayNetworkDetailLevel.details,
        ),
      ),
    ]);
    pendingDetails = null;
    await tester.pump();
    expect(find.text('No data'), findsNothing);
    expect(find.text('local-device'), findsOneWidget);
    expect(find.text('a-peer'), findsNothing);
    requests.clear();
    await tester.pump(const Duration(seconds: 3));
    expect(requests, isEmpty);
    active.value = true;
    await tester.pumpAndSettle();

    await tester.tap(find.text('mesh'));
    await tester.pumpAndSettle();
    requests.clear();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

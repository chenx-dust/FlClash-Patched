import 'package:fl_clash/common/color.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/advanced.dart';
import 'package:fl_clash/views/config/dns.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/config/on_demand.dart';
import 'package:fl_clash/views/config/rules.dart';
import 'package:fl_clash/views/config/scripts.dart';
import 'package:fl_clash/views/hotkey.dart';
import 'package:fl_clash/views/profiles/overwrite/custom/groups.dart';
import 'package:fl_clash/views/profiles/overwrite/custom/proxies.dart';
import 'package:fl_clash/views/profiles/overwrite/custom/proxy_providers.dart';
import 'package:fl_clash/views/profiles/overwrite/custom/rules.dart';
import 'package:fl_clash/views/proxies/list.dart';
import 'package:fl_clash/views/proxies/providers.dart';
import 'package:fl_clash/views/proxies/tab.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:fl_clash/views/views.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:fl_clash/widgets/paged_sheet.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:material_ui/material_ui.dart' as flutter;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';
import '../helpers/test_database_providers.dart';
import '../helpers/test_profiles.dart';

Finder _portField(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

void main() {
  setUpAll(() {
    registerFallbackValue(const GetOverlayNetworkStatusParams(targets: []));
    registerFallbackValue(OverlayNetworkKind.tailscale);
  });

  final cases = <String, Widget>{
    'dashboard': const DashboardView(),
    'proxies': const ProxiesView(),
    'profiles': const ProfilesView(),
    'requests': const RequestsView(),
    'resources': const ResourcesView(),
    'networking': const NetworkingView(),
    'logs': const LogsView(),
    'tools': const ToolsView(),
    'basic config': const ConfigView(),
    'dns config': const Scaffold(body: DnsListView()),
    'network config': const Scaffold(body: NetworkListView()),
    'advanced config': const AdvancedConfigView(),
    'on demand config': const OnDemandView(),
    'theme': const ThemeView(),
    'application settings': const ApplicationSettingView(),
    'backup and restore': const BackupAndRestore(),
    'hotkeys': const HotKeyView(),
    'access control': const AccessView(),
    'proxy providers': const ProvidersView(),
    'added rules': const AddedRulesView(),
    'scripts': const ScriptsView(),
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key} renders its default state', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _MockCoreHandlerInterface? networkingCoreHandler;
      final networkingRequests = <GetOverlayNetworkStatusParams>[];
      var tailscaleState = OverlayNetworkState.uninitialized;
      var tailscaleHealth = <String>[];
      var tailscaleAuthKeyConfigured = false;
      var zeroTierState = OverlayNetworkState.needsLogin;
      var zeroTierError = '';
      var zeroTierNetworkName = 'example';
      String? copiedText;
      if (entry.key == 'networking') {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final coreHandler = _MockCoreHandlerInterface();
        networkingCoreHandler = coreHandler;
        when(() => coreHandler.getOverlayNetworkStatus(any())).thenAnswer((
          invocation,
        ) async {
          final params =
              invocation.positionalArguments.single
                  as GetOverlayNetworkStatusParams;
          networkingRequests.add(params);
          return [
            for (final target in params.targets)
              switch (target.kind) {
                OverlayNetworkKind.tailscale => OverlayNetworkStatus(
                  name: target.name,
                  kind: target.kind,
                  state: tailscaleState,
                  rawState: switch (tailscaleState) {
                    OverlayNetworkState.uninitialized => 'NoState',
                    OverlayNetworkState.connected => 'Running',
                    OverlayNetworkState.starting => 'Starting',
                    OverlayNetworkState.needsApproval => 'NeedsMachineAuth',
                    _ => 'NeedsLogin',
                  },
                  networkName: 'example.com',
                  authUrl: tailscaleState == OverlayNetworkState.needsLogin
                      ? 'https://login.tailscale.com/a/test'
                      : '',
                  error: '',
                  tailscaleDetails:
                      target.level == OverlayNetworkDetailLevel.details
                      ? TailscaleNetworkDetails(
                          magicDnsSuffix: 'example.com',
                          authKeyConfigured: tailscaleAuthKeyConfigured,
                          health: tailscaleHealth,
                          nodes:
                              tailscaleState ==
                                      OverlayNetworkState.uninitialized ||
                                  tailscaleState == OverlayNetworkState.stopped
                              ? const []
                              : const [
                                  TailscaleNode(
                                    id: 'node-1',
                                    publicKey: 'nodekey:test',
                                    hostName: 'host-device',
                                    dnsName: 'device.example.com.',
                                    os: 'windows',
                                    ips: ['100.64.0.1'],
                                    endpoints: ['192.0.2.1:41641'],
                                    online: true,
                                    active: true,
                                    self: false,
                                    exitNode: false,
                                    exitNodeOption: true,
                                    expired: false,
                                  ),
                                ],
                        )
                      : null,
                ),
                OverlayNetworkKind.zerotier => OverlayNetworkStatus(
                  name: target.name,
                  kind: target.kind,
                  state: zeroTierState,
                  rawState: zeroTierState == OverlayNetworkState.error
                      ? 'access-denied'
                      : 'authentication-required',
                  networkName: zeroTierNetworkName,
                  authUrl: zeroTierState == OverlayNetworkState.error
                      ? ''
                      : 'https://example.com/zerotier-login',
                  error: zeroTierError,
                  zeroTierDetails:
                      target.level == OverlayNetworkDetailLevel.details
                      ? const ZeroTierNetworkDetails(
                          networkId: '8056c2e21c000001',
                          node: 'abcdef1234',
                          online: true,
                          addresses: ['10.0.0.2/24'],
                          routes: ['10.0.0.0/24'],
                          dns: ['10.0.0.1:53'],
                          mtu: 2800,
                          peers: [
                            ZeroTierPeer(
                              address: '1234567890',
                              role: 'leaf',
                              version: '1.14.2',
                              direct: true,
                              endpoints: ['192.0.2.1:9993'],
                              latencyMs: 12,
                            ),
                            ZeroTierPeer(
                              address: 'abcdef0123',
                              role: 'planet',
                              version: '',
                              direct: false,
                              endpoints: [],
                              latencyMs: 0,
                            ),
                          ],
                        )
                      : null,
                ),
              },
          ];
        });
        when(
          () => coreHandler.activateOverlayNetwork(any(), any()),
        ).thenAnswer((invocation) async {
          final name = invocation.positionalArguments.first as String;
          final kind = invocation.positionalArguments[1] as OverlayNetworkKind;
          if (kind == OverlayNetworkKind.tailscale) {
            tailscaleState = OverlayNetworkState.needsLogin;
          }
          return OverlayNetworkStatus(
            name: name,
            kind: kind,
            state: kind == OverlayNetworkKind.tailscale
                ? tailscaleState
                : OverlayNetworkState.needsLogin,
            rawState: kind == OverlayNetworkKind.tailscale
                ? 'NeedsLogin'
                : 'authentication-required',
            networkName: kind == OverlayNetworkKind.tailscale
                ? 'example.com'
                : 'example',
            authUrl: kind == OverlayNetworkKind.tailscale
                ? 'https://login.tailscale.com/a/test'
                : 'https://example.com/zerotier-login',
            error: '',
          );
        });
        when(
          () => coreHandler.pingTailscaleNode(any(), any()),
        ).thenAnswer((_) async => const TailscalePingResult(latencyMs: 23));
        when(() => coreHandler.logoutTailscale(any())).thenAnswer((_) async {
          tailscaleState = OverlayNetworkState.needsLogin;
          return true;
        });
      }

      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          scriptsProvider.overrideWith(TestScripts.new),
          globalRulesProvider.overrideWith(TestGlobalRules.new),
          if (networkingCoreHandler != null)
            coreHandlerProvider.overrideWithValue(
              CoreController.scoped(networkingCoreHandler),
            ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      if (entry.key == 'networking') {
        container
            .read(viewSizeProvider.notifier)
            .update((_) => const Size(1400, 1000));
        container
            .read(groupsProvider.notifier)
            .update(
              (_) => const [
                Group(
                  name: 'Networking',
                  type: GroupType.Selector,
                  all: [
                    Proxy(name: 'tailnet', type: 'Tailscale'),
                    Proxy(name: 'zerotier', type: 'ZeroTier'),
                  ],
                ),
              ],
            );
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(child: entry.value),
        ),
      );
      await tester.pump();
      if (entry.key == 'networking') {
        expect(networkingCoreHandler, isNotNull);
        await tester.pumpAndSettle();
        expect(find.byType(flutter.ExpansionTile), findsNWidgets(2));
        expect(find.byType(SvgPicture), findsNWidgets(2));
        expect(
          find.byKey(const ValueKey('networking-tailscale-icon')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('networking-zerotier-icon')),
          findsOneWidget,
        );
        expect(find.text('tailnet'), findsOneWidget);
        expect(find.text('zerotier'), findsOneWidget);
        expect(find.text('device'), findsNothing);
        expect(find.text('1234567890'), findsNothing);
        expect(find.textContaining('example.com'), findsOneWidget);
        expect(networkingRequests, hasLength(1));
        expect(networkingRequests.single.targets, hasLength(2));
        expect(
          networkingRequests.single.targets.every(
            (target) => target.level == OverlayNetworkDetailLevel.summary,
          ),
          isTrue,
        );
        networkingRequests.clear();
        expect(find.byTooltip('Expand'), findsOneWidget);
        await tester.tap(find.byTooltip('Expand'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester
              .widgetList<flutter.ExpansionTile>(
                find.byType(flutter.ExpansionTile),
              )
              .every((tile) => tile.initiallyExpanded),
          isTrue,
        );
        expect(find.byTooltip('Collapse'), findsOneWidget);
        expect(networkingRequests, hasLength(1));
        expect(networkingRequests.single.targets, hasLength(2));
        expect(
          networkingRequests.single.targets.every(
            (target) => target.level == OverlayNetworkDetailLevel.details,
          ),
          isTrue,
        );
        await tester.tap(find.byTooltip('Collapse'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester
              .widgetList<flutter.ExpansionTile>(
                find.byType(flutter.ExpansionTile),
              )
              .every((tile) => !tile.initiallyExpanded),
          isTrue,
        );
        expect(find.byTooltip('Expand'), findsOneWidget);
        networkingRequests.clear();
        await tester.tap(find.text('tailnet'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.widgetWithText(flutter.FilledButton, 'Initialize'),
          findsOneWidget,
        );
        expect(find.text('Network'), findsNothing);
        expect(find.text('device'), findsNothing);
        verifyNever(
          () => networkingCoreHandler!.activateOverlayNetwork(any(), any()),
        );
        await tester.tap(
          find.widgetWithText(flutter.FilledButton, 'Initialize'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        verify(
          () => networkingCoreHandler!.activateOverlayNetwork(
            'tailnet',
            OverlayNetworkKind.tailscale,
          ),
        ).called(1);
        expect(find.text('device'), findsOneWidget);
        expect(find.byIcon(Icons.desktop_windows_outlined), findsOneWidget);
        expect(find.byIcon(Icons.bolt), findsOneWidget);
        await tester.tap(find.byIcon(Icons.bolt));
        await tester.pumpAndSettle();
        expect(find.text('23 ms'), findsOneWidget);
        verify(
          () =>
              networkingCoreHandler!.pingTailscaleNode('tailnet', '100.64.0.1'),
        ).called(1);
        when(
          () => networkingCoreHandler!.pingTailscaleNode(any(), any()),
        ).thenThrow(StateError('unreachable'));
        await tester.tap(find.text('23 ms'));
        await tester.pump();
        await tester.pump();
        expect(find.textContaining('unreachable'), findsOneWidget);
        expect(find.text('23 ms'), findsOneWidget);
        verify(
          () =>
              networkingCoreHandler!.pingTailscaleNode('tailnet', '100.64.0.1'),
        ).called(1);
        await tester.tap(find.text('device'));
        await tester.pumpAndSettle();
        expect(find.text('device details'), findsOneWidget);
        expect(
          find.textContaining('DNS name: device.example.com.'),
          findsNothing,
        );
        expect(find.text('Host'), findsOneWidget);
        expect(find.text('DNS name'), findsOneWidget);
        expect(find.text('Address'), findsOneWidget);
        expect(find.text('System'), findsOneWidget);
        expect(find.text('ID'), findsOneWidget);
        expect(find.text('Node key'), findsOneWidget);
        expect(find.text('Endpoints'), findsOneWidget);
        expect(find.text('Status'), findsOneWidget);
        expect(find.textContaining('Exit node available'), findsOneWidget);
        expect(find.text('host-device'), findsOneWidget);
        expect(find.text('device.example.com.'), findsOneWidget);
        expect(find.text('100.64.0.1'), findsOneWidget);
        expect(find.text('windows'), findsOneWidget);
        expect(find.text('node-1'), findsOneWidget);
        expect(find.text('nodekey:test'), findsOneWidget);
        expect(find.text('192.0.2.1:41641'), findsOneWidget);
        expect(find.byTooltip('Copy'), findsNWidgets(6));
        await tester.tap(find.byTooltip('Copy').at(3));
        await tester.pump();
        expect(copiedText, '100.64.0.1');
        globalState.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('1234567890'), findsNothing);
        expect(
          find.widgetWithText(flutter.FilledButton, 'Sign in'),
          findsOneWidget,
        );
        expect(networkingRequests, isNotEmpty);
        expect(networkingRequests.last.targets, hasLength(1));
        expect(
          networkingRequests.last.targets.single.kind,
          OverlayNetworkKind.tailscale,
        );
        expect(
          networkingRequests.last.targets.single.level,
          OverlayNetworkDetailLevel.details,
        );
        networkingRequests.clear();
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(networkingRequests, isNotEmpty);
        expect(
          networkingRequests.last.targets.single.kind,
          OverlayNetworkKind.tailscale,
        );
        networkingRequests.clear();
        await tester.tap(find.text('tailnet'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('device'), findsNothing);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(networkingRequests, isEmpty);
        await tester.tap(find.text('zerotier'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('1234567890'), findsOneWidget);
        expect(networkingRequests, hasLength(1));
        expect(
          networkingRequests.single.targets.single.kind,
          OverlayNetworkKind.zerotier,
        );
        expect(
          networkingRequests.single.targets.single.level,
          OverlayNetworkDetailLevel.details,
        );
        expect(find.text('Local'), findsOneWidget);
        expect(find.text('abcdef1234'), findsOneWidget);
        expect(find.text('10.0.0.2/24'), findsOneWidget);
        expect(find.byIcon(Icons.device_hub), findsOneWidget);
        expect(find.byIcon(Icons.public), findsOneWidget);
        expect(find.text('leaf · 1.14.2 · Direct'), findsOneWidget);
        expect(find.text('planet'), findsOneWidget);
        expect(find.text('Relayed'), findsNothing);
        expect(find.text('12 ms'), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('12 ms')).style?.color,
          getDelayColor(12),
        );
        expect(find.text('192.0.2.1:9993'), findsNothing);
        await tester.tap(find.text('1234567890'));
        await tester.pumpAndSettle();
        expect(find.text('1234567890 details'), findsOneWidget);
        expect(find.text('Role'), findsOneWidget);
        expect(find.text('Version'), findsOneWidget);
        expect(find.text('Delay'), findsOneWidget);
        expect(find.text('Endpoints'), findsOneWidget);
        expect(find.text('192.0.2.1:9993'), findsOneWidget);
        globalState.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        zeroTierState = OverlayNetworkState.error;
        zeroTierError = 'ZeroTier network access denied';
        await tester.tap(find.byTooltip('Sync').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Access denied'), findsOneWidget);
        expect(find.text('ZeroTier network access denied'), findsOneWidget);
        expect(find.text('abcdef1234'), findsOneWidget);
        expect(find.text('1234567890'), findsOneWidget);
        zeroTierState = OverlayNetworkState.needsLogin;
        zeroTierError = '';
        zeroTierNetworkName = '';
        await tester.tap(find.byTooltip('Sync').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('8056c2e21c000001'), findsOneWidget);
        networkingRequests.clear();
        await tester.tap(find.text('tailnet'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.widgetWithText(flutter.FilledButton, 'Sign in'),
          findsNWidgets(2),
        );
        await tester.tap(
          find.widgetWithText(flutter.FilledButton, 'Sign in').first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.text('https://login.tailscale.com/a/test'),
          findsNWidgets(2),
        );
        globalState.navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('1234567890'), findsOneWidget);
        tailscaleState = OverlayNetworkState.uninitialized;
        await tester.tap(find.byTooltip('Sync'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Uninitialized'), findsOneWidget);
        tailscaleState = OverlayNetworkState.connected;
        tailscaleHealth = ['DERP unavailable'];
        await tester.tap(find.byTooltip('Sync'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.widgetWithText(flutter.FilledButton, 'Sign out'),
          findsOneWidget,
        );
        expect(find.text('Health warnings'), findsOneWidget);
        expect(find.text('DERP unavailable'), findsOneWidget);
        tailscaleAuthKeyConfigured = true;
        await tester.tap(find.byTooltip('Sync'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.widgetWithText(flutter.FilledButton, 'Sign out'),
          findsNothing,
        );
        tailscaleAuthKeyConfigured = false;
        tailscaleState = OverlayNetworkState.needsApproval;
        tailscaleHealth = [];
        await tester.tap(find.byTooltip('Sync'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.widgetWithText(flutter.FilledButton, 'Sign out'),
          findsOneWidget,
        );
        tailscaleState = OverlayNetworkState.starting;
        await tester.tap(find.byTooltip('Sync'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.widgetWithText(flutter.FilledButton, 'Sign out'),
          findsNothing,
        );
        expect(find.textContaining('Connecting'), findsOneWidget);
        expect(find.text('Account'), findsNothing);
        tailscaleState = OverlayNetworkState.connected;
        await tester.tap(find.byTooltip('Sync'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.widgetWithText(flutter.FilledButton, 'Sign out'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        verify(
          () => networkingCoreHandler!.logoutTailscale('tailnet'),
        ).called(1);
        expect(
          find.widgetWithText(flutter.FilledButton, 'Sign in'),
          findsNWidgets(2),
        );
        tailscaleState = OverlayNetworkState.connected;
        await tester.tap(find.byTooltip('Sync'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        when(
          () => networkingCoreHandler!.logoutTailscale(any()),
        ).thenThrow(StateError('logout failed'));
        await tester.tap(find.widgetWithText(flutter.FilledButton, 'Sign out'));
        await tester.pump();
        expect(find.textContaining('logout failed'), findsOneWidget);
        expect(
          find.widgetWithText(flutter.FilledButton, 'Sign out'),
          findsOneWidget,
        );
      }
      if (entry.key == 'access control') {
        await tester.pump(const Duration(milliseconds: 301));
      }
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        for (var index = 0; index < 8; index++) {
          await tester.drag(scrollables.first, const Offset(0, -700));
          await tester.pump();
        }
      }

      expect(find.byWidget(entry.value), findsOneWidget);
      expect(tester.takeException(), null);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  final toolDestinations = <String, Type>{
    'Theme': ThemeView,
    'Backup and restore': BackupAndRestore,
    'Basic configuration': ConfigView,
    'Advanced configuration': AdvancedConfigView,
    'Application': ApplicationSettingView,
  };

  for (final entry in toolDestinations.entries) {
    testWidgets('tools opens ${entry.key}', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [profilesProvider.overrideWith(TestProfiles.new)],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(1400, 1000));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: ToolsView()),
        ),
      );
      await tester.pump();

      final target = find.text(entry.key);
      await tester.scrollUntilVisible(
        target,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(find.byType(entry.value), findsOneWidget);
      expect(tester.takeException(), null);
    });
  }

  testWidgets('user agent dialog applies a preset', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1000, 800));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(body: ListView(children: const [UaItem()])),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('User-Agent'));
    await tester.pumpAndSettle();
    expect(find.text('clash-verge/v2.4.2'), findsOneWidget);

    await tester.tap(find.text('clash-verge/v2.4.2'));
    await tester.pumpAndSettle();

    expect(
      container.read(patchClashConfigProvider).globalUa,
      'clash-verge/v2.4.2',
    );
    expect(tester.takeException(), null);
  });

  testWidgets('port dialog validates the fields the expander hides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1000, 800));
    final before = container.read(patchClashConfigProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: Scaffold(body: PortItem())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Port').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();

    await tester.enterText(_portField('SOCKS port'), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collapse'));
    await tester.pumpAndSettle();
    expect(_portField('SOCKS port'), findsNothing);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), null);
    expect(container.read(patchClashConfigProvider), before);
    expect(_portField('SOCKS port'), findsOneWidget);
    expect(find.text('SOCKS port cannot be empty'), findsOneWidget);
  });

  testWidgets('DNS mode options update the patch configuration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1000, 800));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: Scaffold(body: DnsModeItem())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('DNS mode'));
    await tester.pumpAndSettle();
    expect(find.text('fake-ip'), findsWidgets);

    await tester.tap(find.text('fake-ip').last);
    await tester.pumpAndSettle();

    expect(
      container.read(patchClashConfigProvider).dns.enhancedMode,
      DnsMode.fakeIp,
    );

    final previousOverride = container.read(overrideDnsProvider);
    final previousDns = container.read(patchClashConfigProvider).dns;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          child: Scaffold(
            body: Column(
              children: [
                OverrideItem(),
                StatusItem(),
                PreferH3Item(),
                IPv6Item(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Override DNS'));
    await tester.pump();
    await tester.tap(find.text('Status'));
    await tester.pump();
    await tester.tap(find.text('Prefer HTTP/3'));
    await tester.pump();
    await tester.tap(find.text('IPv6'));
    await tester.pump();

    expect(container.read(overrideDnsProvider), !previousOverride);
    expect(
      container.read(patchClashConfigProvider).dns.enable,
      !previousDns.enable,
    );
    expect(
      container.read(patchClashConfigProvider).dns.preferH3,
      !previousDns.preferH3,
    );
    expect(
      container.read(patchClashConfigProvider).dns.ipv6,
      !previousDns.ipv6,
    );
    expect(tester.takeException(), null);
  });

  testWidgets('proxies renders populated tab and list layouts', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = Profile.normal().copyWith(
      currentGroupName: 'Selector',
      selectedMap: {'Selector': 'Proxy 1'},
      unfoldSet: {'Selector'},
    );
    final proxies = List.generate(
      24,
      (index) => Proxy(name: 'Proxy $index', type: 'Direct'),
    );
    final group = Group(
      name: 'Selector',
      type: GroupType.Selector,
      hidden: false,
      now: 'Proxy 1',
      all: proxies,
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        currentGroupsStateProvider.overrideWithValue(
          GroupsState(value: [group]),
        ),
        groupsProvider.overrideWithValue([group]),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1400, 1000));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ProxiesView()),
      ),
    );
    await tester.pump();

    expect(container.read(proxiesTabStateProvider).groups, [group]);
    expect(find.byType(ProxiesTabView), findsOneWidget);
    expect(find.byType(ProxyGroupView), findsOneWidget);

    container
        .read(proxiesStyleSettingProvider.notifier)
        .update((state) => state.copyWith(type: ProxiesType.list));
    await tester.pump();
    expect(find.byType(ProxiesListView), findsOneWidget);

    final scrollables = find.byType(Scrollable);
    for (var index = 0; index < 8; index++) {
      await tester.drag(
        scrollables.last,
        const Offset(0, -700),
        warnIfMissed: false,
      );
      await tester.pump();
    }
    expect(tester.takeException(), null);
  });

  testWidgets('custom overwrite editors render populated data', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = Profile.normal().copyWith(
      overwriteType: OverwriteType.custom,
    );
    final proxyGroups = List.generate(
      8,
      (index) => ProxyGroup(
        id: 100 + index,
        profileId: profile.id,
        name: 'Group $index',
        type: GroupType.Selector,
        proxies: const ['DIRECT'],
      ),
    );
    final rules = List.generate(
      12,
      (index) => Rule(
        id: 200 + index,
        content: 'example$index.com',
        ruleTarget: 'DIRECT',
        order: index.toString(),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        profileCustomRulesProvider.overrideWith2(
          (_) => _TestProfileCustomRules(rules),
        ),
        proxyGroupsProvider.overrideWith2((_) => _TestProxyGroups(proxyGroups)),
        proxyGroupProvider.overrideWithBuild((_, _) => proxyGroups.first),
        clashConfigProvider(profile.id).overrideWithValue(
          const AsyncData(
            ClashConfig(
              proxies: [Proxy(name: 'DIRECT', type: 'Direct')],
              proxyProviders: ['provider'],
            ),
          ),
        ),
        customOverwriteDateProvider(profile.id).overrideWithValue(
          CustomOverwriteDate(
            loaded: true,
            proxyNames: const ['DIRECT'],
            proxyTypes: const {'DIRECT': 'Direct'},
            proxyGroups: proxyGroups,
            proxyProviders: const {'provider'},
            ruleTargets: {
              ...RuleTarget.baseTargets,
              ...proxyGroups.map((group) => group.name),
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1400, 1000));

    final views = <Widget>[
      CustomRulesView(profile.id),
      CustomProxyGroupsView(profile.id),
      SheetProvider(
        type: SheetType.page,
        child: ProfileIdProvider(
          profileId: profile.id,
          child: const EditProxiesView(),
        ),
      ),
      SheetProvider(
        type: SheetType.page,
        child: ProfileIdProvider(
          profileId: profile.id,
          child: const EditProxyProvidersView(),
        ),
      ),
    ];

    for (final view in views) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(child: view),
        ),
      );
      await tester.pump();
      expect(find.byWidget(view), findsOneWidget);
      expect(tester.takeException(), null);

      if (view is CustomRulesView) {
        final list = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView),
        );
        list.onReorderItem!(0, 1);
        await tester.pump();

        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();
        expect(find.text('Select all'), findsOneWidget);
        await tester.tap(find.text('Select all'));
        await tester.pump();
        await tester.tap(find.text('Select all'));
        await tester.pump();
        expect(find.text('Add'), findsOneWidget);

        container
            .read(viewSizeProvider.notifier)
            .update((_) => const Size(500, 1000));
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(find.byType(PagedSheet), findsOneWidget);
        globalState.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        container
            .read(viewSizeProvider.notifier)
            .update((_) => const Size(1400, 1000));
      }

      if (view is CustomProxyGroupsView) {
        final list = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView),
        );
        list.onReorderItem!(0, 1);
        await tester.pump();

        container
            .read(viewSizeProvider.notifier)
            .update((_) => const Size(500, 1000));
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(find.byType(PagedSheet), findsOneWidget);
        globalState.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        container
            .read(viewSizeProvider.notifier)
            .update((_) => const Size(1400, 1000));
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TestProfileCustomRules extends ProfileCustomRules {
  final List<Rule> initial;

  _TestProfileCustomRules(this.initial);

  @override
  Stream<List<Rule>> build(int profileId) => Stream.value(initial);

  @override
  void order(int oldIndex, int newIndex) {}
}

class _TestProxyGroups extends ProxyGroups {
  final List<ProxyGroup> initial;

  _TestProxyGroups(this.initial);

  @override
  Stream<List<ProxyGroup>> build(int profileId) => Stream.value(initial);

  @override
  void order(int oldIndex, int newIndex) {}
}

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/config/tun_advanced.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 1000);
  });

  tearDown(() => container.dispose());

  Tun readTun() => container.read(patchClashConfigProvider).tun;

  void writeTun(WidgetRef ref, Tun Function(Tun tun) update) => ref
      .read(patchClashConfigProvider.notifier)
      .update((state) => state.copyWith(tun: update(state.tun)));

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickOption(WidgetTester tester, String label) async {
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> submitInput(WidgetTester tester, String text) async {
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), text);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
  }

  testWidgets('a switch override moves between profile, on and off', (
    tester,
  ) async {
    await pump(
      tester,
      ConfigOverrideToggleItem(
        title: (l) => 'GSO',
        selector: patchClashConfigProvider.select((state) => state.tun.gso),
        onChanged: (ref, value) =>
            writeTun(ref, (tun) => tun.copyWith(gso: value)),
      ),
    );
    expect(find.text('Follow profile'), findsOneWidget);

    await pickOption(tester, 'Enabled');
    expect(readTun().gso, isTrue);

    await pickOption(tester, 'Disabled');
    expect(readTun().gso, isFalse);

    await pickOption(tester, 'Follow profile');
    expect(readTun().gso, isNull);
  });

  group('number override', () {
    Widget item() => ConfigOverrideNumberItem(
      title: (l) => 'UDP timeout',
      max: 600,
      selector: patchClashConfigProvider.select(
        (state) => state.tun.udpTimeout,
      ),
      onChanged: (ref, value) =>
          writeTun(ref, (tun) => tun.copyWith(udpTimeout: value)),
    );

    testWidgets('stores a number and clears back to the profile', (
      tester,
    ) async {
      await pump(tester, item());

      await submitInput(tester, '300');
      expect(readTun().udpTimeout, 300);

      await submitInput(tester, '');
      expect(readTun().udpTimeout, isNull);
    });

    testWidgets('rejects values outside the field range', (tester) async {
      await pump(tester, item());

      await submitInput(tester, '601');

      expect(find.text('UDP timeout must be a number'), findsOneWidget);
      expect(readTun().udpTimeout, isNull);
    });
  });

  testWidgets('Linux-only sections appear only on Linux', (tester) async {
    await pump(tester, const TunAdvancedListView(isLinux: false));
    expect(find.text('Linux'), findsNothing);
    expect(find.text('Exclude interfaces'), findsNothing);
    expect(find.text('Route exclude address'), findsOneWidget);

    await pump(tester, const TunAdvancedListView(isLinux: true));
    expect(find.text('Linux'), findsOneWidget);
    expect(find.text('Exclude interfaces'), findsOneWidget);
  });

  testWidgets('reset clears overrides but keeps app-applied values', (
    tester,
  ) async {
    container.listen(patchClashConfigProvider, (_, _) {});
    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith.tun(
            mtu: 1400,
            device: 'tun-test',
            gso: true,
            routeExcludeAddress: ['10.0.0.0/8'],
          ),
        );
    await pump(tester, const TunAdvancedResetButton());

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(readTun().gso, isNull);
    expect(readTun().routeExcludeAddress, isNull);
    expect(readTun().mtu, 1400);
    expect(readTun().device, 'tun-test');
  });

  testWidgets('the device name writes the trimmed value', (tester) async {
    await pump(tester, const TunDeviceItem());

    await submitInput(tester, '  tun-test  ');

    expect(readTun().device, 'tun-test');
  });

  testWidgets('auto route writes the desktop setting', (tester) async {
    await pump(tester, const TunAutoRouteItem());
    expect(container.read(networkSettingProvider).desktopAutoRoute, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(container.read(networkSettingProvider).desktopAutoRoute, isFalse);
  });

  testWidgets('desktop route address ignores the mobile route mode', (
    tester,
  ) async {
    container
        .read(networkSettingProvider.notifier)
        .update((state) => state.copyWith(routeMode: RouteMode.bypassPrivate));

    await pump(tester, const RouteAddressItem(followsRouteMode: false));

    expect(find.byType(ListTile), findsOneWidget);
  });

  group('network options placement', () {
    List<Type> types({required bool isDesktop, bool isMacOS = false}) =>
        networkOptionsItems(
          isDesktop: isDesktop,
          isMacOS: isMacOS,
        ).map((item) => item.runtimeType).toList();

    test('app-applied TUN settings live in the desktop options', () {
      final desktop = types(isDesktop: true);
      expect(desktop, containsAll([TunAutoRouteItem, TunDeviceItem]));
      expect(desktop.where((type) => type == RouteAddressItem), hasLength(1));
      expect(desktop.last, TunAdvancedItem);
    });

    test('the device name is hidden where mihomo ignores it', () {
      expect(
        types(isDesktop: true, isMacOS: true),
        isNot(contains(TunDeviceItem)),
      );
      final mobile = types(isDesktop: false);
      expect(mobile, isNot(contains(TunDeviceItem)));
      expect(mobile, isNot(contains(TunAutoRouteItem)));
      expect(mobile, isNot(contains(TunAdvancedItem)));
    });
  });

  test('dns hijack entries follow the format mihomo parses', () {
    for (final value in [
      'any:53',
      'tcp://any:53',
      'udp://8.8.8.8:53',
      '[::]:53',
      '[2001:4860:4860::8888]:53',
    ]) {
      expect(isValidDnsHijack(value), isTrue, reason: value);
    }
    for (final value in [
      '8.8.8.8',
      'dns.google:53',
      '::1:53',
      'any:70000',
      ':53',
    ]) {
      expect(isValidDnsHijack(value), isFalse, reason: value);
    }
  });
}

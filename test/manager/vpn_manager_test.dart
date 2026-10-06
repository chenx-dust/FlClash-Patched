import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/status_manager.dart';
import 'package:fl_clash/manager/vpn_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  VpnOptions? activeOptions;
  Future<VpnOptions?> Function()? readOptions;
  late ValueNotifier<TunnelState> tunnelState;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() {
    container = ProviderContainer(
      overrides: [currentProfileProvider.overrideWithValue(null)],
    );
    globalState.container = container;
    activeOptions = container.read(vpnOptionsProvider);
    readOptions = null;
    tunnelState = ValueNotifier(TunnelState.pending);
  });

  tearDown(() {
    container.dispose();
    tunnelState.dispose();
  });

  Future<void> pumpVpnManager(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: globalState.navigatorKey,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          builder: (_, child) {
            return StatusManager(
              child: VpnManager(
                tunnelState: tunnelState,
                readActiveOptions: () async =>
                    readOptions == null ? activeOptions : await readOptions!(),
                child: child!,
              ),
            );
          },
          home: const SizedBox(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 601));
  }

  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('shows a tip when the vpn options change while started', (
    tester,
  ) async {
    await pumpVpnManager(tester);
    container.read(runTimeProvider.notifier).value = 1;

    container
        .read(vpnSettingProvider.notifier)
        .update((_) => const VpnProps(enable: false));
    await tester.pump(const Duration(milliseconds: 601));

    expect(
      find.text(currentAppLocalizations.vpnConfigChangeDetected),
      findsOneWidget,
    );
    await drainTimers(tester);
  });

  testWidgets('does not show a tip when not started', (tester) async {
    await pumpVpnManager(tester);

    container
        .read(vpnSettingProvider.notifier)
        .update((_) => const VpnProps(enable: false));
    await tester.pump(const Duration(milliseconds: 601));

    expect(
      find.text(currentAppLocalizations.vpnConfigChangeDetected),
      findsNothing,
    );
    await drainTimers(tester);
  });

  testWidgets('compares against the options actually running after restart', (
    tester,
  ) async {
    await pumpVpnManager(tester);
    container.read(runTimeProvider.notifier).value = 1;

    container
        .read(vpnSettingProvider.notifier)
        .update((_) => const VpnProps(enable: false));
    await tester.pump(const Duration(milliseconds: 601));
    expect(
      find.text(currentAppLocalizations.vpnConfigChangeDetected),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text(currentAppLocalizations.vpnConfigChangeDetected),
      findsNothing,
    );

    container
        .read(vpnSettingProvider.notifier)
        .update((_) => const VpnProps(enable: true));
    activeOptions = container.read(vpnOptionsProvider);
    await tester.pump(const Duration(milliseconds: 601));

    expect(
      find.text(currentAppLocalizations.vpnConfigChangeDetected),
      findsNothing,
    );
    await drainTimers(tester);
  });

  testWidgets('detects a TUN option outside the legacy vpn state', (
    tester,
  ) async {
    await pumpVpnManager(tester);
    container.read(runTimeProvider.notifier).value = 1;

    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.tun(mtu: state.tun.mtu + 1));
    await tester.pump(const Duration(milliseconds: 601));

    expect(
      find.text(currentAppLocalizations.vpnConfigChangeDetected),
      findsOneWidget,
    );
    await drainTimers(tester);
  });

  testWidgets(
    'checks changes after starting inside the former throttle window',
    (tester) async {
      await pumpVpnManager(tester);
      container
          .read(vpnSettingProvider.notifier)
          .update((state) => state.copyWith(ipv6: true));
      await tester.pump(const Duration(milliseconds: 601));
      activeOptions = container.read(vpnOptionsProvider);
      container.read(runTimeProvider.notifier).value = 1;
      container
          .read(vpnSettingProvider.notifier)
          .update((state) => state.copyWith(dnsHijacking: false));
      await tester.pump(const Duration(milliseconds: 601));
      expect(
        find.text(currentAppLocalizations.vpnConfigChangeDetected),
        findsOneWidget,
      );
      await drainTimers(tester);
    },
  );

  testWidgets(
    'checks final options after rapid edits and ignores reverted edits',
    (tester) async {
      await pumpVpnManager(tester);
      container.read(runTimeProvider.notifier).value = 1;
      container
          .read(vpnSettingProvider.notifier)
          .update((state) => state.copyWith(ipv6: true));
      await tester.pump(const Duration(milliseconds: 300));
      container
          .read(vpnSettingProvider.notifier)
          .update((state) => state.copyWith(ipv6: false));
      await tester.pump(const Duration(milliseconds: 601));
      expect(
        find.text(currentAppLocalizations.vpnConfigChangeDetected),
        findsNothing,
      );
      container
          .read(vpnSettingProvider.notifier)
          .update((state) => state.copyWith(ipv6: true));
      await tester.pump(const Duration(milliseconds: 601));
      expect(
        find.text(currentAppLocalizations.vpnConfigChangeDetected),
        findsOneWidget,
      );
      await drainTimers(tester);
    },
  );

  testWidgets('does not treat a pending or failed start as active options', (
    tester,
  ) async {
    activeOptions = null;
    await pumpVpnManager(tester);
    container.read(runTimeProvider.notifier).value = 1;
    container
        .read(vpnSettingProvider.notifier)
        .update((state) => state.copyWith(ipv6: true));
    await tester.pump(const Duration(milliseconds: 601));
    expect(
      find.text(currentAppLocalizations.vpnConfigChangeDetected),
      findsNothing,
    );
    await drainTimers(tester);
  });

  for (final dispose in [false, true]) {
    testWidgets(
      'discards an active-options read after ${dispose ? 'disposal' : 'stop'}',
      (tester) async {
        final response = Completer<VpnOptions?>();
        readOptions = () => response.future;
        await pumpVpnManager(tester);
        container.read(runTimeProvider.notifier).value = 1;
        container
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(ipv6: true));
        await tester.pump(const Duration(milliseconds: 601));
        if (dispose) {
          await tester.pumpWidget(const SizedBox());
        } else {
          container.read(runTimeProvider.notifier).value = null;
        }
        response.complete(activeOptions);
        await tester.pump(const Duration(milliseconds: 601));
        expect(
          find.text(currentAppLocalizations.vpnConfigChangeDetected),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await drainTimers(tester);
      },
    );
  }

  testWidgets(
    'checks edits made during startup when native startup completes',
    (tester) async {
      final startupOptions = activeOptions;
      activeOptions = null;
      await pumpVpnManager(tester);
      container.read(runTimeProvider.notifier).value = 1;
      container
          .read(vpnSettingProvider.notifier)
          .update((state) => state.copyWith(ipv6: true));
      await tester.pump(const Duration(milliseconds: 601));
      expect(
        find.text(currentAppLocalizations.vpnConfigChangeDetected),
        findsNothing,
      );
      activeOptions = startupOptions;
      tunnelState.value = TunnelState.connected;
      await tester.pump(const Duration(milliseconds: 601));
      expect(
        find.text(currentAppLocalizations.vpnConfigChangeDetected),
        findsOneWidget,
      );
      await drainTimers(tester);
    },
  );

  testWidgets('recovers from failed reads when the app resumes', (
    tester,
  ) async {
    await pumpVpnManager(tester);
    readOptions = () => Future.error(StateError('channel unavailable'));
    container.read(runTimeProvider.notifier).value = 1;
    container
        .read(vpnSettingProvider.notifier)
        .update((state) => state.copyWith(ipv6: true));
    await tester.pump(const Duration(milliseconds: 601));
    expect(
      find.text(currentAppLocalizations.vpnConfigChangeDetected),
      findsNothing,
    );
    readOptions = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 601));
    expect(
      find.text(currentAppLocalizations.vpnConfigChangeDetected),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await drainTimers(tester);
  });
}

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/core_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Setup extends SetupAction {
  int reloads = 0;
  int updates = 0;

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    reloads++;
    return true;
  }

  @override
  Future<void> updateConfig() async {
    updates++;
  }
}

void main() {
  const profile = Profile(id: 1, autoUpdateDuration: Duration.zero);
  const rule = Rule(id: 10, content: 'example.com', ruleTarget: 'DIRECT');
  late db.Database database;
  late ProviderContainer container;
  late _Setup setup;

  setUp(() {
    database = db.Database(NativeDatabase.memory());
    db.database = database;
    setup = _Setup();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        initProvider.overrideWithBuild((_, _) => true),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        setupActionProvider.overrideWith(() => setup),
      ],
    );
    globalState.container = container;
  });

  tearDown(() async {
    debouncer.cancel(FunctionTag.applyProfile);
    debouncer.cancel(FunctionTag.updateConfig);
    container.dispose();
    await database.close();
  });

  Future<void> settleDatabase(WidgetTester tester) async {
    await tester.runAsync(() async => pumpEventQueue());
    await tester.pump();
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.runAsync(
      () => database.profilesDao.putAll([profile.toCompanion()]),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: CoreManager(child: SizedBox())),
      ),
    );
    await settleDatabase(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(setup.reloads, 0);
  }

  testWidgets('coalesces reload-only changes and preserves hot updates', (
    tester,
  ) async {
    await mount(tester);
    container.read(overrideDnsProvider.notifier).value = true;
    container.read(overrideNtpProvider.notifier).value = true;
    container
        .read(networkSettingProvider.notifier)
        .update((state) => state.copyWith(appendSystemDns: true));
    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            dns: state.dns.copyWith(nameserver: ['1.1.1.1']),
            ntp: state.ntp.copyWith(server: 'time.example.com'),
            hosts: {'example.com': '127.0.0.1'},
            port: 8080,
            keepAliveInterval: 40,
            interfaceName: 'eth0',
            interfaceNameMode: InterfaceNameMode.custom,
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 599));
    expect(setup.reloads, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(setup.reloads, 1);
    expect(setup.updates, 0);

    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) =>
              state.copyWith(mode: Mode.direct, mixedPort: 7891, ipv6: true),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(setup.reloads, 1);
    expect(setup.updates, 1);
  });

  testWidgets(
    'reloads persisted effective rule edits and refreshes setup state',
    (tester) async {
      await mount(tester);
      container.listen(setupStateProvider(1), (_, _) {});
      await tester.runAsync(() => container.read(setupStateProvider(1).future));

      Future<void> persist(Future<void> Function() write, int expected) async {
        await tester.runAsync(write);
        await settleDatabase(tester);
        await tester.pump(const Duration(milliseconds: 700));
        expect(setup.reloads, expected);
      }

      await persist(() => database.rulesDao.putGlobalRule(rule), 1);
      final updated = rule.copyWith(content: 'changed.com');
      await persist(() => database.rulesDao.putGlobalRule(updated), 2);
      final snapshot = await tester.runAsync(
        () => container.read(setupStateProvider(1).future),
      );
      expect(snapshot!.addedRules.single.content, 'changed.com');

      await persist(() async {
        await database.rulesDao.putDisabledLink(1, rule.id);
      }, 3);
      await persist(() => database.rulesDao.putGlobalRule(rule), 3);
      await persist(() async {
        await database.rulesDao.delDisabledLink(1, rule.id);
      }, 4);
      await persist(() => database.rulesDao.delRules([rule.id]), 5);
    },
  );

  testWidgets(
    'ignores inactive profiles, script mode and disconnected changes',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        await database.profilesDao.putAll([
          profile.copyWith(id: 2).toCompanion(),
        ]);
        await database.rulesDao.putProfileAddedRule(2, rule);
      });
      await settleDatabase(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(setup.reloads, 0);

      container
          .read(profilesProvider.notifier)
          .put(profile.copyWith(overwriteType: OverwriteType.script));
      await tester.pump();
      await tester.runAsync(() => database.rulesDao.putGlobalRule(rule));
      await settleDatabase(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(setup.reloads, 0);

      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      container.read(overrideDnsProvider.notifier).value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(setup.reloads, 0);
    },
  );

  testWidgets('reordering added rules triggers reload after persistence', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await database.rulesDao.putGlobalRule(rule.copyWith(order: 'a0'));
      await database.rulesDao.putGlobalRule(
        rule.copyWith(id: 11, content: 'second.com', order: 'a1'),
      );
    });
    await mount(tester);
    await tester.runAsync(
      () => database.rulesDao.orderGlobalRule(ruleId: 11, order: 'Zz'),
    );
    await settleDatabase(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(setup.reloads, 1);
    expect(container.read(activeAddedRulesProvider).rules.value!.first.id, 11);
  });
}

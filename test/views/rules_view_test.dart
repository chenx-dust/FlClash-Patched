import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/rules/rules.dart';
import 'package:fl_clash/views/rules/query.dart';
import 'package:fl_clash/views/config/rules.dart';
import 'package:fl_clash/views/profiles/overwrite/overwrite.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';
import '../helpers/test_database_providers.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _ProfileRules extends ProfileAddedRules {
  _ProfileRules(this.rules);

  final List<Rule> rules;

  @override
  Stream<List<Rule>> build(int profileId) => Stream.value(rules);
}

class _Setup extends SetupAction {
  @override
  void autoApplyProfile() {}
}

void main() {
  late _Core core;
  late ProviderContainer container;
  Profile? profile;
  List<Rule> addedRules = [];
  List<Rule> profileRules = [];
  const rule = CoreRule(
    index: 7,
    type: 'Domain',
    payload: 'example.com',
    proxy: 'DIRECT',
    hitCount: 12,
  );

  setUpAll(() => registerFallbackValue(rule.toDisabledParams(true)));

  setUp(() {
    core = _Core();
    when(() => core.getRules()).thenAnswer((_) async => [rule]);
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        currentProfileProvider.overrideWith((_) => profile),
        profileAddedRulesProvider(
          1,
        ).overrideWith(() => _ProfileRules(profileRules)),
        globalRulesProvider.overrideWith(() => TestGlobalRules(addedRules)),
        profileProvider(1).overrideWith((_) => profile),
        clashConfigProvider(1).overrideWith((_) async => const ClashConfig()),
        setupActionProvider.overrideWith(_Setup.new),
        addedRulesStreamProvider(
          1,
        ).overrideWith((_) => Stream.value(addedRules)),
      ],
    );
    globalState.container = container;
    container.listen(coreStatusProvider, (_, _) {});
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
  });

  tearDown(() {
    container.dispose();
    profile = null;
    addedRules = [];
    profileRules = [];
  });

  Future<void> pumpView(WidgetTester tester, {double width = 800}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).update((_) => Size(width, 800));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('en'), child: RulesView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> closeView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('opens rule query through the scoped core', (tester) async {
    const params = RuleQueryParams(target: 'example.com');
    when(() => core.queryRule(params)).thenAnswer(
      (_) async => const RuleQuery(
        target: 'example.com',
        port: 443,
        network: Network.tcp,
        mode: Mode.rule,
        rule: 'DomainSuffix',
        rulePayload: 'example.com',
        proxy: 'DIRECT',
        ip: '',
        delay: 0,
      ),
    );
    await pumpView(tester);
    await tester.tap(find.byTooltip('Query rules'));
    await tester.pumpAndSettle();
    expect(find.byType(RuleQueryDialog), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'example.com');
    await tester.tap(find.text('Query'));
    await tester.pumpAndSettle();
    verify(() => core.queryRule(params)).called(1);
    expect(find.text('DomainSuffix(example.com)'), findsNWidgets(2));
    await closeView(tester);
  });

  testWidgets('tags added rules by original order even after searching', (
    tester,
  ) async {
    profile = const Profile(
      id: 1,
      autoUpdateDuration: Duration.zero,
      matchTarget: 'DIRECT',
    );
    addedRules = [
      const Rule(content: 'first.com', ruleTarget: 'DIRECT'),
      const Rule(content: 'example.com', ruleTarget: 'MATCH'),
    ];
    when(() => core.getRules()).thenAnswer(
      (_) async => [
        rule.copyWith(index: 0, payload: 'first.com'),
        rule.copyWith(index: 1, disabled: true),
        rule.copyWith(index: 2),
      ],
    );
    await pumpView(tester, width: 360);
    expect(find.text('Added rules', findRichText: true), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    tester
        .widget<CommonScaffold>(find.byType(CommonScaffold))
        .searchState!
        .onSearch('example.com');
    await tester.pumpAndSettle();
    expect(find.text('Added rules', findRichText: true), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
    await closeView(tester);
  });

  for (final overwriteType in [OverwriteType.script, OverwriteType.custom]) {
    testWidgets('does not tag rules in $overwriteType mode', (tester) async {
      profile = Profile(
        id: 1,
        autoUpdateDuration: Duration.zero,
        overwriteType: overwriteType,
      );
      addedRules = [const Rule(content: 'example.com', ruleTarget: 'DIRECT')];
      when(
        () => core.getRules(),
      ).thenAnswer((_) async => [rule.copyWith(index: 0)]);
      await pumpView(tester);
      expect(find.text('Added rules', findRichText: true), findsNothing);
      await closeView(tester);
    });
  }

  testWidgets('does not tag stale rules at an added rule position', (
    tester,
  ) async {
    profile = const Profile(id: 1, autoUpdateDuration: Duration.zero);
    addedRules = [const Rule(content: 'changed.com', ruleTarget: 'DIRECT')];
    when(
      () => core.getRules(),
    ).thenAnswer((_) async => [rule.copyWith(index: 0)]);
    await pumpView(tester);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('Added rules', findRichText: true), findsNothing);
    await closeView(tester);
  });

  for (final isProfileRule in [true, false]) {
    testWidgets(
      'added tag opens ${isProfileRule ? 'profile' : 'global'} rules',
      (tester) async {
        profile = const Profile(id: 1, autoUpdateDuration: Duration.zero);
        addedRules = [
          const Rule(id: 42, content: 'example.com', ruleTarget: 'DIRECT'),
        ];
        profileRules = isProfileRule ? addedRules : [];
        when(
          () => core.getRules(),
        ).thenAnswer((_) async => [rule.copyWith(index: 0)]);
        await pumpView(tester, width: 360);
        await tester.tap(find.text('Added rules', findRichText: true));
        await tester.pumpAndSettle();
        if (isProfileRule) {
          expect(find.byType(OverwriteView), findsOneWidget);
          expect(
            tester.widget<OverwriteView>(find.byType(OverwriteView)).profileId,
            1,
          );
        } else {
          expect(find.byType(AddedRulesView), findsOneWidget);
        }
        expect(find.byType(AdaptiveSheetScaffold), findsNothing);
        expect(tester.takeException(), isNull);
        globalState.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(RulesView), findsOneWidget);
        expect(find.text('Added rules', findRichText: true), findsOneWidget);
        await closeView(tester);
      },
    );
  }

  ExternalProvider seedRuleProvider({
    String type = 'Rule',
    String vehicle = 'HTTP',
  }) {
    final provider = ExternalProvider(
      name: 'ads',
      type: type,
      vehicleType: vehicle,
      count: 10,
      updateAt: DateTime.utc(2026),
    );
    container.listen(providersProvider, (_, _) {});
    container.read(providersProvider.notifier).value = [provider];
    when(() => core.getRules()).thenAnswer(
      (_) async => [
        rule.copyWith(type: 'RuleSet', payload: 'ads', size: 10),
        rule.copyWith(index: 8, type: 'RuleSet', payload: 'ads', size: 10),
      ],
    );
    return provider;
  }

  testWidgets(
    'updates a referenced ruleset and locks all references while pending',
    (tester) async {
      final provider = seedRuleProvider();
      final response = Completer<String>();
      when(
        () => core.updateExternalProvider('ads'),
      ).thenAnswer((_) => response.future);
      when(
        () => core.getExternalProvider('ads'),
      ).thenAnswer((_) async => provider.copyWith(count: 25));
      await pumpView(tester, width: 360);
      await tester.tap(find.byTooltip('Sync: ads').first);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      for (final button in tester.widgetList<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Sync: ads',
        ),
      )) {
        expect(button.onPressed, isNull);
      }
      when(() => core.getRules()).thenAnswer(
        (_) async => [rule.copyWith(type: 'RuleSet', payload: 'ads', size: 25)],
      );
      response.complete('');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      verify(() => core.updateExternalProvider('ads')).called(1);
      verify(() => core.getRules()).called(2);
      expect(container.read(providersProvider).single.count, 25);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('ads', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('25 rules'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeView(tester);
    },
  );

  testWidgets('failed ruleset updates report errors and allow retry', (
    tester,
  ) async {
    seedRuleProvider();
    when(
      () => core.updateExternalProvider('ads'),
    ).thenThrow(Exception('download failed'));
    await pumpView(tester);
    await tester.tap(find.byTooltip('Sync: ads').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('download failed'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find
                .byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Sync: ads',
                )
                .first,
          )
          .onPressed,
      isNotNull,
    );
    verifyNever(() => core.getExternalProvider('ads'));
    await closeView(tester);
  });

  for (final (type, vehicle) in [
    ('Rule', 'File'),
    ('Rule', 'Inline'),
    ('Proxy', 'HTTP'),
  ]) {
    testWidgets('does not offer ruleset download for $type $vehicle', (
      tester,
    ) async {
      seedRuleProvider(type: type, vehicle: vehicle);
      await pumpView(tester);
      expect(find.byTooltip('Sync: ads'), findsNothing);
      await closeView(tester);
    });
  }

  testWidgets('ruleset completion after disposal does not refresh the view', (
    tester,
  ) async {
    final provider = seedRuleProvider();
    final response = Completer<String>();
    when(
      () => core.updateExternalProvider('ads'),
    ).thenAnswer((_) => response.future);
    when(
      () => core.getExternalProvider('ads'),
    ).thenAnswer((_) async => provider);
    await pumpView(tester);
    await tester.tap(find.byTooltip('Sync: ads').first);
    await tester.pump();
    await closeView(tester);
    response.complete('');
    await tester.pumpAndSettle();
    verify(() => core.getRules()).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows rule order and searches target, type and payload', (
    tester,
  ) async {
    await pumpView(tester, width: 360);
    expect(find.text('#8'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('Hits 12 · Misses 0'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Hits 12 · Misses 0')).dy,
      lessThan(tester.getTopLeft(find.text('example.com')).dy),
    );
    final statistics = tester.getRect(find.text('Hits 12 · Misses 0'));
    final toggle = tester.getRect(find.byType(Switch));
    expect(statistics.right, closeTo(toggle.right, 0.01));
    expect(statistics.bottom, lessThan(toggle.top));
    for (final query in ['direct', 'domain', 'EXAMPLE']) {
      tester
          .widget<CommonScaffold>(find.byType(CommonScaffold))
          .searchState!
          .onSearch(query);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('example.com'), findsOneWidget);
    }
    final search = tester
        .widget<CommonScaffold>(find.byType(CommonScaffold))
        .searchState!;
    search.onRegexChange!(true);
    search.onSearch('[');
    await tester.pumpAndSettle();
    expect(find.text('example.com'), findsNothing);
    expect(tester.takeException(), isNull);
    await closeView(tester);
  });

  testWidgets(
    'debounces switch changes without loading or disabling controls',
    (tester) async {
      final response = Completer<bool>();
      when(
        () => core.setRuleDisabled(any()),
      ).thenAnswer((_) => response.future);
      await pumpView(tester);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      verifyNever(() => core.setRuleDisabled(any()));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      verify(() => core.setRuleDisabled(rule.toDisabledParams(true))).called(1);
      when(
        () => core.getRules(),
      ).thenAnswer((_) async => [rule.copyWith(disabled: true)]);
      response.complete(true);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
      await closeView(tester);
    },
  );

  testWidgets('rejected change refreshes the rule and reports failure', (
    tester,
  ) async {
    when(() => core.setRuleDisabled(any())).thenAnswer((_) async => false);
    await pumpView(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not change the rule.'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    verify(() => core.getRules()).called(2);
    await closeView(tester);
  });

  testWidgets('queues the latest switch intent behind an in-flight change', (
    tester,
  ) async {
    final response = Completer<bool>();
    when(() => core.setRuleDisabled(any())).thenAnswer((_) => response.future);
    await pumpView(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 600));
    verify(() => core.setRuleDisabled(rule.toDisabledParams(true))).called(1);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 600));
    verifyNever(() => core.setRuleDisabled(rule.toDisabledParams(false)));
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    response.complete(true);
    await tester.pumpAndSettle();
    verify(() => core.setRuleDisabled(rule.toDisabledParams(false))).called(1);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await closeView(tester);
  });

  testWidgets('disposal cancels a debounced switch change', (tester) async {
    await pumpView(tester);
    await tester.tap(find.byType(Switch));
    await closeView(tester);
    await tester.pump(const Duration(seconds: 1));
    verifyNever(() => core.setRuleDisabled(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed mutation releases the controls for retry', (
    tester,
  ) async {
    when(
      () => core.setRuleDisabled(any()),
    ).thenThrow(Exception('rule failure'));
    await pumpView(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.textContaining('rule failure'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    await closeView(tester);
  });

  testWidgets('disconnect discards an in-flight response', (tester) async {
    final response = Completer<List<CoreRule>>();
    when(() => core.getRules()).thenAnswer((_) => response.future);
    await pumpView(tester);
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await tester.pump();
    response.complete([rule]);
    await tester.pumpAndSettle();
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('example.com'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    verify(() => core.getRules()).called(1);
    await closeView(tester);
  });

  testWidgets('refreshes statistics and ignores completion after disposal', (
    tester,
  ) async {
    await pumpView(tester);
    when(
      () => core.getRules(),
    ).thenAnswer((_) async => [rule.copyWith(hitCount: 25)]);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('Hits 25 · Misses 0'), findsOneWidget);
    final response = Completer<List<CoreRule>>();
    when(() => core.getRules()).thenAnswer((_) => response.future);
    await tester.pump(const Duration(seconds: 5));
    await closeView(tester);
    response.complete([rule]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('polling keeps rows stable and switches interactive', (
    tester,
  ) async {
    await pumpView(tester);
    final position = tester.getTopLeft(find.text('example.com'));
    final response = Completer<List<CoreRule>>();
    when(() => core.getRules()).thenAnswer((_) => response.future);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.getTopLeft(find.text('example.com')), position);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    response.complete([rule.copyWith(hitCount: 25)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Hits 25 · Misses 0'), findsOneWidget);
    expect(tester.getTopLeft(find.text('example.com')), position);
    await closeView(tester);
  });

  testWidgets('a switch change supersedes a pending background refresh', (
    tester,
  ) async {
    await pumpView(tester);
    final response = Completer<List<CoreRule>>();
    when(() => core.getRules()).thenAnswer((_) => response.future);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    when(() => core.setRuleDisabled(any())).thenAnswer((_) async => true);
    when(
      () => core.getRules(),
    ).thenAnswer((_) async => [rule.copyWith(disabled: true)]);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    response.complete([rule]);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await closeView(tester);
  });

  testWidgets('failed loads recover through polling without a refresh button', (
    tester,
  ) async {
    when(() => core.getRules()).thenThrow(Exception('load failure'));
    await pumpView(tester);
    expect(find.textContaining('load failure'), findsOneWidget);
    when(() => core.getRules()).thenAnswer((_) async => []);
    expect(find.byTooltip('Sync'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('load failure'), findsNothing);
    expect(find.byType(NullStatus), findsOneWidget);
    await closeView(tester);
  });

  testWidgets('shows all rules without filters or a count header', (
    tester,
  ) async {
    when(() => core.getRules()).thenAnswer(
      (_) async => [
        rule,
        rule.copyWith(index: 15, payload: 'disabled.example', disabled: true),
      ],
    );
    await pumpView(tester);
    expect(find.byTooltip('Filter'), findsNothing);
    expect(find.text('2 rules'), findsNothing);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('disabled.example'), findsOneWidget);
    expect(find.text('#16'), findsOneWidget);
    await closeView(tester);
  });

  testWidgets('details show rule size and timestamps on a narrow screen', (
    tester,
  ) async {
    when(() => core.getRules()).thenAnswer(
      (_) async => [rule.copyWith(size: 123, hitAt: DateTime(2026, 10, 6, 12))],
    );
    await pumpView(tester, width: 360);
    await tester.tap(find.text('example.com'));
    await tester.pumpAndSettle();
    expect(find.text('123 rules'), findsOneWidget);
    await tester.ensureVisible(find.text('Last hit'));
    await tester.pumpAndSettle();
    expect(find.text('Last hit'), findsOneWidget);
    expect(find.text('Last miss'), findsNothing);
    expect(tester.takeException(), isNull);
    await closeView(tester);
  });

  testWidgets('expands nested proxy groups and follows selection changes', (
    tester,
  ) async {
    container.listen(groupsProvider, (_, _) {});
    const outer = Group(type: GroupType.Selector, name: 'route', now: 'auto');
    const inner = Group(type: GroupType.URLTest, name: 'auto', now: 'node-a');
    container.read(groupsProvider.notifier).value = [outer, inner];
    when(
      () => core.getRules(),
    ).thenAnswer((_) async => [rule.copyWith(proxy: 'route')]);
    await pumpView(tester, width: 360);
    expect(find.text('route', findRichText: true), findsOneWidget);
    expect(find.text('auto', findRichText: true), findsNothing);
    expect(find.text('node-a', findRichText: true), findsOneWidget);
    await tester.tap(find.text('...', findRichText: true));
    await tester.pump();
    expect(find.text('auto', findRichText: true), findsOneWidget);
    container.read(groupsProvider.notifier).value = [
      outer,
      inner.copyWith(now: 'node-b'),
    ];
    await tester.pump();
    expect(find.text('node-a', findRichText: true), findsNothing);
    expect(find.text('node-b', findRichText: true), findsOneWidget);
    container.read(groupsProvider.notifier).value = [
      outer,
      inner.copyWith(now: 'route'),
    ];
    await tester.pump();
    expect(find.text('route', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    await closeView(tester);
  });

  testWidgets('hidden pages stop polling and refresh on return', (
    tester,
  ) async {
    Future<void> show(bool active) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            locale: const Locale('en'),
            child: PageActivityScope(
              isActive: active,
              child: const RulesView(),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await show(true);
    verify(() => core.getRules()).called(1);
    await show(false);
    await tester.pump(const Duration(seconds: 10));
    verifyNever(() => core.getRules());
    await show(true);
    verify(() => core.getRules()).called(1);
    await closeView(tester);
  });
}

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/views/proxies/proxies.dart';
import 'package:fl_clash/views/proxies/tab.dart';
import 'package:fl_clash/views/rules/rules.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

void main() {
  late ProviderContainer container;
  late _Core core;
  final nodes = List.generate(
    80,
    (index) => Proxy(name: 'node-$index', type: 'Shadowsocks'),
  );

  setUp(() {
    core = _Core();
    when(() => core.getRules()).thenAnswer(
      (_) async => [
        const CoreRule(
          index: 0,
          type: 'Domain',
          payload: 'example.com',
          proxy: 'route',
        ),
        const CoreRule(index: 1, type: 'Match', payload: '', proxy: 'DIRECT'),
      ],
    );
    final profile = Profile.normal().copyWith(currentGroupName: 'route');
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
      ],
    );
    globalState.container = container;
    container.listen(currentProfileProvider, (_, _) {});
    container.listen(coreStatusProvider, (_, _) {});
    container.listen(groupsProvider, (_, _) {});
    container.listen(proxiesStyleSettingProvider, (_, _) {});
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container.read(currentPageLabelProvider.notifier).toPage(PageLabel.rules);
    container.read(groupsProvider.notifier).value = [
      const Group(
        type: GroupType.Selector,
        name: 'route',
        now: 'destination',
        all: [Proxy(name: 'destination', type: 'Selector')],
      ),
      for (var index = 0; index < 15; index++)
        Group(
          type: GroupType.Selector,
          name: 'other-$index',
          all: nodes,
          now: 'node-65',
        ),
      Group(
        type: GroupType.Selector,
        name: 'destination',
        hidden: true,
        now: 'node-65',
        all: nodes,
      ),
    ];
  });

  tearDown(() => container.dispose());

  Future<void> pumpViews(
    WidgetTester tester,
    ProxiesType type, {
    double width = 800,
    bool routedRules = false,
    bool lazyProxies = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).update((_) => Size(width, 800));
    if (routedRules) {
      container.read(currentPageLabelProvider.notifier).toPage(PageLabel.tools);
    }
    container
        .read(proxiesStyleSettingProvider.notifier)
        .update((state) => state.copyWith(type: type));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: const Locale('en'),
          child: Consumer(
            builder: (_, ref, _) {
              final isProxies =
                  ref.watch(currentPageLabelProvider) == PageLabel.proxies;
              return IndexedStack(
                index: isProxies ? 1 : 0,
                children: [
                  PageActivityScope(
                    isActive: !isProxies,
                    child: routedRules
                        ? Scaffold(
                            body: ListItem.open(
                              title: const Text('Open rules'),
                              widget: const RulesView(),
                            ),
                          )
                        : const RulesView(),
                  ),
                  if (!lazyProxies || isProxies)
                    const ProxiesView()
                  else
                    const SizedBox(),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (routedRules) {
      await tester.tap(find.text('Open rules'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> closeViews(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('list jump expands an already laid out collapsed group', (
    tester,
  ) async {
    final groups = container.read(groupsProvider);
    container.read(groupsProvider.notifier).value = [
      groups.first,
      groups.last.copyWith(hidden: false),
    ];
    await pumpViews(tester, ProxiesType.list);
    await tester.tap(find.text('node-65', findRichText: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final target = find.byWidgetPredicate(
      (widget) =>
          widget is ProxyCard &&
          widget.groupName == 'destination' &&
          widget.proxy.name == 'node-65',
    );
    expect(target.hitTestable(), findsOneWidget);
    await closeViews(tester);
  });

  for (final type in ProxiesType.values) {
    for (final width in [360.0, 800.0]) {
      testWidgets('$type closes the tools route at width $width', (
        tester,
      ) async {
        await pumpViews(
          tester,
          type,
          width: width,
          routedRules: true,
          lazyProxies: width == 360,
        );
        await tester.tap(
          find
              .descendant(
                of: find.byType(RulesView),
                matching: find.text('node-65', findRichText: true),
              )
              .first,
        );
        await tester.pumpAndSettle();
        final target = find.byWidgetPredicate(
          (widget) =>
              widget is ProxyCard &&
              widget.groupName == 'destination' &&
              widget.proxy.name == 'node-65',
        );
        expect(target.hitTestable(), findsOneWidget);
        expect(find.byType(RulesView), findsNothing);
        expect(tester.takeException(), isNull);
        await closeViews(tester);
      });
    }
    for (final details in [false]) {
      testWidgets(
        '$type locates a node in its hidden chain group, details=$details',
        (tester) async {
          await pumpViews(tester, type, width: details ? 360 : 800);
          final proxiesView = find.byType(ProxiesView, skipOffstage: false);
          tester
              .state<CommonScaffoldState>(
                find.descendant(
                  of: proxiesView,
                  matching: find.byType(CommonScaffold, skipOffstage: false),
                ),
              )
              .handleToSearch();
          await tester.pumpAndSettle();
          final searchField = tester.widget<TextField>(
            find.descendant(
              of: proxiesView,
              matching: find.byType(TextField, skipOffstage: false),
            ),
          );
          searchField.controller!.text = 'no match';
          searchField.onChanged!('no match');
          container.read(queryProvider(QueryTag.proxies).notifier).value =
              'no match';
          container
              .read(proxiesStyleSettingProvider.notifier)
              .update((state) => state.copyWith(hideUnavailable: true));
          container
              .read(delayDataSourceProvider.notifier)
              .setDelay(
                Delay(
                  name: 'node-65',
                  url: container.read(appSettingProvider).testUrl,
                  value: -1,
                ),
              );
          await tester.pumpAndSettle();
          if (details) {
            await tester.tap(find.text('example.com'));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('node-65', findRichText: true));
          await tester.pumpAndSettle();
          expect(container.read(currentPageLabelProvider), PageLabel.proxies);
          expect(container.read(currentProfileProvider)?.selectedMap, isEmpty);
          expect(
            container.read(currentProfileProvider)?.unfoldSet,
            contains('destination'),
          );
          expect(
            container.read(proxiesStyleSettingProvider).showHiddenGroups,
            isFalse,
          );
          final card = find.byWidgetPredicate(
            (widget) =>
                widget is ProxyCard &&
                widget.groupName == 'destination' &&
                widget.proxy.name == 'node-65',
          );
          expect(card.hitTestable(), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(container.read(queryProvider(QueryTag.proxies)), isEmpty);
          expect(
            container.read(proxiesStyleSettingProvider).hideUnavailable,
            isTrue,
          );
          container.read(queryProvider(QueryTag.proxies).notifier).value =
              'no match';
          await tester.pumpAndSettle();
          expect(card, findsNothing);
          expect(find.text('Rule details'), findsNothing);
          expect(tester.takeException(), isNull);
          await closeViews(tester);
        },
      );
    }

    testWidgets('$type opens a clicked group and supports a second jump', (
      tester,
    ) async {
      await pumpViews(tester, type);
      await tester.tap(find.text('...', findRichText: true));
      await tester.pump();
      await tester.tap(find.text('destination', findRichText: true));
      await tester.pumpAndSettle();
      if (type == ProxiesType.tab) {
        expect(
          tester
              .state<ProxiesTabViewState>(find.byType(ProxiesTabView))
              .currentGroup
              ?.name,
          'destination',
        );
      }
      final firstNode = find.byWidgetPredicate(
        (widget) =>
            widget is ProxyCard &&
            widget.groupName == 'destination' &&
            widget.proxy.name == 'node-0',
      );
      expect(firstNode.hitTestable(), findsOneWidget);
      container.read(currentPageLabelProvider.notifier).toPage(PageLabel.rules);
      await tester.pumpAndSettle();
      expect(container.read(proxyFocusProvider), isNull);
      await tester.tap(find.text('node-65', findRichText: true));
      await tester.pumpAndSettle();
      final target = find.byWidgetPredicate(
        (widget) =>
            widget is ProxyCard &&
            widget.groupName == 'destination' &&
            widget.proxy.name == 'node-65',
      );
      expect(target.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeViews(tester);
    });
  }

  testWidgets('built-in targets are not clickable', (tester) async {
    await pumpViews(tester, ProxiesType.list);
    final direct = tester.widget<TonalChip>(
      find.ancestor(
        of: find.text('DIRECT', findRichText: true),
        matching: find.byType(TonalChip),
      ),
    );
    expect(direct.onPressed, isNull);
    await closeViews(tester);
  });
}

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/list.dart';
import 'package:fl_clash/views/proxies/tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

void main() {
  late ProviderContainer globalContainer;
  late ProviderSubscription<Profile?> currentProfileSubscription;
  late _MockCoreHandlerInterface coreHandler;

  setUpAll(() {
    registerFallbackValue(
      const ChangeProxyParams(groupName: '', proxyName: ''),
    );
  });

  setUp(() {
    coreHandler = _MockCoreHandlerInterface();
    CoreController.resetInstance();
    CoreController.test(coreHandler);
    when(() => coreHandler.changeProxy(any())).thenAnswer((_) async => '');
    when(() => coreHandler.closeConnections()).thenAnswer((_) async => true);
    when(
      () => coreHandler.getProxies(),
    ).thenAnswer((_) async => _proxiesData());
    final profile = Profile.normal().copyWith(
      currentGroupName: 'B',
      selectedMap: {'A': 'Node A', 'B': 'Node B'},
    );
    globalContainer = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        profilesProvider.overrideWith(() => _TestProfiles([profile])),
        currentGroupsStateProvider.overrideWithValue(
          GroupsState(value: [_group('A'), _group('B'), _group('C')]),
        ),
      ],
    );
    globalState.container = globalContainer;
    currentProfileSubscription = globalContainer.listen(
      currentProfileProvider,
      (_, _) {},
    );
  });

  tearDown(() {
    debouncer.cancel(FunctionTag.changeProxy);
    debouncer.cancel(FunctionTag.updateGroups);
    currentProfileSubscription.close();
    globalContainer.dispose();
    CoreController.resetInstance();
  });

  testWidgets('current group follows the rendered tab list', (tester) async {
    final key = GlobalKey<ProxiesTabViewState>();
    final renderedGroups = [_group('B'), _group('C')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proxiesTabStateProvider.overrideWithValue(
            ProxiesTabState(
              groups: renderedGroups,
              currentGroupName: 'B',
              proxyCardType: ProxyCardType.standard,
              columns: 2,
            ),
          ),
        ],
        child: _TestApp(child: ProxiesTabView(key: key)),
      ),
    );
    await tester.pump();

    expect(key.currentState?.currentGroup?.name, 'B');

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    tabBar.controller?.animateTo(1);
    await tester.pumpAndSettle();

    expect(key.currentState?.currentGroup?.name, 'C');
    expect(globalContainer.read(currentProfileProvider)?.currentGroupName, 'C');
  });

  testWidgets('long pressing a tab resets its proxy selection', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proxiesTabStateProvider.overrideWithValue(
            ProxiesTabState(
              groups: [_group('A'), _group('B')],
              currentGroupName: 'B',
              proxyCardType: ProxyCardType.standard,
              columns: 2,
            ),
          ),
        ],
        child: const _TestApp(child: ProxiesTabView()),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byKey(const ValueKey('proxy-group-tab-B')));
    await _pumpUntilSelectionReset(tester, globalContainer, 'B');

    expect(globalContainer.read(currentProfileProvider)?.selectedMap['B'], '');

    verify(
      () => coreHandler.changeProxy(
        const ChangeProxyParams(groupName: 'B', proxyName: ''),
      ),
    ).called(1);
    verify(() => coreHandler.getProxies()).called(1);
  });

  testWidgets('long pressing a list header resets its proxy selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proxiesListStateProvider.overrideWithValue(
            ProxiesListState(
              groups: [_group('A')],
              currentUnfoldSet: {},
              proxyCardType: ProxyCardType.standard,
              columns: 2,
            ),
          ),
        ],
        child: const _TestApp(child: ProxiesListView()),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byKey(const Key('A')).first);
    await _pumpUntilSelectionReset(tester, globalContainer, 'A');

    expect(globalContainer.read(currentProfileProvider)?.selectedMap['A'], '');

    verify(
      () => coreHandler.changeProxy(
        const ChangeProxyParams(groupName: 'A', proxyName: ''),
      ),
    ).called(1);
    verify(() => coreHandler.getProxies()).called(1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> _pumpUntilSelectionReset(
  WidgetTester tester,
  ProviderContainer container,
  String groupName,
) async {
  for (var i = 0; i < 100; i++) {
    if (container.read(currentProfileProvider)?.selectedMap[groupName] == '') {
      return;
    }
    await tester.pump(const Duration(milliseconds: 10));
  }
}

ProxiesData _proxiesData() {
  return ProxiesData(
    all: ['A', 'B', 'Node A', 'Node B'],
    proxies: Map<String, dynamic>.from({
      'A': {
        'name': 'A',
        'type': 'Selector',
        'all': ['Node A'],
        'now': 'Node A',
      },
      'B': {
        'name': 'B',
        'type': 'Selector',
        'all': ['Node B'],
        'now': 'Node B',
      },
      'Node A': {'name': 'Node A', 'type': 'Shadowsocks'},
      'Node B': {'name': 'Node B', 'type': 'Shadowsocks'},
    }),
  );
}

Group _group(String name) {
  return Group(type: GroupType.Selector, name: name);
}

class _TestProfiles extends Profiles {
  final List<Profile> initial;

  _TestProfiles(this.initial);

  @override
  List<Profile> build() => initial;

  @override
  void put(Profile profile) {
    final next = List<Profile>.from(state);
    final index = next.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      next.add(profile);
    } else {
      next[index] = profile;
    }
    state = next;
  }
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalState.navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        globalState.measure = Measure.of(context, 1);
        globalState.theme = CommonTheme.of(context, 1);
        return child!;
      },
      home: Scaffold(body: child),
    );
  }
}

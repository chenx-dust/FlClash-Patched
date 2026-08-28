import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/list.dart';
import 'package:fl_clash/views/proxies/tab.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

void main() {
  late ProviderContainer globalContainer;
  late ProviderSubscription<Profile?> currentProfileSubscription;
  late _MockCoreHandlerInterface core;

  setUpAll(() {
    registerFallbackValue(
      const ChangeProxyParams(groupName: '', proxyName: ''),
    );
  });

  setUp(() {
    core = _MockCoreHandlerInterface();
    when(() => core.changeProxy(any())).thenAnswer((_) async => '');
    when(core.closeConnections).thenAnswer((_) async => true);
    when(core.getProxies).thenAnswer((_) async => _proxiesData());
    final profile = Profile.normal().copyWith(
      currentGroupName: 'B',
      selectedMap: {'A': 'Node A', 'B': 'Node B'},
    );
    globalContainer = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentGroupsStateProvider.overrideWithValue(
          GroupsState(value: [_group('A'), _group('B'), _group('C')]),
        ),
        proxiesTabStateProvider.overrideWithValue(
          ProxiesTabState(
            groups: [_group('B'), _group('C')],
            currentGroupName: 'B',
            proxyCardType: ProxyCardType.standard,
          ),
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
    debouncer.cancel((FunctionTag.changeProxy, 'A'));
    debouncer.cancel((FunctionTag.changeProxy, 'B'));
    debouncer.cancel(FunctionTag.updateGroups);
    currentProfileSubscription.close();
    globalContainer.dispose();
  });

  testWidgets('current group follows the rendered tab list', (tester) async {
    final key = GlobalKey<ProxiesTabViewState>();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: globalContainer,
        child: TestApp(
          child: ProxiesTabView(key: key),
          homeBuilder: (child) => Scaffold(body: child),
        ),
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
      UncontrolledProviderScope(
        container: globalContainer,
        child: TestApp(
          child: const ProxiesTabView(),
          homeBuilder: (child) => Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byKey(const ValueKey('proxy-group-tab-B')));
    await tester.pumpAndSettle();

    verify(
      () => core.changeProxy(
        const ChangeProxyParams(groupName: 'B', proxyName: ''),
      ),
    ).called(1);
  });

  testWidgets('long pressing a list header resets its proxy selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: globalContainer,
        child: TestApp(
          child: ListHeader(
            group: _group('A'),
            isExpand: false,
            onChange: (_) {},
            onScrollToSelected: (_) {},
          ),
          homeBuilder: (child) => Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byType(ListHeader));
    await tester.pumpAndSettle();

    verify(
      () => core.changeProxy(
        const ChangeProxyParams(groupName: 'A', proxyName: ''),
      ),
    ).called(1);
  });
}

Group _group(String name) {
  return Group(
    type: GroupType.Selector,
    name: name,
    all: [Proxy(name: 'Node $name', type: 'Shadowsocks')],
  );
}

ProxiesData _proxiesData() {
  return ProxiesData(
    all: const ['A', 'B', 'Node A', 'Node B'],
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

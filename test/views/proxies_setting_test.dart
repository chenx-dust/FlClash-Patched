import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/setting.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('bottom safe area belongs to the scrolling settings content', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          child: MediaQuery(
            data: MediaQueryData(viewPadding: EdgeInsets.only(bottom: 24)),
            child: SheetProvider(
              type: SheetType.bottomSheet,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AdaptiveSheetScaffold(
                  title: 'Settings',
                  bodyIncludesBottomSafeArea: true,
                  body: ProxiesSetting(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final scroll = find
        .descendant(
          of: find.byType(ProxiesSetting),
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    expect(
      tester.widget<SingleChildScrollView>(scroll).padding,
      const EdgeInsets.only(bottom: 56),
    );
    expect(
      tester.getBottomLeft(scroll).dy,
      tester.getBottomLeft(find.byType(AdaptiveSheetScaffold)).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('list options expand, collapse, and reverse smoothly', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        proxiesStyleSettingProvider.overrideWithBuild(
          (_, _) => const ProxiesStyleProps(type: ProxiesType.tab),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: Scaffold(body: ProxiesSetting())),
      ),
    );

    final options = find.byType(AnimatedCrossFade);
    double height() => tester.getSize(options).height;
    void select(ProxiesType type) {
      container
          .read(proxiesStyleSettingProvider.notifier)
          .update((state) => state.copyWith(type: type));
    }

    expect(height(), 0);
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump();
    expect(container.read(proxiesStyleSettingProvider).type, ProxiesType.list);
    await tester.pump(const Duration(milliseconds: 150));
    final expandingHeight = height();
    await tester.pumpAndSettle();
    final expandedHeight = height();
    expect(expandingHeight, greaterThan(0));
    expect(expandingHeight, lessThan(expandedHeight));

    select(ProxiesType.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(height(), greaterThan(0));
    expect(height(), lessThan(expandedHeight));

    select(ProxiesType.list);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(height(), expandedHeight);

    select(ProxiesType.tab);
    await tester.pumpAndSettle();
    expect(height(), 0);
    expect(tester.takeException(), isNull);
  });
}

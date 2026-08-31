import 'package:fl_clash/common/navigator.dart';
import 'package:fl_clash/models/config.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<Route<dynamic>> openListItem(
    WidgetTester tester, {
    required TargetPlatform platform,
    required bool predictiveBack,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      final container = ProviderContainer(
        overrides: [
          isMobileViewProvider.overrideWithValue(true),
          themeSettingProvider.overrideWithBuild(
            (_, _) => ThemeProps(predictiveBack: predictiveBack),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ListItem.open(
                title: const Text('Open'),
                widget: const Text('Detail'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      return ModalRoute.of(tester.element(find.text('Detail')))!;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('iOS list items use the themed page route', (tester) async {
    final route = await openListItem(
      tester,
      platform: TargetPlatform.iOS,
      predictiveBack: false,
    );

    expect(route, isA<CommonRoute<dynamic>>());
  });

  testWidgets('Android predictive back uses the themed page route', (
    tester,
  ) async {
    final route = await openListItem(
      tester,
      platform: TargetPlatform.android,
      predictiveBack: true,
    );

    expect(route, isA<CommonRoute<dynamic>>());
  });
}

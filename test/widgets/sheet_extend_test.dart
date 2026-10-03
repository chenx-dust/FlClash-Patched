import 'package:animations/animations.dart';
import 'package:fl_clash/application.dart';
import 'package:fl_clash/common/navigator.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> openExtend(
    WidgetTester tester, {
    required TargetPlatform platform,
    required bool predictiveBack,
  }) async {
    final container = ProviderContainer(
      overrides: [isMobileViewProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            platform: platform,
            pageTransitionsTheme: buildPageTransitionsTheme(
              predictiveBack: predictiveBack,
              isMobile: true,
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showExtend<void>(
                  context,
                  builder: (_) => const Scaffold(body: Text('extended')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  double opacityOf(WidgetTester tester, String text) {
    final fades = find.ancestor(
      of: find.text(text),
      matching: find.byType(FadeTransition),
    );
    var opacity = 1.0;
    for (final fade in tester.widgetList<FadeTransition>(fades)) {
      opacity *= fade.opacity.value;
    }
    return opacity;
  }

  testWidgets('android without predictive back keeps the page below in place', (
    tester,
  ) async {
    await openExtend(
      tester,
      platform: TargetPlatform.android,
      predictiveBack: false,
    );

    expect(opacityOf(tester, 'open'), 1);
    expect(find.byType(SharedAxisTransition), findsWidgets);

    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });

  testWidgets('android predictive back keeps the themed extend route', (
    tester,
  ) async {
    await openExtend(
      tester,
      platform: TargetPlatform.android,
      predictiveBack: true,
    );

    expect(find.byType(CommonPageTransition), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });

  testWidgets('iOS extend pages keep the themed route', (tester) async {
    await openExtend(
      tester,
      platform: TargetPlatform.iOS,
      predictiveBack: false,
    );

    expect(find.byType(CommonPageTransition), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('extended'), findsOneWidget);
  });
}

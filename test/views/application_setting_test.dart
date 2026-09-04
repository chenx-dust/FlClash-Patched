import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/application_setting.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('hides the close connection prompt on first build', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        appSettingProvider.overrideWithBuild(
          (_, _) => const AppSettingProps(closeConnections: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1400, 1400);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ApplicationSettingView()),
      ),
    );

    expect(find.text('Auto close connections'), findsOneWidget);
    expect(find.text('Close connections prompt'), findsNothing);
  });

  testWidgets('hides the close connection prompt when auto close is enabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1400, 1400);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ApplicationSettingView()),
      ),
    );

    expect(find.text('Close connections prompt'), findsOneWidget);

    await tester.tap(find.text('Auto close connections'));
    await tester.pump();

    expect(container.read(appSettingProvider).closeConnections, true);
    expect(find.text('Close connections prompt'), findsNothing);
  });

  testWidgets(
    'update interval submits from the keyboard and animates idle input',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(1400, 1400);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: ApplicationSettingView()),
        ),
      );
      await tester.tap(find.text('UI info update interval'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Form),
          matching: find.byType(AnimatedSize),
        ),
        findsOneWidget,
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, '7');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNothing);
      expect(container.read(appSettingProvider).foregroundTickerInterval, 7);
    },
  );
}

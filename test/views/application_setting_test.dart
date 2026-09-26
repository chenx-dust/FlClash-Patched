import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/config/advanced.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_app.dart';

Future<void> _scrollTo(WidgetTester tester, String text) {
  return tester.scrollUntilVisible(
    find.text(text),
    500,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _jumpToTop(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pump();
}

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
        child: const TestApp(child: GeneralView()),
      ),
    );

    await _scrollTo(tester, 'Auto close connections');
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
        child: const TestApp(child: GeneralView()),
      ),
    );

    await _scrollTo(tester, 'Close connections prompt');
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
          child: const TestApp(child: GeneralView()),
        ),
      );
      await _scrollTo(tester, 'UI info update interval');
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

  testWidgets('shows TV mode only when the device is not a television', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() {
      system.isTV = false;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1400, 1400);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ThemeView()),
      ),
    );

    await _scrollTo(tester, 'TV mode');
    expect(find.text('TV mode'), findsOneWidget);
    await tester.tap(find.text('TV mode'));
    await tester.pump();
    expect(container.read(appSettingProvider).tvMode, isTrue);
    expect(system.isTV, isFalse);

    system.isTV = true;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ThemeView()),
      ),
    );
    expect(find.text('TV mode'), findsNothing);
    expect(system.isTV, isTrue);
  });

  testWidgets('general page keeps every relocated setting', (tester) async {
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
        child: const TestApp(child: GeneralView()),
      ),
    );

    final labels = <String>[
      'Startup and background',
      if (system.isDesktop) ...['Auto launch', 'Silent launch'],
      'Auto run',
      'On demand',
      'Minimize on exit',
      if (system.isAndroid) ...[
        'Hide from recent tasks',
        'Collapse Quick Settings panel',
        'Stop button in notification',
      ],
      if (system.isAndroid || system.isMacOS) 'Show real-time network speed',
      'Requests and updates',
      'User-Agent',
      'Verify TLS certificates',
      'Inbound',
      'Port',
      'Allow LAN',
      'External controller',
      'Authentication',
      'Connection',
      'Test URL',
      'Unified delay',
      'TCP concurrent',
      if (system.isDesktop) 'TCP keep-alive interval',
      'Find process',
      'Auto close connections',
      'Close connections prompt',
      'Only count proxy traffic',
      'Core',
      'IPv6',
      'Hosts',
      'Append system DNS',
      'Geo low-memory mode',
      if (!system.isIOS) 'High performance Geo matcher',
      'Logs and diagnostics',
      'Log level',
      'Logcat',
      'App',
      'Back to dashboard',
      if (system.isDesktop) 'Show proxy selection in tray',
      'UI info update interval',
    ];
    for (final label in labels) {
      await _scrollTo(tester, label);
      expect(find.text(label), findsWidgets);
    }

    if (!system.isAndroid) {
      expect(find.text('Hide from recent tasks'), findsNothing);
      expect(find.text('Collapse Quick Settings panel'), findsNothing);
      expect(find.text('Stop button in notification'), findsNothing);
    }
    expect(find.text('High priority auto launch'), findsNothing);
    expect(find.text('Account'), findsNothing);
    expect(find.text('Auto check for updates'), findsNothing);
    expect(find.text('TV mode'), findsNothing);
    expect(find.text('Tab animation'), findsNothing);
    expect(find.text('Swipe to switch pages'), findsNothing);

    if (system.isDesktop) {
      await _jumpToTop(tester);
      await _scrollTo(tester, 'Auto launch');
      await tester.tap(find.text('Auto launch'));
      await tester.pump();
      if (system.isWindows) {
        await _scrollTo(tester, 'High priority auto launch');
        expect(find.text('High priority auto launch'), findsOneWidget);
      } else {
        expect(find.text('High priority auto launch'), findsNothing);
      }
    }

    await _jumpToTop(tester);
    await _scrollTo(tester, 'Authentication');
    await tester.tap(find.text('Authentication'));
    await tester.pump();
    await _scrollTo(tester, 'Account');
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: AdvancedConfigView()),
      ),
    );
    expect(find.text('Network'), findsOneWidget);
    expect(find.text('DNS'), findsOneWidget);
    expect(find.text('Added rules'), findsOneWidget);
    expect(find.text('Script'), findsOneWidget);
    expect(find.text('On demand'), findsNothing);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ThemeView()),
      ),
    );
    await _scrollTo(tester, 'Tab animation');
    expect(find.text('Tab animation'), findsOneWidget);
    expect(find.byIcon(Icons.animation), findsOneWidget);
    await _scrollTo(tester, 'Swipe to switch pages');
    expect(find.text('Swipe to switch pages'), findsOneWidget);
    expect(find.byIcon(Icons.swipe), findsOneWidget);
    if (!system.isTV) {
      await _scrollTo(tester, 'TV mode');
      expect(find.text('TV mode'), findsOneWidget);
      expect(find.byIcon(Icons.tv), findsOneWidget);
    }

    globalState.packageInfo = PackageInfo(
      appName: 'FlClash',
      packageName: 'com.follow.clash',
      version: '0.0.0',
      buildNumber: '1',
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: AboutView()),
      ),
    );
    expect(find.text('Auto check for updates'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
    expect(
      find.text('Check for updates automatically when the app starts'),
      findsNothing,
    );
  });
}

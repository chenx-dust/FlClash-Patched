import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/access.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('primary switch is visible and mode remains in settings', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        packagesProvider.overrideWithBuild(
          (_, _) => const [
            Package(
              packageName: 'example.app',
              label: 'Example',
              system: false,
              internet: true,
              lastUpdateTime: 1,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: AccessView()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 301));

    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.text('Whitelist mode'), findsNothing);
    expect(find.text('Blacklist mode'), findsNothing);
    expect(find.text('Configure application access proxy'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Whitelist mode'), findsOneWidget);
    expect(find.text('Blacklist mode'), findsOneWidget);
    await tester.tap(find.text('Whitelist mode'));
    await tester.pump();
    expect(
      container.read(accessControlStateProvider).mode,
      AccessControlMode.acceptSelected,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    final saved = container.read(vpnSettingProvider).accessControlProps;
    expect(saved.enable, true);
    expect(saved.mode, AccessControlMode.acceptSelected);
  });

  testWidgets('saving preserves selected apps hidden by display filters', (
    tester,
  ) async {
    const accessControl = AccessControlProps(
      enable: true,
      rejectList: ['system.app'],
    );
    final container = ProviderContainer(
      overrides: [
        vpnSettingProvider.overrideWithBuild(
          (_, _) => const VpnProps(accessControlProps: accessControl),
        ),
        packagesProvider.overrideWithBuild(
          (_, _) => const [
            Package(
              packageName: 'user.app',
              label: 'User app',
              system: false,
              internet: true,
              lastUpdateTime: 1,
            ),
            Package(
              packageName: 'system.app',
              label: 'System app',
              system: true,
              internet: true,
              lastUpdateTime: 1,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: AccessView()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 301));

    expect(find.text('system.app'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(container.read(vpnSettingProvider).accessControlProps.rejectList, [
      'system.app',
    ]);
  });
}

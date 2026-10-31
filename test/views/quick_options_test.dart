import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/dashboard/widgets/quick_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Center(child: SizedBox(width: 200, child: child)),
        ),
      ),
    );
  }

  group('Ipv6Button', () {
    testWidgets('tapping the card toggles without opening a sheet', (
      tester,
    ) async {
      await pump(tester, const Ipv6Button());
      final initial = container.read(patchClashConfigProvider).ipv6;

      await tester.tap(find.text('IPv6'));
      await tester.pumpAndSettle();

      expect(container.read(patchClashConfigProvider).ipv6, !initial);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('labels the card Toggle instead of Options', (tester) async {
      await pump(tester, const Ipv6Button());

      expect(find.text('Toggle'), findsOneWidget);
      expect(find.text('Options'), findsNothing);
    });

    testWidgets('the switch toggles the setting', (tester) async {
      await pump(tester, const Ipv6Button());
      final initial = container.read(patchClashConfigProvider).ipv6;

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(patchClashConfigProvider).ipv6, !initial);
    });
  });

  group('ExternalControllerButton', () {
    testWidgets('switching on binds loopback, switching off clears it', (
      tester,
    ) async {
      await pump(tester, const ExternalControllerButton());
      expect(container.read(patchClashConfigProvider).externalController, '');

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        container.read(patchClashConfigProvider).externalController,
        '127.0.0.1:9090',
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(container.read(patchClashConfigProvider).externalController, '');
    });

    testWidgets('tapping the card opens the options sheet', (tester) async {
      await pump(tester, const ExternalControllerButton());

      await tester.tap(find.text('External controller'));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(container.read(patchClashConfigProvider).externalController, '');
    });
  });
}

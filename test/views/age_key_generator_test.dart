import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/profiles/age_key_generator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('private key action pastes when generating from a private key', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': '  AGE-SECRET-KEY-1EXAMPLE  '};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      TestApp(
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => const Size(800, 600)),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => const AgeKeyGeneratorDialog(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = currentAppLocalizations;
    expect(find.byTooltip(l10n.copy), findsNWidgets(2));
    expect(find.byTooltip(l10n.paste), findsNothing);

    await tester.tap(find.text(l10n.generateFromPrivateKey));
    await tester.pumpAndSettle();

    expect(find.byTooltip(l10n.paste), findsOneWidget);
    expect(find.byTooltip(l10n.copy), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.paste));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'AGE-SECRET-KEY-1EXAMPLE',
    );
    expect(tester.takeException(), null);
  });
}

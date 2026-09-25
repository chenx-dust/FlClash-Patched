import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/manager/back_manager.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  bool isTV = true,
  bool slider = false,
  bool sideSheet = false,
  WidgetBuilder? builder,
}) async {
  system.isTV = isTV;
  addTearDown(() {
    system.isTV = false;
  });
  await tester.pumpWidget(
    BackManager(
      child: TestApp(
        overrides: [
          viewSizeProvider.overrideWithBuild(
            (_, _) => sideSheet ? const Size(900, 700) : const Size(400, 700),
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSheet<void>(
              context: context,
              props: const SheetProps(isScrollControlled: true, blur: false),
              builder:
                  builder ??
                  (_) => slider
                      ? Slider(autofocus: true, value: 0.5, onChanged: (_) {})
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(autofocus: true),
                            SizedBox(height: 16),
                            TextField(),
                          ],
                        ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final sideSheet in <bool>[false, true]) {
    final placement = sideSheet ? 'side sheet' : 'bottom sheet';
    for (final key in <LogicalKeyboardKey?>[
      null,
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.gameButtonB,
    ]) {
      testWidgets('TV back $key releases input before closing the $placement', (
        tester,
      ) async {
        await _openSheet(tester, sideSheet: sideSheet);
        await tester.enterText(find.byType(TextField).first, 'keep this');
        await tester.pumpAndSettle();
        final input = tester.widget<EditableText>(
          find.byType(EditableText).first,
        );
        final scope = input.focusNode.enclosingScope!;

        Future<void> back() async {
          if (key == null) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.sendKeyEvent(key);
          }
          await tester.pumpAndSettle();
        }

        await back();
        expect(find.byType(TextField), findsWidgets);
        expect(input.focusNode.hasFocus, isFalse);
        expect(scope.hasPrimaryFocus, isTrue);
        expect(scope.focusedChild, same(input.focusNode));
        expect(input.controller.text, 'keep this');
        expect(tester.testTextInput.hasAnyClients, isFalse);

        await back();
        expect(find.byType(TextField), findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  }

  testWidgets('TV arrows resume traversal after leaving sheet input', (
    tester,
  ) async {
    await _openSheet(tester);
    final inputs = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(inputs.last.focusNode.hasPrimaryFocus, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(inputs.last.focusNode.hasFocus, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'TV back closes a sheet on the frame after focus leaves the input',
    (tester) async {
      await _openSheet(
        tester,
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(autofocus: true),
            TextButton(onPressed: () {}, child: const Text('Next')),
          ],
        ),
      );
      Focus.of(tester.element(find.text('Next'))).requestFocus();
      await tester.pump();
      expect(
        Focus.of(tester.element(find.text('Next'))).hasPrimaryFocus,
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('TV back releases a sheet slider before closing', (tester) async {
    await _openSheet(tester, slider: true);
    final sliderFocus = FocusManager.instance.primaryFocus!;
    final scope = sliderFocus.enclosingScope!;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(sliderFocus.hasFocus, isFalse);
    expect(scope.hasPrimaryFocus, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('TV close button dismisses a sheet while input is focused', (
    tester,
  ) async {
    await _openSheet(
      tester,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TextField(autofocus: true),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('sheet back still reaches an inner pop handler', (tester) async {
    var handled = 0;
    await _openSheet(
      tester,
      builder: (_) => CommonPopScope(
        onPop: (_) {
          handled++;
          return false;
        },
        child: const TextField(autofocus: true),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, 0);
    expect(find.byType(TextField), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, 1);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('non-TV back closes a sheet immediately', (tester) async {
    await _openSheet(tester, isTV: false);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });
}

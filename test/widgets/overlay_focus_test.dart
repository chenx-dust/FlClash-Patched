import 'package:fl_clash/widgets/focus.dart';
import 'package:fl_clash/widgets/popup.dart';
import 'package:fl_clash/widgets/side_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<FocusNode> pumpPageNavigator(
    WidgetTester tester, {
    required Widget page,
  }) async {
    final outsideFocus = FocusNode();
    addTearDown(outsideFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Focus(
              focusNode: outsideFocus,
              child: const SizedBox(width: 48, height: 48),
            ),
            Expanded(
              child: FocusTraversalGroup(
                policy: PageTraversalPolicy(),
                child: Navigator(
                  pages: [MaterialPage(child: PageFocusScope(child: page))],
                  onDidRemovePage: (_) {},
                  routeDirectionalTraversalEdgeBehavior:
                      TraversalEdgeBehavior.parentScope,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    return outsideFocus;
  }

  Future<void> focusLabel(WidgetTester tester, String label) async {
    Focus.of(tester.element(find.text(label))).requestFocus();
    await tester.pump();
  }

  bool labelHasFocus(WidgetTester tester, String label) {
    return Focus.of(tester.element(find.text(label))).hasPrimaryFocus;
  }

  testWidgets('arrow keys stay inside a popup menu', (tester) async {
    final outsideFocus = await pumpPageNavigator(
      tester,
      page: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  CommonPopupRoute<void>(
                    barrierLabel: 'dismiss',
                    anchorOf: () => const Rect.fromLTWH(80, 80, 40, 40),
                    builder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _noop,
                          child: const Text('Menu A'),
                        ),
                        TextButton(
                          onPressed: _noop,
                          child: const Text('Menu B'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Open menu'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    await focusLabel(tester, 'Menu A');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(labelHasFocus(tester, 'Menu B'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(labelHasFocus(tester, 'Menu B'), isTrue);
    expect(find.text('Menu B'), findsOneWidget);
    expect(outsideFocus.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(labelHasFocus(tester, 'Menu B'), isTrue);
    expect(outsideFocus.hasFocus, isFalse);
  });

  testWidgets('tab stays inside a popup menu', (tester) async {
    await pumpPageNavigator(
      tester,
      page: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  CommonPopupRoute<void>(
                    barrierLabel: 'dismiss',
                    anchorOf: () => const Rect.fromLTWH(80, 80, 40, 40),
                    builder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _noop,
                          child: const Text('Menu A'),
                        ),
                        TextButton(
                          onPressed: _noop,
                          child: const Text('Menu B'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Open menu'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    await focusLabel(tester, 'Menu B');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(labelHasFocus(tester, 'Menu B'), isTrue);
    expect(find.text('Open menu'), findsOneWidget);
  });

  testWidgets('arrow keys stay inside a side sheet', (tester) async {
    final outsideFocus = await pumpPageNavigator(
      tester,
      page: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showModalSideSheet<void>(
                  context: context,
                  builder: (_) => Column(
                    children: [
                      TextButton(
                        onPressed: _noop,
                        child: const Text('Sheet A'),
                      ),
                      TextButton(
                        onPressed: _noop,
                        child: const Text('Sheet B'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open sheet'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await focusLabel(tester, 'Sheet B');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(labelHasFocus(tester, 'Sheet B'), isTrue);
    expect(find.text('Sheet B'), findsOneWidget);
    expect(outsideFocus.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(outsideFocus.hasFocus, isFalse);
    expect(find.text('Sheet A'), findsOneWidget);
  });
}

void _noop() {}

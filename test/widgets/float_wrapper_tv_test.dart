import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/button.dart';
import 'package:fl_clash/widgets/float_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  tearDown(() {
    system.isTV = false;
  });

  testWidgets('FloatWrapper outlines its child when the device is a TV', (
    tester,
  ) async {
    system.isTV = true;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _pump(tester, container);

    expect(find.byType(FabFocusOutline), findsOneWidget);
    expect(_ring(), findsNothing);

    await _focusAction(tester);

    expect(_ring(), findsOneWidget);
  });

  testWidgets('FloatWrapper outlines its child when TV mode is enabled', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _pump(tester, container);
    expect(find.byType(FabFocusOutline), findsNothing);
    expect(system.isTV, isFalse);

    container.read(appSettingProvider.notifier).value = const AppSettingProps(
      tvMode: true,
    );
    await tester.pump();

    expect(system.isTV, isFalse);
    expect(find.byType(FabFocusOutline), findsOneWidget);

    await _focusAction(tester);

    expect(_ring(), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, ProviderContainer container) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: FloatWrapper(
            child: TextButton(onPressed: _noop, child: const Text('action')),
          ),
        ),
      ),
    ),
  );
}

Finder _ring() {
  return find.descendant(
    of: find.byType(FabFocusOutline),
    matching: find.byType(IgnorePointer),
  );
}

Future<void> _focusAction(WidgetTester tester) async {
  Focus.of(tester.element(find.text('action'))).requestFocus();
  await tester.pump();
  await tester.pump();
}

void _noop() {}

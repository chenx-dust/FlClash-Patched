import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/hotkey.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

ProviderContainer _containerFor(
  WidgetTester tester, {
  List<HotKeyAction> hotKeyActions = const [],
}) {
  const size = Size(1400, 1000);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).update((_) => size);
  // hotKeyActionsProvider is autoDispose: without a live listener the seeded
  // value is discarded before the assertions read it back.
  final subscription = container.listen(
    hotKeyActionsProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  container.read(hotKeyActionsProvider.notifier).value = hotKeyActions;
  return container;
}

Future<void> _pumpRecorder(
  WidgetTester tester,
  ProviderContainer container,
  HotKeyAction action,
) async {
  // Pushed as a route so the recorder's Navigator.pop has something to pop,
  // matching how the view opens it as a dialog.
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: HotKeyRecorder(
                    hotKeyAction: action,
                    labels: ShortcutLabels.host(),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _pressWithControl(
  WidgetTester tester,
  PhysicalKeyboardKey key,
  LogicalKeyboardKey logicalKey,
) async {
  await simulateKeyDownEvent(
    LogicalKeyboardKey.controlLeft,
    physicalKey: PhysicalKeyboardKey.controlLeft,
  );
  await simulateKeyDownEvent(logicalKey, physicalKey: key);
  await tester.pumpAndSettle();
  await simulateKeyUpEvent(logicalKey, physicalKey: key);
  await simulateKeyUpEvent(
    LogicalKeyboardKey.controlLeft,
    physicalKey: PhysicalKeyboardKey.controlLeft,
  );
}

void main() {
  group('HotKeyView', () {
    testWidgets('shows unset actions in sections', (tester) async {
      final container = _containerFor(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: HotKeyView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rule mode'), findsOneWidget);
      expect(find.text('Not set'), findsWidgets);
      expect(tester.takeException(), null);
    });

    testWidgets('shows the bound key caps', (tester) async {
      final container = _containerFor(
        tester,
        hotKeyActions: [
          HotKeyAction(
            action: HotAction.mode,
            key: PhysicalKeyboardKey.keyA.usbHidUsage,
            modifiers: const {KeyboardModifier.control},
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: HotKeyView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ctrl'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(tester.takeException(), null);
    });
  });

  group('HotKeyRecorder', () {
    testWidgets('prompts for input until a key is captured', (tester) async {
      final container = _containerFor(tester);
      await _pumpRecorder(
        tester,
        container,
        const HotKeyAction(action: HotAction.mode),
      );

      expect(find.text(currentAppLocalizations.pressKeyboard), findsOne);

      await _pressWithControl(
        tester,
        PhysicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyA,
      );

      expect(find.text(currentAppLocalizations.pressKeyboard), findsNothing);
      expect(find.text('Ctrl'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(tester.takeException(), null);
    });

    testWidgets('save stores a modifier plus key combination', (tester) async {
      final container = _containerFor(tester);
      await _pumpRecorder(
        tester,
        container,
        const HotKeyAction(action: HotAction.mode),
      );

      await _pressWithControl(
        tester,
        PhysicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyA,
      );
      await tester.tap(find.text(currentAppLocalizations.save));
      await tester.pumpAndSettle();

      final stored = container.read(hotKeyActionsProvider);
      expect(stored, hasLength(1));
      expect(stored.single.action, HotAction.mode);
      expect(stored.single.key, PhysicalKeyboardKey.keyA.usbHidUsage);
      expect(stored.single.modifiers, {KeyboardModifier.control});
    });

    testWidgets('save stays disabled for a bare key', (tester) async {
      final container = _containerFor(tester);
      await _pumpRecorder(
        tester,
        container,
        const HotKeyAction(action: HotAction.mode),
      );

      await simulateKeyDownEvent(
        LogicalKeyboardKey.keyA,
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.pumpAndSettle();
      await simulateKeyUpEvent(
        LogicalKeyboardKey.keyA,
        physicalKey: PhysicalKeyboardKey.keyA,
      );

      final save = tester.widget<TextButton>(
        find.widgetWithText(TextButton, currentAppLocalizations.save),
      );
      expect(save.onPressed, isNull);
      expect(find.textContaining('Ctrl'), findsWidgets);
      expect(container.read(hotKeyActionsProvider), isEmpty);
    });

    testWidgets('save moves a combination already bound elsewhere', (
      tester,
    ) async {
      final taken = HotKeyAction(
        action: HotAction.start,
        key: PhysicalKeyboardKey.keyA.usbHidUsage,
        modifiers: const {KeyboardModifier.control},
      );
      final container = _containerFor(tester, hotKeyActions: [taken]);
      await _pumpRecorder(
        tester,
        container,
        const HotKeyAction(action: HotAction.mode),
      );

      await _pressWithControl(
        tester,
        PhysicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyA,
      );
      expect(find.textContaining('Start/Stop'), findsOneWidget);
      await tester.tap(find.text(currentAppLocalizations.save));
      await tester.pumpAndSettle();

      final stored = container.read(hotKeyActionsProvider);
      expect(stored, hasLength(1));
      expect(stored.single.action, HotAction.mode);
      expect(stored.single.key, PhysicalKeyboardKey.keyA.usbHidUsage);
    });

    testWidgets('save replaces the binding for the same action', (
      tester,
    ) async {
      final existing = HotKeyAction(
        action: HotAction.mode,
        key: PhysicalKeyboardKey.keyB.usbHidUsage,
        modifiers: const {KeyboardModifier.control},
      );
      final container = _containerFor(tester, hotKeyActions: [existing]);
      await _pumpRecorder(tester, container, existing);

      await _pressWithControl(
        tester,
        PhysicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyA,
      );
      await tester.tap(find.text(currentAppLocalizations.save));
      await tester.pumpAndSettle();

      final stored = container.read(hotKeyActionsProvider);
      expect(stored, hasLength(1), reason: 'replaces rather than appends');
      expect(stored.single.key, PhysicalKeyboardKey.keyA.usbHidUsage);
    });

    testWidgets('remove clears the key and modifiers for the action', (
      tester,
    ) async {
      final existing = HotKeyAction(
        action: HotAction.mode,
        key: PhysicalKeyboardKey.keyB.usbHidUsage,
        modifiers: const {KeyboardModifier.control},
      );
      final container = _containerFor(tester, hotKeyActions: [existing]);
      await _pumpRecorder(tester, container, existing);

      await tester.tap(find.text(currentAppLocalizations.remove));
      await tester.pumpAndSettle();

      expect(container.read(hotKeyActionsProvider), isEmpty);
    });
  });
}

import 'package:fl_clash/manager/back_manager.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('escape follows the framework pop route', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => BackManager(child: child!),
        home: CommonPopScope(
          onPop: (_) {
            backCount++;
            return false;
          },
          child: const Focus(autofocus: true, child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 1));

    expect(backCount, 1);
  });

  testWidgets('gamepad B follows the framework pop route', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => BackManager(child: child!),
        home: CommonPopScope(
          onPop: (_) {
            backCount++;
            return false;
          },
          child: const Focus(autofocus: true, child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pump(const Duration(milliseconds: 1));

    expect(backCount, 1);
  });

  testWidgets('mouse back button follows the framework pop route', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => BackManager(child: child!),
        home: CommonPopScope(
          onPop: (_) {
            backCount++;
            return false;
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.sendEventToBinding(
      const PointerDownEvent(
        position: Offset(100, 100),
        kind: PointerDeviceKind.mouse,
        buttons: kBackMouseButton,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(backCount, 1);
  });
}

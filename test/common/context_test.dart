import 'package:fl_clash/common/context.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('showSnackBar replaces the current fixed snack bar', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    context.showSnackBar('first');
    await tester.pump();
    context.showSnackBar('second', persist: true);
    await tester.pump();

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.fixed);
    expect(snackBar.persist, isTrue);
  });

  testWidgets('showSnackBar keeps the deadline while the pointer is over it', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));

    context.showSnackBar(
      'hold',
      persist: false,
      action: SnackBarAction(label: 'Close', onPressed: () {}),
    );
    await _showSnackBar(tester);
    expect(find.text('Close'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));

    final gesture = await _hoverSnackBar(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('hold'), findsOneWidget);

    await gesture.moveTo(const Offset(400, 10));
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpAndSettle();
    expect(find.text('hold'), findsNothing);
  });

  testWidgets('showSnackBar finishes closing when the pointer returns', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));

    context.showSnackBar('hold');
    await _showSnackBar(tester);
    final gesture = await _hoverSnackBar(tester);
    await tester.pump(const Duration(seconds: 2));

    await gesture.moveTo(const Offset(400, 10));
    await gesture.moveTo(tester.getCenter(find.byType(SnackBar)));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpAndSettle();
    expect(find.text('hold'), findsNothing);
  });

  testWidgets('showSnackBar dismisses after the duration', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));

    context.showSnackBar('gone');
    await _showSnackBar(tester);
    await tester.pump(const Duration(seconds: 3));

    await tester.pumpAndSettle();
    expect(find.text('gone'), findsNothing);
  });

  testWidgets('showSnackBar keeps its duration with animations disabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));
    context.showSnackBar('readable');
    await _showSnackBar(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('readable'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('readable'), findsNothing);
  });

  testWidgets('showSnackBar with an action persists by default', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));
    var pressed = false;
    context.showSnackBar(
      'action',
      action: SnackBarAction(label: 'Close', onPressed: () => pressed = true),
    );
    await _showSnackBar(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('action'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
    expect(find.text('action'), findsNothing);
  });

  testWidgets(
    'showSnackBar holds over the native action and keeps its layout',
    (tester) async {
      tester.view.physicalSize = const Size(480, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext context;
      await tester.pumpWidget(_snackBarApp((value) => context = value));
      const label = 'Close all connections';
      var pressed = false;
      context.showSnackBar(
        'hold',
        persist: false,
        action: SnackBarAction(label: label, onPressed: () => pressed = true),
      );
      await _showSnackBar(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text(label)).dy,
        greaterThan(tester.getBottomLeft(find.text('hold')).dy),
      );
      final gesture = await _hoverSnackBar(tester);
      await gesture.moveTo(tester.getCenter(find.text(label)));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('hold'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
      expect(find.text('hold'), findsNothing);
    },
  );

  testWidgets('replacing a timed snack bar cancels its deadline', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));
    context.showSnackBar('old');
    await _showSnackBar(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    context.showSnackBar('persistent', persist: true);
    await _showSnackBar(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('old'), findsNothing);
    expect(find.text('persistent'), findsOneWidget);
  });

  testWidgets('disposing a timed snack bar cancels its deadline', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));
    context.showSnackBar('gone');
    await _showSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}

Widget _snackBarApp(ValueChanged<BuildContext> onContext) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (value) {
          onContext(value);
          return const SizedBox();
        },
      ),
    ),
  );
}

Future<TestGesture> _hoverSnackBar(WidgetTester tester) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: 0,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(find.byType(SnackBar)));
  return gesture;
}

Future<void> _showSnackBar(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

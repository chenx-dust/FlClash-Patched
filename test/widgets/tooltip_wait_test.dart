import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('hover waits, and the next tooltip waits again after a gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          tooltipTheme: const TooltipThemeData(
            waitDuration: Duration(milliseconds: 500),
          ),
        ),
        home: const Scaffold(
          body: Row(
            children: [
              IconButton(
                onPressed: _noop,
                tooltip: 'Alpha',
                icon: Icon(Icons.add),
              ),
              IconButton(
                onPressed: _noop,
                tooltip: 'Beta',
                icon: Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(tester.getCenter(find.byIcon(Icons.add)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Alpha'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Alpha'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.byIcon(Icons.remove)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Beta'), findsOneWidget);

    await gesture.moveTo(const Offset(300, 300));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Beta'), findsNothing);

    await gesture.moveTo(tester.getCenter(find.byIcon(Icons.add)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Alpha'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Alpha'), findsOneWidget);
  });
}

void _noop() {}

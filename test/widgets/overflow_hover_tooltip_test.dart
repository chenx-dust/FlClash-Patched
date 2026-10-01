import 'package:fl_clash/widgets/text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const longName = 'Hong Kong 01 | United States Premium Node';
  const style = TextStyle(fontSize: 14);

  testWidgets('shows the full name after hovering an overflowing node', (
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
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 48,
              height: 48,
              child: OverflowHoverTooltip(
                message: longName,
                maxWidth: 48,
                style: style,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Tooltip), findsOneWidget);
    expect(find.text(longName), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(tester.getCenter(find.byType(OverflowHoverTooltip)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(longName), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(longName), findsOneWidget);

    await gesture.moveTo(const Offset(400, 400));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(longName), findsNothing);
  });

  testWidgets('skips the tooltip when the name already fits', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OverflowHoverTooltip(
            message: 'HK',
            maxWidth: 400,
            style: style,
            child: SizedBox(width: 80, height: 24),
          ),
        ),
      ),
    );

    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('uses the card line count when deciding overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OverflowHoverTooltip(
            message: 'A\nB',
            maxWidth: 400,
            maxLines: 2,
            style: style,
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );

    expect(find.byType(Tooltip), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OverflowHoverTooltip(
            message: 'A\nB',
            maxWidth: 400,
            style: style,
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );

    expect(find.byType(Tooltip), findsOneWidget);
  });
}

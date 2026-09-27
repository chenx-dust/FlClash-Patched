import 'package:fl_clash/widgets/scroll.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('a vertical mouse wheel scrolls the horizontal row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 120,
            child: HorizontalWheelScroll(
              child: SizedBox(width: 400, height: 32),
            ),
          ),
        ),
      ),
    );

    final target = tester.getCenter(find.byType(HorizontalWheelScroll));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: target);
    await tester.pump();
    await tester.sendEventToBinding(
      PointerScrollEvent(position: target, scrollDelta: const Offset(0, 50)),
    );
    await tester.pump();

    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      50,
    );
  });
}

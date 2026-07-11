import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('monochrome tray SVG renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 64,
            child: SvgPicture.asset('assets/images/icon/flclash-symbolic.svg'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

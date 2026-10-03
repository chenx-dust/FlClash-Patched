import 'dart:math';

import 'package:fl_clash/widgets/donut_chart.dart';
import 'package:fl_clash/views/dashboard/widgets/traffic_usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

class _Canvas extends Mock implements Canvas {}

void main() {
  setUpAll(() {
    registerFallbackValue(Rect.zero);
    registerFallbackValue(Offset.zero);
    registerFallbackValue(Paint());
  });

  testWidgets('TrafficUsage keeps both arcs when traffic is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        wrapInProviderScope: true,
        homeBuilder: _scaffoldBody,
        child: TrafficUsage(),
      ),
    );
    await tester.pump();
    final chart = tester.widget<DonutChart>(find.byType(DonutChart));
    expect(chart.data.map((item) => item.value), [1, 1]);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<DonutChartPainter>()
        .single;
    final canvas = _Canvas();
    final sweeps = <double>[];
    when(() => canvas.drawArc(any(), any(), any(), any(), any())).thenAnswer((
      call,
    ) {
      sweeps.add(call.positionalArguments[2] as double);
      expect((call.positionalArguments[4] as Paint).strokeCap, StrokeCap.round);
    });
    painter.paint(canvas, const Size.square(180));
    expect(sweeps, hasLength(2));
    expect(sweeps.first, greaterThan(0));
    expect(sweeps.first, sweeps.last);
    expect(tester.takeException(), isNull);
  });

  testWidgets('traffic interpolation retains the original one-sided ring', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: SizedBox()));
    const oldData = [
      DonutChartData(value: 0, color: Colors.blue),
      DonutChartData(value: 0, color: Colors.grey),
    ];
    const newData = [
      DonutChartData(value: 0, color: Colors.blue),
      DonutChartData(value: 4096, color: Colors.grey),
    ];
    final canvas = _Canvas();
    final sweeps = <double>[];
    when(() => canvas.drawArc(any(), any(), any(), any(), any())).thenAnswer((
      call,
    ) {
      sweeps.add(call.positionalArguments[2] as double);
    });
    DonutChartPainter(
      oldData,
      newData,
      0.5,
    ).paint(canvas, const Size.square(180));
    expect(sweeps, hasLength(2));
    expect(sweeps.first, greaterThan(0));
    expect(sweeps.last / sweeps.first, closeTo((sqrt(4097) + 1) / 2, 0.000001));
  });

  testWidgets('released memory draws round dots across its Sys share', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: SizedBox()));
    const data = [
      DonutChartData.exact(value: 2048, color: Colors.blue),
      DonutChartData.exact(value: 2048, color: Colors.grey, dashed: true),
      DonutChartData.exact(value: 0, color: Colors.red),
    ];
    final canvas = _Canvas();
    final sweeps = <double>[];
    final dots = <Offset>[];
    double? strokeWidth;
    when(() => canvas.drawArc(any(), any(), any(), any(), any())).thenAnswer((
      call,
    ) {
      sweeps.add(call.positionalArguments[2] as double);
      final paint = call.positionalArguments[4] as Paint;
      strokeWidth = paint.strokeWidth;
      expect(paint.strokeCap, StrokeCap.round);
      expect(paint.style, PaintingStyle.stroke);
    });
    when(() => canvas.drawCircle(any(), any(), any())).thenAnswer((call) {
      dots.add(call.positionalArguments[0] as Offset);
      expect(call.positionalArguments[1], strokeWidth! * 0.4);
      expect((call.positionalArguments[2] as Paint).style, PaintingStyle.fill);
    });
    DonutChartPainter(data, data, 1).paint(canvas, const Size.square(180));

    expect(sweeps, hasLength(1));
    expect(dots.length, greaterThan(1));
    final angles = dots.map((dot) {
      final offset = dot - const Offset(90, 90);
      expect(offset.distance, closeTo(85, 0.000001));
      final angle = atan2(offset.dy, offset.dx);
      return angle < 0 ? angle + 2 * pi : angle;
    }).toList();
    final step = angles[1] - angles[0];
    expect(step * 85, greaterThan(strokeWidth!));
    for (var i = 1; i < angles.length; i++) {
      expect(angles[i] - angles[i - 1], closeTo(step, 0.000001));
    }
    expect(step * dots.length, closeTo(sweeps.single, 0.000001));
  });

  testWidgets('released dots animate to zero before disappearing', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: SizedBox()));
    const oldData = [
      DonutChartData.exact(value: 2048, color: Colors.blue),
      DonutChartData.exact(value: 2048, color: Colors.grey, dashed: true),
    ];
    const newData = [
      DonutChartData.exact(value: 2048, color: Colors.blue),
      DonutChartData.exact(value: 0, color: Colors.grey, dashed: true),
    ];
    final canvas = _Canvas();
    DonutChartPainter(
      oldData,
      newData,
      0.5,
    ).paint(canvas, const Size.square(180));
    verify(() => canvas.drawCircle(any(), any(), any())).called(greaterThan(0));
    DonutChartPainter(
      oldData,
      newData,
      1,
    ).paint(canvas, const Size.square(180));
    verifyNever(() => canvas.drawCircle(any(), any(), any()));
  });

  testWidgets('memory geometry closes continuously regardless of byte units', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: SizedBox()));
    List<double> frame(double progress, double scale) {
      final canvas = _Canvas();
      final geometry = <double>[];
      when(() => canvas.drawArc(any(), any(), any(), any(), any())).thenAnswer((
        call,
      ) {
        geometry.add(call.positionalArguments[1] as double);
        geometry.add(call.positionalArguments[2] as double);
      });
      when(() => canvas.drawCircle(any(), any(), any())).thenAnswer((call) {
        final center = call.positionalArguments[0] as Offset;
        geometry.addAll([
          center.dx,
          center.dy,
          call.positionalArguments[1] as double,
        ]);
      });
      DonutChartPainter(
        [
          DonutChartData.exact(value: 2048 * scale, color: Colors.blue),
          DonutChartData.exact(
            value: 2048 * scale,
            color: Colors.grey,
            dashed: true,
          ),
        ],
        [
          DonutChartData.exact(value: 2048 * scale, color: Colors.blue),
          const DonutChartData.exact(
            value: 0,
            color: Colors.grey,
            dashed: true,
          ),
        ],
        progress,
      ).paint(canvas, const Size.square(180));
      return geometry;
    }

    for (final progress in [0.0, 0.5, 0.9, 0.99, 1.0]) {
      expect(frame(progress, 1), orderedEquals(frame(progress, 1000000)));
    }
    final late = frame(0.99, 1);
    final end = frame(1, 1);
    expect(late, hasLength(5));
    expect(end, hasLength(2));
    expect(late.last, lessThan(0.01));
    expect(late[1], closeTo(end[1], 0.001));
    expect(
      frame(0.5, 1)[1],
      closeTo(
        frame(0, 1)[1] +
            (end[1] - frame(0, 1)[1]) * Curves.easeInOutCubic.transform(0.5),
        0.000001,
      ),
    );
  });

  testWidgets(
    'reversing memory visibility continues from the current geometry',
    (tester) async {
      const visible = [
        DonutChartData.exact(value: 2048, color: Colors.blue),
        DonutChartData.exact(value: 2048, color: Colors.grey, dashed: true),
      ];
      const hidden = [
        DonutChartData.exact(value: 2048, color: Colors.blue),
        DonutChartData.exact(value: 0, color: Colors.grey, dashed: true),
      ];
      Future<void> show(List<DonutChartData> data) => tester.pumpWidget(
        TestApp(
          child: DonutChart(data: data, duration: const Duration(seconds: 1)),
        ),
      );
      double sweep() {
        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((widget) => widget.painter)
            .whereType<DonutChartPainter>()
            .single;
        final canvas = _Canvas();
        var result = 0.0;
        when(
          () => canvas.drawArc(any(), any(), any(), any(), any()),
        ).thenAnswer((call) {
          result = call.positionalArguments[2] as double;
        });
        painter.paint(canvas, const Size.square(180));
        return result;
      }

      await show(visible);
      final initial = sweep();
      await show(hidden);
      await tester.pump(const Duration(milliseconds: 400));
      final interrupted = sweep();
      expect(interrupted, greaterThan(initial));
      await show(visible);
      expect(sweep(), closeTo(interrupted, 0.000001));
      await tester.pumpAndSettle();
      expect(sweep(), closeTo(initial, 0.000001));
    },
  );

  testWidgets('zero memory does not create artificial slices', (tester) async {
    await tester.pumpWidget(const TestApp(child: SizedBox()));
    const data = [
      DonutChartData.exact(value: 0, color: Colors.grey, dashed: true),
    ];
    final canvas = _Canvas();
    DonutChartPainter(data, data, 1).paint(canvas, const Size.square(180));
    verifyNever(() => canvas.drawArc(any(), any(), any(), any(), any()));
    verifyNever(() => canvas.drawCircle(any(), any(), any()));
  });
}

Widget _scaffoldBody(Widget child) => Scaffold(body: child);

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

  testWidgets('solid slices shrink in thickness before disappearing', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: SizedBox()));
    const before = [
      DonutChartData.exact(value: 2048, color: Colors.blue),
      DonutChartData.exact(value: 2048, color: Colors.grey),
    ];
    const after = [
      DonutChartData.exact(value: 0, color: Colors.blue),
      DonutChartData.exact(value: 2048, color: Colors.grey),
    ];
    List<double> widths(double progress) {
      final canvas = _Canvas();
      final result = <double>[];
      when(() => canvas.drawArc(any(), any(), any(), any(), any())).thenAnswer((
        call,
      ) {
        result.add((call.positionalArguments[4] as Paint).strokeWidth);
      });
      when(() => canvas.drawCircle(any(), any(), any())).thenAnswer(
        (call) => result.add((call.positionalArguments[1] as double) * 2),
      );
      DonutChartPainter(
        before,
        after,
        progress,
      ).paint(canvas, const Size.square(180));
      return result;
    }

    final initial = widths(0);
    final late = widths(0.99);
    final later = widths(0.999);
    expect(initial.first, initial.last);
    expect(late.first, greaterThan(0));
    expect(late.first, lessThan(initial.first));
    expect(later.first, lessThan(late.first));
    expect(late.last, initial.last);
    expect(later.last, initial.last);
    expect(widths(1), [initial.last]);
  });

  testWidgets('visibility transitions scale a dot before extending the arc', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: SizedBox()));
    const visible = [
      DonutChartData.exact(value: 2048, color: Colors.blue),
      DonutChartData.exact(value: 2048, color: Colors.grey),
    ];
    const hidden = [
      DonutChartData.exact(value: 0, color: Colors.blue),
      DonutChartData.exact(value: 2048, color: Colors.grey),
    ];
    for (final appearing in [false, true]) {
      for (final progress in [0.2, 0.8]) {
        final canvas = _Canvas();
        final widths = <double>[];
        final dots = <double>[];
        when(
          () => canvas.drawArc(any(), any(), any(), any(), any()),
        ).thenAnswer(
          (call) =>
              widths.add((call.positionalArguments[4] as Paint).strokeWidth),
        );
        when(
          () => canvas.drawCircle(any(), any(), any()),
        ).thenAnswer((call) => dots.add(call.positionalArguments[1] as double));
        DonutChartPainter(
          appearing ? hidden : visible,
          appearing ? visible : hidden,
          progress,
        ).paint(canvas, const Size.square(180));
        final dotPhase = appearing ? progress < 0.5 : progress > 0.5;
        if (dotPhase) {
          expect(widths, hasLength(1));
          expect(dots, hasLength(1));
          expect(dots.single, greaterThan(0));
          expect(dots.single * 2, lessThan(widths.single));
        } else {
          expect(dots, isEmpty);
          expect(widths, hasLength(2));
          expect(widths.first, widths.last);
        }
      }
    }
  });

  testWidgets('small slices keep their size while their share changes', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: SizedBox()));
    for (final dashed in [false, true]) {
      final before = [
        DonutChartData.exact(value: 1, color: Colors.blue, dashed: dashed),
        const DonutChartData.exact(value: 1000000, color: Colors.grey),
      ];
      final after = [
        DonutChartData.exact(value: 2, color: Colors.blue, dashed: dashed),
        const DonutChartData.exact(value: 1000000, color: Colors.grey),
      ];
      for (final progress in [0.0, 0.5, 0.99, 1.0]) {
        final canvas = _Canvas();
        final widths = <double>[];
        final radii = <double>[];
        when(
          () => canvas.drawArc(any(), any(), any(), any(), any()),
        ).thenAnswer(
          (call) =>
              widths.add((call.positionalArguments[4] as Paint).strokeWidth),
        );
        when(() => canvas.drawCircle(any(), any(), any())).thenAnswer(
          (call) => radii.add(call.positionalArguments[1] as double),
        );
        DonutChartPainter(
          before,
          after,
          progress,
        ).paint(canvas, const Size.square(180));
        if (dashed) {
          expect(radii, [widths.single * 0.4]);
        } else {
          expect(widths, hasLength(2));
          expect(widths.first, widths.last);
        }
      }
    }
  });

  testWidgets('small slices scale only when appearing or disappearing', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: SizedBox()));
    for (final dashed in [false, true]) {
      final visible = [
        DonutChartData.exact(value: 1, color: Colors.blue, dashed: dashed),
        const DonutChartData.exact(value: 1000000, color: Colors.grey),
      ];
      final hidden = [
        DonutChartData.exact(value: 0, color: Colors.blue, dashed: dashed),
        const DonutChartData.exact(value: 1000000, color: Colors.grey),
      ];
      for (final appearing in [false, true]) {
        final canvas = _Canvas();
        double? sliceSize;
        double? ringWidth;
        when(
          () => canvas.drawArc(any(), any(), any(), any(), any()),
        ).thenAnswer((call) {
          final paint = call.positionalArguments[4] as Paint;
          if (paint.color.toARGB32() == Colors.blue.toARGB32()) {
            sliceSize = paint.strokeWidth;
          } else {
            ringWidth = paint.strokeWidth;
          }
        });
        when(() => canvas.drawCircle(any(), any(), any())).thenAnswer(
          (call) => sliceSize =
              (call.positionalArguments[1] as double) * (dashed ? 1 : 2),
        );
        DonutChartPainter(
          appearing ? hidden : visible,
          appearing ? visible : hidden,
          0.5,
        ).paint(canvas, const Size.square(180));
        final t = Curves.easeInOutCubic.transform(0.5);
        final visibility = appearing ? t : 1 - t;
        expect(
          sliceSize,
          closeTo(
            ringWidth! * (dashed ? 0.4 : 1) * min(1.0, visibility * 2),
            0.000001,
          ),
        );
      }
    }
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
    expect(late.last, lessThan(0.02));
    expect(frame(0.999, 1).last, lessThan(late.last));
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

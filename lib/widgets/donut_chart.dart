import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

@immutable
class DonutChartData {
  final double _value;
  final Color color;
  final bool dashed;
  final bool _exact;

  const DonutChartData({
    required double value,
    required this.color,
    this.dashed = false,
  }) : _value = value + 1,
       _exact = false;

  const DonutChartData.exact({
    required double value,
    required this.color,
    this.dashed = false,
  }) : _value = value,
       _exact = true;

  double get value => _value;

  @override
  String toString() {
    return 'DonutChartData{_value: $_value}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DonutChartData &&
          runtimeType == other.runtimeType &&
          _value == other._value &&
          color == other.color &&
          dashed == other.dashed &&
          _exact == other._exact;

  @override
  int get hashCode => Object.hash(_value, color, dashed, _exact);
}

class DonutChart extends StatefulWidget {
  final List<DonutChartData> data;
  final Duration duration;
  final double gapScale;

  const DonutChart({
    super.key,
    required this.data,
    this.duration = commonDuration,
    this.gapScale = 1.2,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<DonutChartData> _oldData;
  List<_DonutArc>? _fromArcs;

  @override
  void initState() {
    super.initState();
    _oldData = widget.data;
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void didUpdateWidget(DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.data, widget.data)) {
      _fromArcs = oldWidget.data.every((item) => item._exact)
          ? DonutChartPainter._fromArcs(
              _oldData,
              oldWidget.data,
              _animationController.value,
              fromArcs: _fromArcs,
              gapScale: oldWidget.gapScale,
            )._interpolatedArcs
          : null;
      _oldData = oldWidget.data;
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: DonutChartPainter._fromArcs(
            _oldData,
            widget.data,
            _animationController.value,
            fromArcs: _fromArcs,
            gapScale: widget.gapScale,
          ),
        );
      },
    );
  }
}

class _DonutArc {
  const _DonutArc(
    this.startTurns,
    this.sweepTurns,
    this.startGaps,
    this.sweepGaps,
  );

  final double startTurns;
  final double sweepTurns;
  final double startGaps;
  final double sweepGaps;

  _DonutArc lerp(_DonutArc target, double progress) {
    return _DonutArc(
      startTurns + (target.startTurns - startTurns) * progress,
      sweepTurns + (target.sweepTurns - sweepTurns) * progress,
      startGaps + (target.startGaps - startGaps) * progress,
      sweepGaps + (target.sweepGaps - sweepGaps) * progress,
    );
  }

  static List<_DonutArc> layout(List<DonutChartData> data) {
    final total = data.fold<double>(0, (sum, item) => sum + item.value);
    final count = data.where((item) => item.value > 0).length;
    var prefix = 0.0;
    var preceding = 0;
    final arcs = <_DonutArc>[];
    for (final item in data) {
      final share = total > 0 ? item.value / total : 0.0;
      arcs.add(
        _DonutArc(
          prefix,
          share,
          count > 1 ? 0.5 + preceding - count * prefix : 0,
          count > 1 ? -count * share : 0,
        ),
      );
      prefix += share;
      if (item.value > 0) {
        preceding++;
      }
    }
    return arcs;
  }
}

class DonutChartPainter extends CustomPainter {
  final List<DonutChartData> oldData;
  final List<DonutChartData> newData;
  final double progress;
  final double gapScale;

  final List<_DonutArc>? _fromArcs;
  final Paint _arcPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  List<DonutChartData>? _cachedInterpolatedData;
  double? _cachedProgress;

  DonutChartPainter(
    this.oldData,
    this.newData,
    this.progress, {
    this.gapScale = 1.2,
  }) : _fromArcs = null;

  DonutChartPainter._fromArcs(
    this.oldData,
    this.newData,
    this.progress, {
    required List<_DonutArc>? fromArcs,
    required this.gapScale,
  }) : _fromArcs = fromArcs;

  List<_DonutArc> get _interpolatedArcs {
    final target = _DonutArc.layout(newData);
    final source = _fromArcs ?? _DonutArc.layout(oldData);
    if (source.length != target.length) {
      return target;
    }
    final t = Curves.easeInOutCubic.transform(progress);
    return [
      for (var i = 0; i < target.length; i++) source[i].lerp(target[i], t),
    ];
  }

  static const _logBase = 10.0;
  static const _minValue = 0.1;
  static final _logBaseInv = 1.0 / log(_logBase);

  double _logTransform(double value) {
    if (value < _minValue) return 0;
    return log(value) * _logBaseInv + 1;
  }

  double _expTransform(double value) {
    if (value <= 0) return 0;
    return pow(_logBase, value - 1).toDouble();
  }

  List<DonutChartData> get _interpolatedData {
    if (_cachedInterpolatedData != null && _cachedProgress == progress) {
      return _cachedInterpolatedData!;
    }

    if (newData.isEmpty) {
      _cachedInterpolatedData = newData;
      _cachedProgress = progress;
      return newData;
    }

    if (oldData.length != newData.length) {
      _cachedInterpolatedData = newData;
      _cachedProgress = progress;
      return newData;
    }

    final result = <DonutChartData>[];
    for (var i = 0; i < newData.length; i++) {
      final oldValue = oldData[i].value;
      final newValue = newData[i].value;
      final logOldValue = _logTransform(oldValue);
      final logNewValue = _logTransform(newValue);
      final interpolatedLogValue =
          logOldValue + (logNewValue - logOldValue) * progress;

      final interpolatedValue = _expTransform(interpolatedLogValue);

      result.add(
        newData[i]._exact
            ? DonutChartData.exact(
                value: interpolatedValue,
                color: newData[i].color,
                dashed: newData[i].dashed,
              )
            : DonutChartData(
                value: interpolatedValue,
                color: newData[i].color,
                dashed: newData[i].dashed,
              ),
      );
    }

    _cachedInterpolatedData = result;
    _cachedProgress = progress;
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final exact = newData.every((item) => item._exact);
    final data = exact ? newData : _interpolatedData;
    final arcs = exact ? _interpolatedArcs : _DonutArc.layout(data);
    if (data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = 10.0.ap;
    final radius = min(size.width / 2, size.height / 2) - strokeWidth / 2;

    final gapAngle = 2 * asin(strokeWidth * 1 / (2 * radius)) * gapScale;
    _arcPaint.strokeWidth = strokeWidth;

    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final arc = arcs[index];
      final startAngle =
          -pi / 2 + arc.startTurns * 2 * pi + arc.startGaps * gapAngle;
      final sweepAngle = arc.sweepTurns * 2 * pi + arc.sweepGaps * gapAngle;
      if (sweepAngle <= 0) continue;

      _arcPaint.color = item.color;

      final rect = Rect.fromCircle(center: center, radius: radius);
      if (item.dashed) {
        _arcPaint.style = PaintingStyle.fill;
        final dotCount = max(
          1,
          (sweepAngle * radius / (strokeWidth * 2.1)).floor(),
        );
        final step = sweepAngle / dotCount;
        for (var dot = 0; dot < dotCount; dot++) {
          final angle = startAngle + (dot + 0.5) * step;
          canvas.drawCircle(
            center + Offset(cos(angle), sin(angle)) * radius,
            min(strokeWidth * 0.4, sweepAngle * radius / 1.5),
            _arcPaint,
          );
        }
      } else {
        _arcPaint.style = PaintingStyle.stroke;
        _arcPaint.strokeCap = StrokeCap.round;
        _arcPaint.strokeWidth = min(strokeWidth, sweepAngle * radius / 1.5 * 2);
        canvas.drawArc(rect, startAngle, sweepAngle, false, _arcPaint);
      }
    }
  }

  @override
  bool shouldRepaint(DonutChartPainter oldDelegate) {
    return oldDelegate.gapScale != gapScale ||
        oldDelegate.progress != progress ||
        oldDelegate._fromArcs != _fromArcs ||
        oldDelegate.oldData != oldData ||
        oldDelegate.newData != newData;
  }
}

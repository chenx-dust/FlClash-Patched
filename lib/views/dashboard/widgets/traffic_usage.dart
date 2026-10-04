import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'traffic_details.dart';

class TrafficUsage extends StatelessWidget {
  const TrafficUsage({super.key});

  void _showDetails(BuildContext context) {
    dialogs.showCommonDialog<void>(
      context: context,
      child: const TrafficDetails(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(2),
      child: RepaintBoundary(
        child: CommonCard(
          radius: AppCorner.lg,
          onPressed: () => _showDetails(context),
          onLongPress: () => _showDetails(context),
          child: Column(
            children: [
              Container(
                height:
                    max(20, globalState.measure.titleSmallHeight) +
                    baseInfoEdgeInsets.top,
                padding: baseInfoEdgeInsets.copyWith(bottom: 0),
                child: Row(
                  children: [
                    Icon(
                      Symbols.data_usage,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: TooltipText(
                        text: Text(
                          appLocalizations.trafficUsage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AspectRatio(
                      aspectRatio: 1,
                      child: ExcludeFocus(
                        child: IconButton(
                          tooltip: appLocalizations.details(
                            appLocalizations.trafficUsage,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => _showDetails(context),
                          icon: Icon(
                            Symbols.info,
                            size: 16.ap,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer(
                  builder: (_, ref, _) {
                    final totalTraffic = ref.watch(totalTrafficProvider);
                    return _TrafficUsageBody(
                      up: totalTraffic.up,
                      down: totalTraffic.down,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrafficUsageBody extends StatelessWidget {
  const _TrafficUsageBody({required this.up, required this.down});

  final num up;
  final num down;

  @override
  Widget build(BuildContext context) {
    final upColor = globalState.theme.darken3PrimaryContainer;
    final downColor = globalState.theme.darken2SecondaryContainer;
    return Padding(
      padding: baseInfoEdgeInsets.copyWith(top: 0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: _TrafficChart(
              up: up,
              down: down,
              upColor: upColor,
              downColor: downColor,
            ),
          ),
          _TrafficDataItem(
            icon: Icon(Symbols.arrow_upward, color: upColor, size: 14),
            value: up,
          ),
          const SizedBox(height: 8),
          _TrafficDataItem(
            icon: Icon(Symbols.arrow_downward, color: downColor, size: 14),
            value: down,
          ),
        ],
      ),
    );
  }
}

class _TrafficChart extends StatelessWidget {
  const _TrafficChart({
    required this.up,
    required this.down,
    required this.upColor,
    required this.downColor,
  });

  final num up;
  final num down;
  final Color upColor;
  final Color downColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: DonutChart(
              data: [
                DonutChartData(value: up.toDouble(), color: upColor),
                DonutChartData(value: down.toDouble(), color: downColor),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _TrafficLegend(upColor: upColor, downColor: downColor),
          ),
        ],
      ),
    );
  }
}

class _TrafficLegend extends StatelessWidget {
  const _TrafficLegend({required this.upColor, required this.downColor});

  final Color upColor;
  final Color downColor;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final labelStyle = context.textTheme.bodySmall;
    return LayoutBuilder(
      builder: (_, container) {
        final uploadLabel = _label(appLocalizations.upload, labelStyle);
        final downloadLabel = _label(appLocalizations.download, labelStyle);
        final uploadSize = _measureLabel(context, uploadLabel);
        final downloadSize = _measureLabel(context, downloadLabel);
        final maxLabelWidth = max(uploadSize.width, downloadSize.width);
        if (maxLabelWidth + 24 > container.maxWidth ||
            uploadSize.height + downloadSize.height + 4 > container.maxHeight) {
          return Container();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendEntry(color: upColor, label: uploadLabel),
            const SizedBox(height: 4),
            _LegendEntry(color: downColor, label: downloadLabel),
          ],
        );
      },
    );
  }

  Size _measureLabel(BuildContext context, Text label) {
    final painter = TextPainter(
      text: TextSpan(text: label.data, style: label.style),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  Text _label(String text, TextStyle? style) {
    return Text(
      maxLines: 1,
      text,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.color, required this.label});

  final Color color;
  final Text label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 8,
          decoration: ShapeDecoration(color: color, shape: AppShape.full),
        ),
        const SizedBox(width: 4),
        label,
      ],
    );
  }
}

class _TrafficDataItem extends StatelessWidget {
  const _TrafficDataItem({required this.icon, required this.value});

  final Icon icon;
  final num value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          flex: 1,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 8),
              Flexible(
                flex: 1,
                child: Text(
                  value.traffic.value,
                  style: context.textTheme.bodySmall,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        Text(value.traffic.unit, style: context.textTheme.bodySmall?.toLighter),
      ],
    );
  }
}

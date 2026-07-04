import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkSpeed extends StatefulWidget {
  const NetworkSpeed({super.key});

  @override
  State<NetworkSpeed> createState() => _NetworkSpeedState();
}

class _NetworkSpeedState extends State<NetworkSpeed> {
  List<Point> initPoints = const [Point(0, 0), Point(1, 0)];

  List<Point> _getPoints(List<Traffic> traffics) {
    const maxLength = 30;
    final paddingCount = maxLength - traffics.length;
    final List<Point> trafficPoints = List.generate(maxLength, (index) {
      final speed =
          index < paddingCount ? 0.0 : traffics[index - paddingCount].speed.toDouble();
      return Point((index + initPoints.length).toDouble(), speed);
    });

    return [...initPoints, ...trafficPoints];
  }

  Traffic _getLastTraffic(List<Traffic> traffics) {
    if (traffics.isEmpty) return const Traffic();
    return traffics.last;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final color = context.colorScheme.onSurfaceVariant.opacity80;
    return SizedBox(
      height: getWidgetHeight(2),
      child: RepaintBoundary(
        child: CommonCard(
          onLongPress: () {},
          child: Consumer(
            builder: (_, ref, _) {
              final traffics = ref.watch(trafficsProvider).list;
              return Column(
                children: [
                  Padding(
                    padding: baseInfoEdgeInsets.copyWith(bottom: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: InfoHeader(
                            padding: EdgeInsets.zero,
                            info: Info(
                              label: appLocalizations.networkSpeed,
                              iconData: Icons.speed_sharp,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getLastTraffic(traffics).speedText,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        16,
                      ).copyWith(bottom: 0, left: 0, right: 0),
                      child: LineChart(
                        gradient: true,
                        color: Theme.of(context).colorScheme.primary,
                        points: _getPoints(traffics),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

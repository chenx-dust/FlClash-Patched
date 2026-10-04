import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

enum _TrafficDirection {
  both,
  upload,
  download;

  int value(NodeTraffic node) => switch (this) {
    both => node.up + node.down,
    upload => node.up,
    download => node.down,
  };
}

typedef _TrafficSlice = ({NodeTraffic? node, int value, Color color});

class TrafficDetails extends ConsumerStatefulWidget {
  const TrafficDetails({super.key});

  @override
  ConsumerState<TrafficDetails> createState() => _TrafficDetailsState();
}

class _TrafficDetailsState extends ConsumerState<TrafficDetails>
    with WidgetsBindingObserver, ActivePollingMixin<TrafficDetails> {
  _TrafficDirection _direction = _TrafficDirection.both;
  AsyncSnapshot<List<NodeTraffic>> _snapshot = const AsyncSnapshot.waiting();

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  Future<void> poll(PollGuard isCurrent) async {
    try {
      final nodes = await ref.read(coreHandlerProvider).getNodeTraffic();
      if (isCurrent()) {
        setState(() {
          _snapshot = AsyncSnapshot.withData(ConnectionState.done, nodes);
        });
      }
    } catch (error, stackTrace) {
      commonPrint.log(
        'getNodeTraffic error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      if (isCurrent()) {
        setState(() {
          _snapshot = AsyncSnapshot.withError(
            ConnectionState.done,
            error,
            stackTrace,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    return CommonDialog(
      title: l10n.nodeTrafficUsage,
      maxWidth: 320,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.confirm),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommonTabBar<_TrafficDirection>(
            groupValue: _direction,
            thumbColor: context.colorScheme.secondaryContainer,
            onValueChanged: (value) {
              if (value != null) {
                setState(() => _direction = value);
              }
            },
            children: {
              _TrafficDirection.both: Text(l10n.trafficBoth),
              _TrafficDirection.upload: Text(l10n.upload),
              _TrafficDirection.download: Text(l10n.download),
            },
          ),
          const SizedBox(height: 16),
          if (_snapshot.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(l10n.nodeTrafficReadFailed),
            )
          else if (!_snapshot.hasData)
            const SizedBox(
              height: 80,
              child: Center(child: CommonCircleLoading()),
            )
          else
            _buildBreakdown(context, _snapshot.requireData),
        ],
      ),
    );
  }

  Widget _buildBreakdown(BuildContext context, List<NodeTraffic> nodes) {
    final l10n = context.appLocalizations;
    final total = nodes.fold(0, (sum, node) => sum + _direction.value(node));
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(l10n.noData)),
      );
    }
    final colors = context.colorScheme;
    final palette = [
      colors.primary,
      colors.secondary,
      colors.tertiary,
      colors.primaryContainer,
      colors.secondaryContainer,
      colors.tertiaryContainer,
    ];
    final ordered = [...nodes]
      ..sort((a, b) {
        final provider = a.provider.compareTo(b.provider);
        return provider != 0 ? provider : a.name.compareTo(b.name);
      });
    final slices = <_TrafficSlice>[];
    var other = 0;
    for (var index = 0; index < ordered.length; index++) {
      final node = ordered[index];
      final value = _direction.value(node);
      if (value * 20 <= total) {
        other += value;
        continue;
      }
      final base = HSVColor.fromColor(palette[index % palette.length]);
      final color = base
          .withHue((base.hue + 137.5 * (index ~/ palette.length)) % 360)
          .toColor();
      slices.add((node: node, value: value, color: color));
    }
    slices.sort((a, b) {
      final value = b.value.compareTo(a.value);
      if (value != 0) {
        return value;
      }
      final provider = a.node!.provider.compareTo(b.node!.provider);
      return provider != 0 ? provider : a.node!.name.compareTo(b.node!.name);
    });
    if (other > 0) {
      slices.add((node: null, value: other, color: colors.outline));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox.square(
            dimension: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DonutChart(
                    gapScale: 1.4,
                    data: [
                      for (final slice in slices)
                        DonutChartData.exact(
                          value: slice.value.toDouble(),
                          color: slice.color,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        switch (_direction) {
                          _TrafficDirection.both => l10n.totalTraffic,
                          _TrafficDirection.upload => l10n.uploadTraffic,
                          _TrafficDirection.download => l10n.downloadTraffic,
                        },
                        style: context.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatTraffic(total),
                          style: context.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 8,
                  decoration: ShapeDecoration(
                    color: slice.color,
                    shape: AppShape.full,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TooltipText(
                        text: Text(
                          slice.node?.name ?? l10n.other,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodyMedium,
                        ),
                      ),
                      if (slice.node?.provider.isNotEmpty ?? false)
                        Text(
                          slice.node!.provider,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTraffic(slice.value),
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(width: 6),
                Text(
                  '${(slice.value / total * 100).toStringAsFixed(1)}%',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _formatTraffic(int value) {
  final traffic = value.traffic;
  return '${traffic.value} ${traffic.unit}';
}

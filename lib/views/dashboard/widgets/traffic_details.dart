import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

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
  bool _showDirect = true;
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
              _TrafficDirection.both: _buildDirectionLabel(
                context,
                _TrafficDirection.both,
                l10n.trafficBoth,
              ),
              _TrafficDirection.upload: _buildDirectionLabel(
                context,
                _TrafficDirection.upload,
                l10n.upload,
              ),
              _TrafficDirection.download: _buildDirectionLabel(
                context,
                _TrafficDirection.download,
                l10n.download,
              ),
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

  Widget _buildDirectionLabel(
    BuildContext context,
    _TrafficDirection direction,
    String label,
  ) {
    final nodes = _snapshot.data;
    final value = nodes
        ?.where((node) => _showDirect || node.name != 'DIRECT')
        .fold(0, (sum, node) => sum + direction.value(node));
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (value != null && direction != _direction)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(switch (direction) {
                    _TrafficDirection.upload => Symbols.arrow_upward,
                    _TrafficDirection.download => Symbols.arrow_downward,
                    _TrafficDirection.both => Symbols.mobiledata_arrows,
                  }, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    _formatTraffic(value),
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreakdown(BuildContext context, List<NodeTraffic> nodes) {
    final l10n = context.appLocalizations;
    final total = nodes.fold(0, (sum, node) => sum + _direction.value(node));
    final direct = nodes.where((node) => node.name == 'DIRECT').firstOrNull;
    final directValue = direct == null ? 0 : _direction.value(direct);
    final proxyTotal = total - directValue;
    final chartTotal = _showDirect ? total : proxyTotal;
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            l10n.noData,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
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
    final ordered = nodes.where((node) => node.name != 'DIRECT').toList()
      ..sort((a, b) {
        final provider = a.provider.compareTo(b.provider);
        return provider != 0 ? provider : a.name.compareTo(b.name);
      });
    final slices = <_TrafficSlice>[];
    var other = 0;
    for (var index = 0; index < ordered.length; index++) {
      final node = ordered[index];
      final value = _direction.value(node);
      if (value * 20 <= chartTotal) {
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
    if (direct != null) {
      slices.add((
        node: direct,
        value: directValue,
        color: colors.onSurfaceVariant.opacity38,
      ));
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
                          value: slice.node?.name == 'DIRECT' && !_showDirect
                              ? 0
                              : slice.value.toDouble(),
                          dashed: slice.node?.name == 'DIRECT',
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
                          _formatTraffic(chartTotal),
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
                SizedBox(
                  width: 20,
                  child: slice.node?.name == 'DIRECT'
                      ? Row(
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              Container(
                                width: 4,
                                height: 4,
                                decoration: ShapeDecoration(
                                  color: slice.color,
                                  shape: AppShape.circle,
                                ),
                              ),
                              if (i < 2) const SizedBox(width: 3),
                            ],
                          ],
                        )
                      : Container(
                          height: 8,
                          decoration: ShapeDecoration(
                            color: slice.color,
                            shape: AppShape.full,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: TooltipText(
                              text: Text(
                                slice.node?.name == 'DIRECT'
                                    ? l10n.direct
                                    : slice.node?.name ?? l10n.other,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                          if (slice.node?.name == 'DIRECT') ...[
                            const SizedBox(width: 4),
                            SizedBox.square(
                              dimension: 24.ap,
                              child: IconButton(
                                tooltip: _showDirect ? l10n.hide : l10n.show,
                                padding: EdgeInsets.zero,
                                onPressed: () =>
                                    setState(() => _showDirect = !_showDirect),
                                icon: Icon(
                                  _showDirect
                                      ? Symbols.visibility
                                      : Symbols.visibility_off,
                                  size: 16.ap,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                if (slice.node?.name != 'DIRECT' || _showDirect) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${(chartTotal == 0 ? 0 : slice.value / chartTotal * 100).toStringAsFixed(1)}%',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
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

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
  final _colorSlots = List<(String, String)?>.filled(6, null);
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
    final value = _snapshot.data
        ?.where((node) => _showDirect || node.name != 'DIRECT')
        .fold(0, (sum, node) => sum + direction.value(node));
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (value != null)
            TweenAnimationBuilder<double>(
              tween: Tween(end: direction == _direction ? 0 : 1),
              duration: midDuration,
              curve: Curves.easeInOutCubic,
              builder: (context, progress, child) => ClipRect(
                child: Align(
                  heightFactor: progress,
                  child: Opacity(opacity: progress, child: child),
                ),
              ),
              child: ExcludeSemantics(
                excluding: direction == _direction,
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
        final value = _direction.value(b).compareTo(_direction.value(a));
        if (value != 0) return value;
        final provider = a.provider.compareTo(b.provider);
        return provider != 0 ? provider : a.name.compareTo(b.name);
      });
    final selectedById = {
      for (final node
          in ordered
              .where((node) => _direction.value(node) * 20 > chartTotal)
              .take(palette.length))
        (node.provider, node.name): node,
    };
    final otherNodes = ordered
        .where(
          (node) =>
              _direction.value(node) > 0 &&
              !selectedById.containsKey((node.provider, node.name)),
        )
        .toList();
    if (otherNodes.length == 1 && selectedById.length < palette.length) {
      final node = otherNodes.single;
      selectedById[(node.provider, node.name)] = node;
    }
    for (var index = 0; index < _colorSlots.length; index++) {
      if (!selectedById.containsKey(_colorSlots[index])) {
        _colorSlots[index] = null;
      }
    }
    for (final id in selectedById.keys) {
      if (!_colorSlots.contains(id)) {
        _colorSlots[_colorSlots.indexOf(null)] = id;
      }
    }
    final slices = <_TrafficSlice>[];
    for (var index = 0; index < palette.length; index++) {
      final node = selectedById[_colorSlots[index]];
      slices.add((
        node: node,
        value: node == null ? 0 : _direction.value(node),
        color: palette[index],
      ));
    }
    slices.addAll([
      (
        node: null,
        value:
            proxyTotal -
            selectedById.values.fold(
              0,
              (sum, node) => sum + _direction.value(node),
            ),
        color: colors.outline,
      ),
      (
        node: direct ?? const NodeTraffic(name: 'DIRECT'),
        value: directValue,
        color: colors.onSurfaceVariant.opacity38,
      ),
    ]);
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
        if (total == 0) Text(l10n.noData),
        for (final slice in slices.where((slice) => slice.value > 0))
          _buildLegendRow(context, slice, chartTotal),
      ],
    );
  }

  Widget _buildLegendRow(
    BuildContext context,
    _TrafficSlice slice,
    int chartTotal,
  ) {
    final l10n = context.appLocalizations;
    final colors = context.colorScheme;
    final isDirect = slice.node?.name == 'DIRECT';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final horizontal = constraints.maxWidth >= textScaler.scale(280);
          final wideSpacing = constraints.maxWidth >= textScaler.scale(240);
          return Row(
            children: [
              SizedBox(
                width: 20,
                child: isDirect
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
                              isDirect
                                  ? l10n.direct
                                  : slice.node?.name ?? l10n.other,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                        if (isDirect) ...[
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
              Flex(
                direction: horizontal ? Axis.horizontal : Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTraffic(slice.value),
                    style: context.textTheme.bodySmall,
                  ),
                  if (!isDirect || _showDirect) ...[
                    SizedBox(
                      width: wideSpacing ? 6 : 0,
                      height: wideSpacing ? 0 : 2,
                    ),
                    Text(
                      '${(chartTotal == 0 ? 0 : slice.value / chartTotal * 100).toStringAsFixed(1)}%',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

String _formatTraffic(int value) {
  final traffic = value.traffic;
  return '${traffic.value} ${traffic.unit}';
}

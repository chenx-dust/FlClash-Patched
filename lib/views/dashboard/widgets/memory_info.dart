import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemoryInfo extends ConsumerStatefulWidget {
  final Future<CoreMemoryInfo> Function()? memoryReader;

  const MemoryInfo({super.key, @visibleForTesting this.memoryReader});

  @override
  ConsumerState<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends ConsumerState<MemoryInfo>
    with WidgetsBindingObserver, ActivePollingMixin<MemoryInfo> {
  final _memoryStateNotifier = ValueNotifier<AsyncSnapshot<CoreMemoryInfo>>(
    const AsyncSnapshot.waiting(),
  );

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  void dispose() {
    _memoryStateNotifier.dispose();
    super.dispose();
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    final memory = await _readMemory();
    if (!isCurrent()) {
      return;
    }
    if (memory == null) {
      if (!_memoryStateNotifier.value.hasData) {
        _memoryStateNotifier.value = AsyncSnapshot.withError(
          ConnectionState.done,
          StateError('Memory unavailable'),
        );
      }
      return;
    }
    _memoryStateNotifier.value = AsyncSnapshot.withData(
      ConnectionState.done,
      memory,
    );
  }

  Future<CoreMemoryInfo?> _readMemory() async {
    try {
      final memoryReader = widget.memoryReader;
      return memoryReader != null
          ? await memoryReader()
          : await _core.getMemory();
    } catch (error) {
      commonPrint.log(
        'updateMemory error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  void _showDetails() {
    dialogs.showCommonDialog<void>(
      context: context,
      child: _MemoryDetails(
        memory: _memoryStateNotifier,
        onClear: _clearMemory,
      ),
    );
  }

  Future<void> _clearMemory() async {
    await _core.requestGc();
    if (mounted) {
      restartPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final titleColor = context.colorScheme.onSurfaceVariant;
    final titleStyle = context.textTheme.titleSmall?.copyWith(
      color: titleColor,
    );
    return SizedBox(
      height: getWidgetHeight(1),
      child: RepaintBoundary(
        child: CommonCard(
          radius: AppCorner.lg,
          onLongPress: _showDetails,
          onPressed: () {
            _core.requestGc();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: globalState.measure.titleMediumHeight + 12,
                padding: baseInfoEdgeInsets.copyWith(bottom: 0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Icon(Symbols.memory, color: titleColor),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 1,
                      child: TooltipText(
                        text: Text(
                          appLocalizations.memoryInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AspectRatio(
                      aspectRatio: 1,
                      child: ExcludeFocus(
                        child: IconButton(
                          tooltip: appLocalizations.details(
                            appLocalizations.memoryInfo,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: _showDetails,
                          icon: Icon(
                            Symbols.info,
                            size: 16.ap,
                            color: titleColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: baseInfoEdgeInsets.copyWith(top: 0),
                child: SizedBox(
                  height: globalState.measure.bodyMediumHeight + 2,
                  child: ValueListenableBuilder(
                    valueListenable: _memoryStateNotifier,
                    builder: (_, memory, _) {
                      return FadeThroughBox(
                        child: TooltipText(
                          text: Text(
                            _formatMemory(memory.data?.total ?? 0),
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryDetails extends StatefulWidget {
  const _MemoryDetails({required this.memory, required this.onClear});

  final ValueListenable<AsyncSnapshot<CoreMemoryInfo>> memory;
  final Future<void> Function() onClear;

  @override
  State<_MemoryDetails> createState() => _MemoryDetailsState();
}

class _MemoryDetailsState extends State<_MemoryDetails> {
  bool _clearing = false;
  bool _showReleased = true;

  Future<void> _clear() async {
    if (_clearing) {
      return;
    }
    setState(() => _clearing = true);
    try {
      await globalState.safeRun(widget.onClear);
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    return CommonDialog(
      title: l10n.memoryInfo,
      maxWidth: 320,
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _clearing ? null : _clear,
              child: Text(l10n.memoryCleanup),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ],
      child: ValueListenableBuilder(
        valueListenable: widget.memory,
        builder: (context, snapshot, _) {
          final data = snapshot.data;
          if (data == null) {
            return snapshot.hasError
                ? Text(l10n.memoryReadFailed)
                : const SizedBox(
                    height: 80,
                    child: Center(child: CommonCircleLoading()),
                  );
          }
          final colors = context.colorScheme;
          final items = <({String label, int value, Color color, bool dashed})>[
            (
              label: l10n.memoryHeapObjects,
              value: data.heapObjects,
              color: colors.primary,
              dashed: false,
            ),
            (
              label: l10n.memoryHeapUnused,
              value: data.heapUnused,
              color: colors.primaryContainer,
              dashed: false,
            ),
            (
              label: l10n.memoryHeapIdle,
              value: data.heapIdle,
              color: colors.secondaryContainer,
              dashed: false,
            ),
            (
              label: l10n.memoryStacks,
              value: data.stacks,
              color: colors.secondary,
              dashed: false,
            ),
            (
              label: l10n.memoryMetadata,
              value: data.metadata,
              color: colors.tertiary,
              dashed: false,
            ),
            (
              label: l10n.memoryGC,
              value: data.gc,
              color: colors.tertiaryContainer,
              dashed: false,
            ),
            (
              label: l10n.memoryOther,
              value: data.other,
              color: colors.outline,
              dashed: false,
            ),
            (
              label: l10n.memoryHeapReleased,
              value: data.heapReleased,
              color: colors.onSurfaceVariant.opacity38,
              dashed: true,
            ),
          ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  child: SizedBox.square(
                    dimension: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: DonutChart(
                            gapScale: 1.4,
                            data: [
                              for (final item in items)
                                DonutChartData.exact(
                                  value: item.dashed && !_showReleased
                                      ? 0
                                      : item.value.toDouble(),
                                  color: item.color,
                                  dashed: item.dashed,
                                ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.memoryTotal,
                              style: context.textTheme.bodySmall,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatMemory(data.total),
                                  style: context.textTheme.titleMedium,
                                ),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(end: _showReleased ? 1 : 0),
                                  duration: commonDuration,
                                  curve: Curves.easeInOutCubic,
                                  builder: (context, value, child) {
                                    return ClipRect(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: value,
                                        child: Opacity(
                                          opacity: value,
                                          child: child,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ExcludeSemantics(
                                    excluding: !_showReleased,
                                    child: Text(
                                      ' / ${_formatMemory(data.sys)}',
                                      style: context
                                          .textTheme
                                          .bodySmall
                                          ?.toLight
                                          .copyWith(
                                            color: colors
                                                .onSurfaceVariant
                                                .opacity60,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: item.dashed
                            ? Row(
                                children: [
                                  for (var i = 0; i < 3; i++) ...[
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: ShapeDecoration(
                                        color: item.color,
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
                                  color: item.color,
                                  shape: AppShape.full,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.label,
                                style: context.textTheme.bodyMedium,
                              ),
                            ),
                            if (item.dashed) ...[
                              const SizedBox(width: 4),
                              SizedBox.square(
                                dimension: 24.ap,
                                child: IconButton(
                                  tooltip: _showReleased
                                      ? l10n.hide
                                      : l10n.show,
                                  padding: EdgeInsets.zero,
                                  onPressed: () => setState(
                                    () => _showReleased = !_showReleased,
                                  ),
                                  icon: Icon(
                                    _showReleased
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
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatMemory(item.value),
                        style: context.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(data.sys == 0 ? 0 : item.value / data.sys * 100).toStringAsFixed(1)}%',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _formatMemory(int value) {
  final traffic = value.traffic;
  return '${traffic.value} ${traffic.unit}';
}

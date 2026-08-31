import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class LogListController extends ValueNotifier<LogsState> {
  LogListController() : super(const LogsState());

  void search(String query) {
    value = value.copyWith(query: query);
  }

  void setUseRegex(bool useRegex) {
    value = value.copyWith(useRegex: useRegex);
  }

  void toggleSource(LogSource source) {
    value = value.toggleSource(source);
  }

  void toggleLevel(LogLevel level) {
    value = value.toggleLevel(level);
  }

  void clearFilters() {
    value = value.clearFilters();
  }

  void setLogs(List<Log> logs) {
    if (identical(logs, value.logs)) {
      return;
    }
    value = value.copyWith(
      logs: value.autoScrollToEnd
          ? logs
          : retainTrimmedHead(value.logs, logs, pausedMaxLogsLength),
    );
  }

  void setAutoScrollToEnd(bool autoScrollToEnd) {
    value = value.copyWith(autoScrollToEnd: autoScrollToEnd);
  }

  void resumeAutoScrollToEnd(List<Log> logs) {
    value = value.copyWith(autoScrollToEnd: true, logs: logs);
  }
}

class LogsView extends ConsumerStatefulWidget {
  const LogsView({super.key});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView> {
  final _listController = LogListController();
  late final ScrollController _scrollController;
  late final CoreController _core;
  bool _logListening = false;

  @override
  void initState() {
    super.initState();
    _core = ref.read(coreHandlerProvider);
    _scrollController = ScrollController(initialScrollOffset: double.maxFinite);
    _listController.setLogs(ref.read(logsProvider).list);
    ref.listenManual(logsProvider.select((state) => state.revision), (_, _) {
      updateLogsThrottler();
    });
    ref.listenManual(coreStatusProvider, (_, _) => _syncListening());
    globalState.isBackground.addListener(_syncListening);
    _syncListening();
  }

  List<Widget> _buildActions() {
    return [
      ValueListenableBuilder<LogsState>(
        valueListenable: _listController,
        builder: (_, state, _) => _LogFilterButton(
          logsState: state,
          onToggleSource: _listController.toggleSource,
          onToggleLevel: _listController.toggleLevel,
          onClear: _listController.clearFilters,
        ),
      ),
      IconButton(
        tooltip: context.appLocalizations.exportLogs,
        onPressed: () {
          _handleExport();
        },
        icon: const Icon(Icons.save_outlined),
      ),
    ];
  }

  @override
  void dispose() {
    globalState.isBackground.removeListener(_syncListening);
    _stopListening();
    _listController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncListening() {
    if (globalState.isBackground.value ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      _stopListening();
      return;
    }
    _startListening();
  }

  void _startListening() {
    if (_logListening) return;
    _logListening = true;
    unawaited(
      _core.startLogNotify().then((logs) {
        if (!mounted || !_logListening) return;
        ref
            .read(logsProvider.notifier)
            .addLogs(
              logs.map((log) => log.copyWith(source: LogSource.core)).toList(),
            );
      }),
    );
  }

  void _stopListening() {
    if (!_logListening) return;
    _logListening = false;
    _core.stopLogNotify();
  }

  Future<void> _handleExport() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.safeRun<bool>(() async {
      return ref.read(logsProvider.notifier).exportLogs();
    }, title: appLocalizations.exportLogs);
    if (res != true) return;
    unawaited(
      dialogs.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(text: appLocalizations.exportSuccess),
      ),
    );
  }

  void updateLogsThrottler() {
    throttler.call(FunctionTag.logs, () {
      if (!mounted) {
        return;
      }
      _listController.setLogs(ref.read(logsProvider).list);
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      actions: _buildActions(),
      searchState: AppBarSearchState(
        onSearch: _listController.search,
        onRegexChange: (value) {
          _listController.setUseRegex(value);
          setState(() {});
        },
        useRegex: _listController.value.useRegex,
      ),
      title: appLocalizations.logs,
      floatingActionButton: ValueListenableBuilder(
        valueListenable: _listController,
        builder: (_, state, _) {
          final autoScrollToEnd = state.autoScrollToEnd;
          return FadeRotationScaleBox(
            child: FloatingActionButton(
              key: ValueKey(autoScrollToEnd),
              onPressed: () {
                if (autoScrollToEnd) {
                  _listController.setAutoScrollToEnd(false);
                } else {
                  _listController.resumeAutoScrollToEnd(
                    ref.read(logsProvider).list,
                  );
                }
              },
              child: autoScrollToEnd
                  ? const Icon(Icons.pause)
                  : const Icon(Icons.play_arrow),
            ),
          );
        },
      ),
      body: ValueListenableBuilder<LogsState>(
        valueListenable: _listController,
        builder: (context, state, _) {
          final logs = state.list;
          if (logs.isEmpty) {
            return NullStatus(
              illustration: const LogEmptyIllustration(),
              label: appLocalizations.nullTip(appLocalizations.logs),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: FloatingScrollbar(
              controller: _scrollController,
              hintBuilder: (fraction) {
                final index = (fraction * (logs.length - 1)).round();
                return logs[index].dateTime;
              },
              child: ScrollToEndBox(
                onCancelToEnd: () {
                  _listController.setAutoScrollToEnd(false);
                },
                controller: _scrollController,
                enable: state.autoScrollToEnd,
                dataSource: logs,
                child: SuperListView.separated(
                  physics: const NextClampingScrollPhysics(),
                  reverse: true,
                  shrinkWrap: true,
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    bottom: 16 + BottomInsetScope.of(context),
                  ),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(height: 0),
                  itemBuilder: (_, index) {
                    final log = logs[index];
                    return LogItem(log: log);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogFilterButton extends StatelessWidget {
  final LogsState logsState;
  final ValueChanged<LogSource> onToggleSource;
  final ValueChanged<LogLevel> onToggleLevel;
  final VoidCallback onClear;

  const _LogFilterButton({
    required this.logsState,
    required this.onToggleSource,
    required this.onToggleLevel,
    required this.onClear,
  });

  String _label(Enum value, bool selected) {
    return '${selected ? '✓ ' : ''}${value.name.toUpperCase()}';
  }

  List<CommonPopupMenuItem> _buildItems(BuildContext context) {
    final l10n = context.appLocalizations;
    return [
      CommonPopupMenuItem(
        icon: Icons.source_outlined,
        label: l10n.source,
        subItems: [
          for (final source in LogSource.values)
            CommonPopupMenuItem(
              label: _label(source, logsState.sources.contains(source)),
              onPressed: () => onToggleSource(source),
            ),
        ],
      ),
      CommonPopupMenuItem(
        icon: Icons.flag_outlined,
        label: l10n.level,
        subItems: [
          for (final level in LogLevel.values)
            if (level != LogLevel.silent)
              CommonPopupMenuItem(
                label: _label(level, logsState.levels.contains(level)),
                onPressed: () => onToggleLevel(level),
              ),
        ],
      ),
      CommonPopupMenuItem(
        icon: Icons.filter_alt_off_outlined,
        label: l10n.reset,
        onPressed: onClear,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return CommonPopupBox(
      popupBuilder: (_) => CommonPopupMenu(items: _buildItems(context)),
      targetBuilder: (open) {
        const icon = Icon(Icons.filter_alt_outlined);
        void onPressed() => open(targetContext: context);
        return logsState.hasFilters
            ? IconButton.filledTonal(
                tooltip: context.appLocalizations.filter,
                onPressed: onPressed,
                icon: icon,
              )
            : IconButton(
                tooltip: context.appLocalizations.filter,
                onPressed: onPressed,
                icon: icon,
              );
      },
    );
  }
}

class LogItem extends StatelessWidget {
  final Log log;

  const LogItem({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final source = log.source.name.toUpperCase();
    final level = log.logLevel.name.toUpperCase();
    return CommonPopupBox(
      popupBuilder: (_) => CommonPopupMenu(
        items: [
          CommonPopupMenuItem(
            icon: Icons.copy,
            label: l10n.copy,
            onPressed: () => copyText(context, log.payload),
          ),
        ],
      ),
      targetBuilder: (open) => GestureDetector(
        onLongPress: () => copyText(context, log.payload),
        onSecondaryTapDown: (_) => open(targetContext: context),
        child: ListItem(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ).copyWith(bottom: 12),
          minVerticalPadding: 0,
          title: Text(
            log.payload,
            style: context.textTheme.bodyMedium?.copyWith(
              color: log.logLevel.color(context),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${l10n.source} $source · ${l10n.level} $level',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      log.dateTime,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

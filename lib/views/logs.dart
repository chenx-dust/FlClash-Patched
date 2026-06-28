import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class LogsView extends ConsumerStatefulWidget {
  const LogsView({super.key});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView> {
  final _logsStateNotifier = ValueNotifier<LogsState>(const LogsState());
  late ScrollController _scrollController;

  List<Log> _logs = [];

  @override
  void initState() {
    super.initState();
    _logs = ref.read(logsProvider).list;
    _scrollController = ScrollController(initialScrollOffset: double.maxFinite);
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(logs: _logs);
    ref.listenManual(logsProvider.select((state) => VM(state.list)), (
      prev,
      next,
    ) {
      if (prev != next) {
        final isEquality = logListEquality.equals(prev?.a, next.a);
        if (!isEquality) {
          _logs = next.a;
          updateLogsThrottler();
        }
      }
    });
  }

  List<Widget> _buildActions() {
    final appLocalizations = context.appLocalizations;
    final logsState = _logsStateNotifier.value;
    return [
      _LogFilterButton(
        logsState: logsState,
        onToggleSource: (source) {
          setState(() {
            _logsStateNotifier.value = _logsStateNotifier.value.toggleSource(
              source,
            );
          });
        },
        onToggleLevel: (level) {
          setState(() {
            _logsStateNotifier.value = _logsStateNotifier.value.toggleLevel(
              level,
            );
          });
        },
        onClear: () {
          setState(() {
            _logsStateNotifier.value = _logsStateNotifier.value.clearFilters();
          });
        },
      ),
      IconButton(
        tooltip: appLocalizations.exportFile,
        onPressed: () {
          _handleExport();
        },
        icon: const Icon(Icons.save_outlined),
      ),
    ];
  }

  void _onSearch(String value) {
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(query: value);
  }

  void _onRegexSearchChange(bool value) {
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
      useRegex: value,
    );
  }

  @override
  void dispose() {
    _logsStateNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.safeRun<bool>(() async {
      return globalState.container.read(logsProvider.notifier).exportLogs();
    }, title: appLocalizations.exportLogs);
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.exportSuccess),
    );
  }

  void updateLogsThrottler() {
    throttler.call(FunctionTag.logs, () {
      if (!mounted) {
        return;
      }
      final isEquality = logListEquality.equals(
        _logs,
        _logsStateNotifier.value.logs,
      );
      if (isEquality) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
            logs: _logs,
          );
        }
      });
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      actions: _buildActions(),
      searchState: AppBarSearchState(
        onSearch: _onSearch,
        onRegexChange: _onRegexSearchChange,
        useRegex: _logsStateNotifier.value.useRegex,
      ),
      title: appLocalizations.logs,
      floatingActionButton: ValueListenableBuilder(
        valueListenable: _logsStateNotifier,
        builder: (_, state, _) {
          final autoScrollToEnd = state.autoScrollToEnd;
          return FadeRotationScaleBox(
            child: FloatingActionButton(
              key: ValueKey(autoScrollToEnd),
              onPressed: () {
                _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
                  autoScrollToEnd: !_logsStateNotifier.value.autoScrollToEnd,
                );
              },
              child: autoScrollToEnd
                  ? const Icon(Icons.pause)
                  : const Icon(Icons.play_arrow),
            ),
          );
        },
      ),
      body: ValueListenableBuilder<LogsState>(
        valueListenable: _logsStateNotifier,
        builder: (context, state, _) {
          final logs = state.list;
          if (logs.isEmpty) {
            return NullStatus(
              illustration: const LogEmptyIllustration(),
              label: appLocalizations.nullTip(appLocalizations.logs),
            );
          }
          final items = logs
              .map<Widget>(
                (log) => LogItem(
                  key: Key(log.dateTime),
                  log: log,
                ),
              )
              .separated(const Divider(height: 0))
              .toList();
          return Align(
            alignment: Alignment.topCenter,
            child: ScrollToEndBox(
              onCancelToEnd: () {
                _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
                  autoScrollToEnd: false,
                );
              },
              controller: _scrollController,
              enable: state.autoScrollToEnd,
              dataSource: logs,
              child: CommonScrollBar(
                controller: _scrollController,
                child: SuperListView.builder(
                  physics: const NextClampingScrollPhysics(),
                  reverse: true,
                  shrinkWrap: true,
                  controller: _scrollController,
                  itemBuilder: (_, index) {
                    return items[index];
                  },
                  itemCount: items.length,
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

  String _getLabel(Enum value) {
    return value.name.toUpperCase();
  }

  List<PopupMenuItemData> _buildItems(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final levels = LogLevel.values
        .where((level) => level != LogLevel.silent)
        .toList();
    return [
      PopupMenuItemData(
        icon: Icons.source_outlined,
        label: appLocalizations.source,
        subItems: [
          for (final source in LogSource.values)
            PopupMenuItemData(
              label: _getLabel(source),
              selected: logsState.sources.contains(source),
              closeOnPressed: false,
              onPressed: () {
                onToggleSource(source);
              },
            ),
        ],
      ),
      PopupMenuItemData(
        icon: Icons.flag_outlined,
        label: appLocalizations.level,
        subItems: [
          for (final level in levels)
            PopupMenuItemData(
              label: _getLabel(level),
              selected: logsState.levels.contains(level),
              closeOnPressed: false,
              onPressed: () {
                onToggleLevel(level);
              },
            ),
        ],
      ),
      PopupMenuItemData(
        icon: Icons.filter_alt_off_outlined,
        label: appLocalizations.reset,
        onPressed: onClear,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return CommonPopupBox(
      popup: CommonPopupMenu(items: _buildItems(context)),
      targetBuilder: (open) {
        if (logsState.hasFilters) {
          return IconButton.filledTonal(
            tooltip: context.appLocalizations.filter,
            onPressed: () {
              open(targetContext: context);
            },
            icon: const Icon(Icons.filter_alt_outlined),
          );
        }
        return IconButton(
          tooltip: context.appLocalizations.filter,
          onPressed: () {
            open(targetContext: context);
          },
          icon: const Icon(Icons.filter_alt_outlined),
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
    final appLocalizations = context.appLocalizations;
    final sourceLabel = log.source.name.toUpperCase();
    final levelLabel = log.logLevel.name.toUpperCase();
    return ListItem(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () {
        copyText(context, log.payload);
      },
      title: Text(
        log.payload,
        style: context.textTheme.bodyMedium?.copyWith(
          color: log.logLevel.color(context),
        ),
      ),
      subtitle: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${appLocalizations.source} $sourceLabel · ${appLocalizations.level} $levelLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                log.dateTime,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurface.opacity80,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

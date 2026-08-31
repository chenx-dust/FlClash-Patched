import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  final Future<List<TrackerInfo>> Function()? connectionsReader;

  const ConnectionsView({super.key, @visibleForTesting this.connectionsReader});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView>
    with WidgetsBindingObserver, ActivePollingMixin<ConnectionsView> {
  CoreController get _core => ref.read(coreHandlerProvider);

  final _listController = TrackerInfoListController();
  final ScrollController _scrollController = ScrollController();
  TrackerInfoFilter _trackerFilter = const TrackerInfoFilter();
  bool _showFilterBar = false;
  TrackerInfoSortType? _sortType;
  bool _sortAscending = false;
  DateTime? _lastUpdatedAt;

  @override
  Duration get pollInterval => const Duration(seconds: 1);

  List<Widget> _buildActions() {
    final appLocalizations = context.appLocalizations;
    return [
      TrackerInfoFilterButton(
        visible: _showFilterBar,
        filter: _trackerFilter,
        onPressed: _toggleFilterBar,
      ),
      IconButton(
        tooltip: appLocalizations.sort,
        onPressed: () async {
          await showSheet(
            context: context,
            props: const SheetProps(isScrollControlled: true),
            builder: (_) => AdaptiveSheetScaffold(
              title: appLocalizations.sort,
              body: StatefulBuilder(
                builder: (_, setSheetState) => _ConnectionSortView(
                  sortType: _sortType,
                  sortAscending: _sortAscending,
                  onSortChanged: (type, ascending) {
                    setState(() {
                      if (_sortType == type && _sortAscending == ascending) {
                        _sortType = null;
                      } else {
                        _sortType = type;
                        _sortAscending = ascending;
                      }
                    });
                    setSheetState(() {});
                  },
                ),
              ),
            ),
          );
          if (!mounted) return;
          await _refreshConnections();
        },
        icon: const Icon(Icons.sort),
      ),
    ];
  }

  void _setTrackerFilter(TrackerInfoFilter filter) {
    setState(() {
      _trackerFilter = filter;
      if (filter.isNotEmpty) _showFilterBar = true;
    });
  }

  void _toggleFilterBar() {
    setState(() {
      if (_showFilterBar || _trackerFilter.isNotEmpty) {
        _showFilterBar = false;
        _trackerFilter = const TrackerInfoFilter();
      } else {
        _showFilterBar = true;
      }
    });
  }

  List<TrackerInfo> _sortConnections(List<TrackerInfo> trackerInfos) {
    final sortType = _sortType;
    if (sortType == null) return trackerInfos;
    final sorted = List<TrackerInfo>.of(trackerInfos)
      ..sort((a, b) {
        return switch (sortType) {
          TrackerInfoSortType.start => a.start.compareTo(b.start),
          TrackerInfoSortType.uploadTraffic => a.upload.compareTo(b.upload),
          TrackerInfoSortType.downloadTraffic => a.download.compareTo(
            b.download,
          ),
          TrackerInfoSortType.uploadSpeed => (a.uploadSpeed ?? 0).compareTo(
            b.uploadSpeed ?? 0,
          ),
          TrackerInfoSortType.downloadSpeed => (a.downloadSpeed ?? 0).compareTo(
            b.downloadSpeed ?? 0,
          ),
          TrackerInfoSortType.destination => a.title.compareTo(b.title),
          TrackerInfoSortType.process => a.metadata.process.compareTo(
            b.metadata.process,
          ),
          TrackerInfoSortType.port =>
            (int.tryParse(a.metadata.destinationPort) ?? 0).compareTo(
              int.tryParse(b.metadata.destinationPort) ?? 0,
            ),
          TrackerInfoSortType.network => a.metadata.network.compareTo(
            b.metadata.network,
          ),
          TrackerInfoSortType.rule => getTrackerInfoRuleText(
            a,
          ).compareTo(getTrackerInfoRuleText(b)),
          TrackerInfoSortType.proxyChains =>
            a.chains.join('\n').compareTo(b.chains.join('\n')),
        };
      });
    return _sortAscending ? sorted : sorted.reversed.toList();
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    final trackerInfos = await _readConnections();
    if (trackerInfos == null || !isCurrent()) {
      return;
    }
    _applyConnections(trackerInfos);
  }

  Future<void> _refreshConnections() async {
    final trackerInfos = await _readConnections();
    if (trackerInfos == null || !mounted) {
      return;
    }
    _applyConnections(trackerInfos);
  }

  Future<List<TrackerInfo>?> _readConnections() async {
    try {
      final connectionsReader = widget.connectionsReader;
      return connectionsReader != null
          ? await connectionsReader()
          : await _core.getConnections();
    } catch (error) {
      commonPrint.log(
        'updateConnections error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  void _applyConnections(List<TrackerInfo> trackerInfos) {
    final updatedAt = DateTime.now();
    final previousUpdatedAt = _lastUpdatedAt;
    final previousTrackerInfos = {
      for (final trackerInfo in _listController.value.trackerInfos)
        trackerInfo.id: trackerInfo,
    };
    final updatedTrackerInfos = previousUpdatedAt == null
        ? trackerInfos
        : trackerInfos.map((trackerInfo) {
            final previous = previousTrackerInfos[trackerInfo.id];
            return previous == null
                ? trackerInfo
                : trackerInfo.withCalculatedSpeed(
                    previous: previous,
                    elapsed: updatedAt.difference(previousUpdatedAt),
                  );
          }).toList();
    _lastUpdatedAt = updatedAt;
    _listController.setTrackerInfos(updatedTrackerInfos);
  }

  Future<void> _handleCloseConnection(String id) async {
    await _core.closeConnection(id);
    await _refreshConnections();
  }

  @override
  void dispose() {
    _listController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      title: appLocalizations.connections,
      onKeywordsUpdate: _listController.updateKeywords,
      searchState: AppBarSearchState(
        onSearch: _listController.search,
        onRegexChange: (value) {
          _listController.setUseRegex(value);
          setState(() {});
        },
        useRegex: _listController.value.useRegex,
      ),
      actions: _buildActions(),
      floatingActionButton: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: _listController,
        builder: (_, state, _) => state.trackerInfos.isEmpty
            ? const SizedBox.shrink()
            : CommonFloatingActionButton(
                onPressed: () async {
                  await _core.closeConnections();
                  await _refreshConnections();
                },
                label: appLocalizations.closeAll,
                icon: const Icon(Icons.clear_all),
              ),
      ),
      body: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: _listController,
        builder: (context, state, _) {
          final connections = _sortConnections(
            state.list.withTrackerFilter(_trackerFilter),
          );
          final body = connections.isEmpty
              ? Expanded(
                  child: NullStatus(
                    label: appLocalizations.nullTip(
                      appLocalizations.connections,
                    ),
                    illustration: const ConnectionEmptyIllustration(),
                  ),
                )
              : Expanded(
                  child: TrackerInfoAnimatedList(
                    controller: _scrollController,
                    trackerInfos: connections,
                    detailTitle: appLocalizations.details(
                      appLocalizations.connection,
                    ),
                    filter: _trackerFilter,
                    onClickFilter: (type, value) {
                      _setTrackerFilter(_trackerFilter.toggle(type, value));
                    },
                    onDetailClosed: _refreshConnections,
                    trailingBuilder: (trackerInfo) => IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        _handleCloseConnection(trackerInfo.id);
                      },
                    ),
                  ),
                );
          return Column(
            children: [
              TrackerInfoFilterBar(
                visible: _showFilterBar,
                trackerInfos: state.trackerInfos,
                filter: _trackerFilter,
                onChanged: _setTrackerFilter,
              ),
              body,
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionSortView extends StatelessWidget {
  final TrackerInfoSortType? sortType;
  final bool sortAscending;
  final void Function(TrackerInfoSortType type, bool ascending) onSortChanged;

  const _ConnectionSortView({
    required this.sortType,
    required this.sortAscending,
    required this.onSortChanged,
  });

  String _label(BuildContext context, TrackerInfoSortType type) {
    final l10n = context.appLocalizations;
    return switch (type) {
      TrackerInfoSortType.start => l10n.time,
      TrackerInfoSortType.uploadTraffic => l10n.uploadTraffic,
      TrackerInfoSortType.downloadTraffic => l10n.downloadTraffic,
      TrackerInfoSortType.uploadSpeed => l10n.uploadSpeed,
      TrackerInfoSortType.downloadSpeed => l10n.downloadSpeed,
      TrackerInfoSortType.destination => l10n.destination,
      TrackerInfoSortType.process => l10n.process,
      TrackerInfoSortType.port => l10n.port,
      TrackerInfoSortType.network => l10n.network,
      TrackerInfoSortType.rule => l10n.rule,
      TrackerInfoSortType.proxyChains => l10n.proxyChains,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        for (final type in TrackerInfoSortType.values)
          ListItem(
            title: Text(_label(context, type)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final ascending in [true, false])
                  IconButton.filledTonal(
                    tooltip: ascending
                        ? context.appLocalizations.ascending
                        : context.appLocalizations.descending,
                    isSelected: sortType == type && sortAscending == ascending,
                    onPressed: () => onSortChanged(type, ascending),
                    icon: Icon(
                      ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

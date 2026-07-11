import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'filter.dart';
import 'item.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView> {
  final _connectionsStateNotifier = ValueNotifier<TrackerInfosState>(
    const TrackerInfosState(),
  );
  final ScrollController _scrollController = ScrollController();
  TrackerInfoFilter _trackerFilter = const TrackerInfoFilter();
  bool _showFilterBar = false;
  TrackerInfoSortType? _sortType;
  bool _sortAscending = false;
  bool _hasDeferredUpdate = false;
  DateTime? _lastUpdatedAt;

  bool get _isCurrentRoute {
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  List<Widget> _buildActions(BuildContext context) {
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
            builder: (_) {
              return AdaptiveSheetScaffold(
                title: appLocalizations.sort,
                body: StatefulBuilder(
                  builder: (_, setSheetState) {
                    return _ConnectionSortView(
                      sortType: _sortType,
                      sortAscending: _sortAscending,
                      onSortChanged: (type, ascending) {
                        setState(() {
                          if (_sortType == type &&
                              _sortAscending == ascending) {
                            _sortType = null;
                            return;
                          }
                          _sortType = type;
                          _sortAscending = ascending;
                        });
                        setSheetState(() {});
                      },
                    );
                  },
                ),
              );
            },
          );
          if (!mounted) {
            return;
          }
          await _updateConnections(flushDeferred: true);
        },
        icon: const Icon(Icons.sort),
      ),
    ];
  }

  Widget _buildFAB() {
    return _ClearConnectionsButton(
      onClick: () async {
        coreController.closeConnections();
        await _updateConnections();
      },
    );
  }

  List<TrackerInfo> _sortConnections(List<TrackerInfo> trackerInfos) {
    final sortType = _sortType;
    if (sortType == null) {
      return trackerInfos;
    }
    final sortedList = List<TrackerInfo>.of(trackerInfos);
    sortedList.sort((a, b) {
      return switch (sortType) {
        TrackerInfoSortType.start => a.start.compareTo(b.start),
        TrackerInfoSortType.uploadTraffic => a.upload.compareTo(b.upload),
        TrackerInfoSortType.downloadTraffic => a.download.compareTo(b.download),
        TrackerInfoSortType.uploadSpeed => (a.uploadSpeed ?? 0).compareTo(
          b.uploadSpeed ?? 0,
        ),
        TrackerInfoSortType.downloadSpeed => (a.downloadSpeed ?? 0).compareTo(
          b.downloadSpeed ?? 0,
        ),
        TrackerInfoSortType.destination => _getDestinationSortText(
          a,
        ).compareTo(_getDestinationSortText(b)),
        TrackerInfoSortType.process => a.metadata.process.compareTo(
          b.metadata.process,
        ),
        TrackerInfoSortType.port => _getDestinationPort(
          a,
        ).compareTo(_getDestinationPort(b)),
        TrackerInfoSortType.network => a.metadata.network.compareTo(
          b.metadata.network,
        ),
        TrackerInfoSortType.rule => _getRuleSortText(
          a,
        ).compareTo(_getRuleSortText(b)),
        TrackerInfoSortType.proxyChains => _getProxyChainsSortText(
          a,
        ).compareTo(_getProxyChainsSortText(b)),
      };
    });
    if (_sortAscending) {
      return sortedList;
    }
    return sortedList.reversed.toList();
  }

  String _getDestinationSortText(TrackerInfo trackerInfo) {
    final metadata = trackerInfo.metadata;
    return metadata.host.takeFirstValid([
      metadata.remoteDestination,
      metadata.destinationIP,
    ]);
  }

  int _getDestinationPort(TrackerInfo trackerInfo) {
    return int.tryParse(trackerInfo.metadata.destinationPort) ?? 0;
  }

  String _getRuleSortText(TrackerInfo trackerInfo) {
    final rulePayload = trackerInfo.rulePayload;
    if (rulePayload.isEmpty) {
      return trackerInfo.rule;
    }
    return '${trackerInfo.rule}($rulePayload)';
  }

  String _getProxyChainsSortText(TrackerInfo trackerInfo) {
    return trackerInfo.chains.join('\n');
  }

  void _onSearch(String value) {
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      query: value,
    );
  }

  void _onRegexSearchChange(bool value) {
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      useRegex: value,
    );
  }

  void _setTrackerFilter(TrackerInfoFilter filter) {
    setState(() {
      _trackerFilter = filter;
      if (filter.isNotEmpty) {
        _showFilterBar = true;
      }
    });
  }

  void _toggleFilterBar() {
    setState(() {
      if (_showFilterBar || _trackerFilter.isNotEmpty) {
        _showFilterBar = false;
        _trackerFilter = const TrackerInfoFilter();
        return;
      }
      _showFilterBar = true;
    });
  }

  @override
  void initState() {
    super.initState();
    foregroundTicker.register(this, _updateConnections);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateConnections();
    });
  }

  Future<void> _updateConnections({bool flushDeferred = false}) async {
    if (!mounted) {
      return;
    }
    if (!flushDeferred && !_isCurrentRoute) {
      _hasDeferredUpdate = true;
      return;
    }
    if (flushDeferred && !_hasDeferredUpdate && !_isCurrentRoute) {
      return;
    }
    final trackerInfos = await coreController.getConnections();
    if (!mounted) {
      return;
    }
    if (!_isCurrentRoute) {
      _hasDeferredUpdate = true;
      return;
    }
    final updatedAt = DateTime.now();
    final previousUpdatedAt = _lastUpdatedAt;
    final previousTrackerInfos = {
      for (final trackerInfo in _connectionsStateNotifier.value.trackerInfos)
        trackerInfo.id: trackerInfo,
    };
    final updatedTrackerInfos = previousUpdatedAt == null
        ? trackerInfos
        : trackerInfos.map((trackerInfo) {
            final previous = previousTrackerInfos[trackerInfo.id];
            if (previous == null) {
              return trackerInfo;
            }
            return trackerInfo.withCalculatedSpeed(
              previous: previous,
              elapsed: updatedAt.difference(previousUpdatedAt),
            );
          }).toList();
    _hasDeferredUpdate = false;
    _lastUpdatedAt = updatedAt;
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      trackerInfos: updatedTrackerInfos,
    );
  }

  Future<void> _handleBlockConnection(String id) async {
    await coreController.closeConnection(id);
    await _updateConnections();
  }

  Widget _buildBody(TrackerInfosState state) {
    final appLocalizations = context.appLocalizations;
    final connections = _sortConnections(
      state.list.withTrackerFilter(_trackerFilter),
    );
    final body = () {
      if (connections.isEmpty) {
        return Expanded(
          child: NullStatus(
            label: appLocalizations.nullTip(appLocalizations.connections),
            illustration: const ConnectionEmptyIllustration(),
          ),
        );
      }
      final items = connections
          .map<Widget>(
            (trackerInfo) => TrackerInfoItem(
              key: Key(trackerInfo.id),
              trackerInfo: trackerInfo,
              onClickFilter: (type, value) {
                _setTrackerFilter(_trackerFilter.add(type, value));
              },
              onDetailClosed: () async {
                await _updateConnections(flushDeferred: true);
              },
              trailing: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: () {
                  _handleBlockConnection(trackerInfo.id);
                },
              ),
              detailTitle: appLocalizations.details(
                appLocalizations.connection,
              ),
            ),
          )
          .separated(const Divider(height: 0))
          .toList();
      return Expanded(
        child: SuperListView.builder(
          controller: _scrollController,
          itemBuilder: (context, index) {
            return items[index];
          },
          itemCount: connections.length,
        ),
      );
    }();
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
  }

  @override
  void dispose() {
    foregroundTicker.unregister(this);
    _connectionsStateNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ValueListenableBuilder<TrackerInfosState>(
      valueListenable: _connectionsStateNotifier,
      builder: (context, state, _) {
        return CommonScaffold(
          title: appLocalizations.connections,
          searchState: AppBarSearchState(
            onSearch: _onSearch,
            onRegexChange: _onRegexSearchChange,
            useRegex: state.useRegex,
          ),
          actions: _buildActions(context),
          floatingActionButton: state.trackerInfos.isEmpty ? null : _buildFAB(),
          body: _buildBody(state),
        );
      },
    );
  }
}

class _ClearConnectionsButton extends StatefulWidget {
  final Future<void> Function() onClick;

  const _ClearConnectionsButton({required this.onClick});

  @override
  State<_ClearConnectionsButton> createState() =>
      _ClearConnectionsButtonState();
}

class _ClearConnectionsButtonState extends State<_ClearConnectionsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  Future<void> _handleClick() async {
    if (_controller.isAnimating) {
      return;
    }
    await _controller.forward();
    try {
      await widget.onClick();
    } finally {
      if (mounted) {
        await _controller.reverse();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return AnimatedBuilder(
      animation: _controller.view,
      builder: (_, child) {
        return FadeTransition(
          opacity: _animation,
          child: ScaleTransition(scale: _animation, child: child),
        );
      },
      child: CommonFloatingActionButton(
        onPressed: _handleClick,
        label: appLocalizations.closeAll,
        icon: const Icon(Icons.clear_all),
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

  String _getTextWithSortType(BuildContext context, TrackerInfoSortType type) {
    final appLocalizations = context.appLocalizations;
    return switch (type) {
      TrackerInfoSortType.start => appLocalizations.time,
      TrackerInfoSortType.uploadTraffic => appLocalizations.uploadTraffic,
      TrackerInfoSortType.downloadTraffic => appLocalizations.downloadTraffic,
      TrackerInfoSortType.uploadSpeed => appLocalizations.uploadSpeed,
      TrackerInfoSortType.downloadSpeed => appLocalizations.downloadSpeed,
      TrackerInfoSortType.destination => appLocalizations.destination,
      TrackerInfoSortType.process => appLocalizations.process,
      TrackerInfoSortType.port => appLocalizations.port,
      TrackerInfoSortType.network => appLocalizations.network,
      TrackerInfoSortType.rule => appLocalizations.rule,
      TrackerInfoSortType.proxyChains => appLocalizations.proxyChains,
    };
  }

  IconData _getIconWithSortType(TrackerInfoSortType type) {
    return switch (type) {
      TrackerInfoSortType.start => Icons.schedule,
      TrackerInfoSortType.uploadTraffic => Icons.upload,
      TrackerInfoSortType.downloadTraffic => Icons.download,
      TrackerInfoSortType.uploadSpeed => Icons.speed,
      TrackerInfoSortType.downloadSpeed => Icons.speed,
      TrackerInfoSortType.destination => Icons.sort_by_alpha,
      TrackerInfoSortType.process => Icons.apps,
      TrackerInfoSortType.port => Icons.numbers,
      TrackerInfoSortType.network => Icons.hub,
      TrackerInfoSortType.rule => Icons.rule,
      TrackerInfoSortType.proxyChains => Icons.account_tree,
    };
  }

  Widget _buildDirectionButton({
    required TrackerInfoSortType type,
    required bool ascending,
  }) {
    final selected = sortType == type && sortAscending == ascending;
    return IconButton.filledTonal(
      isSelected: selected,
      onPressed: () {
        onSortChanged(type, ascending);
      },
      icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
    );
  }

  Widget _buildSortItem(BuildContext context, TrackerInfoSortType type) {
    return ListItem(
      leading: Icon(_getIconWithSortType(type)),
      title: Text(_getTextWithSortType(context, type)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDirectionButton(type: type, ascending: true),
          const SizedBox(width: 8),
          _buildDirectionButton(type: type, ascending: false),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        for (final type in TrackerInfoSortType.values)
          _buildSortItem(context, type),
      ],
    );
  }
}

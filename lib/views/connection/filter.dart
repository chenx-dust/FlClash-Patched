import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

enum TrackerInfoFilterType { process, chain, network, rule }

extension TrackerInfoFilterTypeExt on TrackerInfoFilterType {
  String getLabel(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (this) {
      TrackerInfoFilterType.process => appLocalizations.process,
      TrackerInfoFilterType.chain => appLocalizations.proxyChains,
      TrackerInfoFilterType.network => appLocalizations.networkType,
      TrackerInfoFilterType.rule => appLocalizations.rule,
    };
  }

  IconData get icon {
    return switch (this) {
      TrackerInfoFilterType.process => Icons.apps,
      TrackerInfoFilterType.chain => Icons.account_tree,
      TrackerInfoFilterType.network => Icons.hub,
      TrackerInfoFilterType.rule => Icons.rule,
    };
  }
}

class TrackerInfoFilterEntry {
  final TrackerInfoFilterType type;
  final String value;

  const TrackerInfoFilterEntry({required this.type, required this.value});
}

class TrackerInfoFilter {
  final Set<String> processes;
  final Set<String> chains;
  final Set<String> networks;
  final Set<String> rules;

  const TrackerInfoFilter({
    this.processes = const {},
    this.chains = const {},
    this.networks = const {},
    this.rules = const {},
  });

  bool get isEmpty {
    return processes.isEmpty &&
        chains.isEmpty &&
        networks.isEmpty &&
        rules.isEmpty;
  }

  bool get isNotEmpty => !isEmpty;

  TrackerInfoFilter copyWith({
    Set<String>? processes,
    Set<String>? chains,
    Set<String>? networks,
    Set<String>? rules,
  }) {
    return TrackerInfoFilter(
      processes: processes ?? this.processes,
      chains: chains ?? this.chains,
      networks: networks ?? this.networks,
      rules: rules ?? this.rules,
    );
  }

  TrackerInfoFilter toggle(TrackerInfoFilterType type, String value) {
    Set<String> toggleValue(Set<String> values) {
      final nextValues = Set<String>.from(values);
      if (nextValues.contains(value)) {
        nextValues.remove(value);
      } else {
        nextValues.add(value);
      }
      return nextValues;
    }

    return switch (type) {
      TrackerInfoFilterType.process => copyWith(
        processes: toggleValue(processes),
      ),
      TrackerInfoFilterType.chain => copyWith(chains: toggleValue(chains)),
      TrackerInfoFilterType.network => copyWith(
        networks: toggleValue(networks),
      ),
      TrackerInfoFilterType.rule => copyWith(rules: toggleValue(rules)),
    };
  }

  TrackerInfoFilter add(TrackerInfoFilterType type, String value) {
    Set<String> addValue(Set<String> values) {
      return Set<String>.from(values)..add(value);
    }

    return switch (type) {
      TrackerInfoFilterType.process => copyWith(processes: addValue(processes)),
      TrackerInfoFilterType.chain => copyWith(chains: addValue(chains)),
      TrackerInfoFilterType.network => copyWith(networks: addValue(networks)),
      TrackerInfoFilterType.rule => copyWith(rules: addValue(rules)),
    };
  }

  TrackerInfoFilter remove(TrackerInfoFilterType type, String value) {
    Set<String> removeValue(Set<String> values) {
      return Set<String>.from(values)..remove(value);
    }

    return switch (type) {
      TrackerInfoFilterType.process => copyWith(
        processes: removeValue(processes),
      ),
      TrackerInfoFilterType.chain => copyWith(chains: removeValue(chains)),
      TrackerInfoFilterType.network => copyWith(
        networks: removeValue(networks),
      ),
      TrackerInfoFilterType.rule => copyWith(rules: removeValue(rules)),
    };
  }

  Iterable<TrackerInfoFilterEntry> get entries sync* {
    for (final process in processes) {
      yield TrackerInfoFilterEntry(
        type: TrackerInfoFilterType.process,
        value: process,
      );
    }
    for (final chain in chains) {
      yield TrackerInfoFilterEntry(
        type: TrackerInfoFilterType.chain,
        value: chain,
      );
    }
    for (final network in networks) {
      yield TrackerInfoFilterEntry(
        type: TrackerInfoFilterType.network,
        value: network,
      );
    }
    for (final rule in rules) {
      yield TrackerInfoFilterEntry(
        type: TrackerInfoFilterType.rule,
        value: rule,
      );
    }
  }

  bool matches(TrackerInfo trackerInfo) {
    final metadata = trackerInfo.metadata;
    return _matchesValue(processes, metadata.process) &&
        _matchesAny(chains, trackerInfo.chains) &&
        _matchesValue(networks, metadata.network) &&
        _matchesValue(rules, getTrackerInfoRuleText(trackerInfo));
  }

  bool _matchesValue(Set<String> filters, String value) {
    return filters.isEmpty || filters.contains(value);
  }

  bool _matchesAny(Set<String> filters, Iterable<String> values) {
    return filters.isEmpty || values.any(filters.contains);
  }
}

String getTrackerInfoRuleText(TrackerInfo trackerInfo) {
  final rulePayload = trackerInfo.rulePayload;
  if (rulePayload.isEmpty) {
    return trackerInfo.rule;
  }
  return '${trackerInfo.rule}($rulePayload)';
}

extension TrackerInfoFilterListExt on Iterable<TrackerInfo> {
  List<TrackerInfo> withTrackerFilter(TrackerInfoFilter filter) {
    return where(filter.matches).toList();
  }
}

class TrackerInfoFilterBar extends StatelessWidget {
  final bool visible;
  final List<TrackerInfo> trackerInfos;
  final TrackerInfoFilter filter;
  final ValueChanged<TrackerInfoFilter> onChanged;

  const TrackerInfoFilterBar({
    super.key,
    required this.visible,
    required this.trackerInfos,
    required this.filter,
    required this.onChanged,
  });

  Future<void> _showFilterSheet(
    BuildContext context,
    TrackerInfoFilterType type,
  ) async {
    await showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_) {
        return _TrackerInfoFilterSheet(
          type: type,
          trackerInfos: trackerInfos,
          filter: filter,
          onChanged: onChanged,
        );
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final items = TrackerInfoFilterType.values.map((type) {
      return PopupMenuItemData(
        icon: type.icon,
        label: type.getLabel(context),
        onPressed: () {
          _showFilterSheet(context, type);
        },
      );
    }).toList();
    return CommonPopupBox(
      popup: CommonPopupMenu(items: items),
      targetBuilder: (open) {
        return IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          tooltip: context.appLocalizations.filter,
          onPressed: open,
          icon: const Icon(Icons.add),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBar = visible || filter.isNotEmpty;
    final entries = filter.entries.toList();
    return AnimatedSwitcher(
      duration: animateDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          alignment: AlignmentDirectional.topStart,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: showBar
          ? Padding(
              key: const ValueKey(true),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: entries.isEmpty
                        ? Text(
                            context.appLocalizations.noFilterCondition,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant.opacity60,
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              spacing: 8,
                              children: [
                                for (final entry in entries)
                                  CommonChip(
                                    label: entry.value,
                                    labelStyle: context.textTheme.labelSmall
                                        ?.copyWith(
                                          color: context
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                    avatar: Icon(
                                      entry.type.icon,
                                      color:
                                          context.colorScheme.onSurfaceVariant,
                                      size: 14,
                                    ),
                                    type: ChipType.delete,
                                    onPressed: () {
                                      onChanged(
                                        filter.remove(entry.type, entry.value),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                  ),
                  _buildAddButton(context),
                ],
              ),
            )
          : const SizedBox(key: ValueKey(false)),
    );
  }
}

class TrackerInfoFilterButton extends StatelessWidget {
  final bool visible;
  final TrackerInfoFilter filter;
  final VoidCallback onPressed;

  const TrackerInfoFilterButton({
    super.key,
    required this.visible,
    required this.filter,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (visible || filter.isNotEmpty) {
      return IconButton.filledTonal(
        tooltip: context.appLocalizations.filter,
        onPressed: onPressed,
        icon: const Icon(Icons.filter_alt_outlined),
      );
    }
    return IconButton(
      tooltip: context.appLocalizations.filter,
      onPressed: onPressed,
      icon: const Icon(Icons.filter_alt_outlined),
    );
  }
}

class _TrackerInfoFilterSheet extends StatefulWidget {
  final TrackerInfoFilterType type;
  final List<TrackerInfo> trackerInfos;
  final TrackerInfoFilter filter;
  final ValueChanged<TrackerInfoFilter> onChanged;

  const _TrackerInfoFilterSheet({
    required this.type,
    required this.trackerInfos,
    required this.filter,
    required this.onChanged,
  });

  @override
  State<_TrackerInfoFilterSheet> createState() =>
      _TrackerInfoFilterSheetState();
}

class _TrackerInfoFilterSheetState extends State<_TrackerInfoFilterSheet> {
  late TrackerInfoFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
  }

  void _setFilter(TrackerInfoFilter filter) {
    setState(() {
      _filter = filter;
    });
    widget.onChanged(filter);
  }

  List<String> _sortedOptions(Iterable<String> values) {
    final options = values
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList();
    options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  Map<String, int> _countOptions(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      if (value.trim().isEmpty) {
        continue;
      }
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
  }

  Set<String> _selectedValues(TrackerInfoFilterType type) {
    return switch (type) {
      TrackerInfoFilterType.process => _filter.processes,
      TrackerInfoFilterType.chain => _filter.chains,
      TrackerInfoFilterType.network => _filter.networks,
      TrackerInfoFilterType.rule => _filter.rules,
    };
  }

  List<Widget> _buildSection({
    required BuildContext context,
    required TrackerInfoFilterType type,
    required Iterable<String> rawOptions,
  }) {
    final options = _sortedOptions(rawOptions);
    if (options.isEmpty) {
      return const [];
    }
    final counts = _countOptions(rawOptions);
    final selectedValues = _selectedValues(type);
    final unselectedOptions = options
        .where((option) => !selectedValues.contains(option))
        .toList();
    if (unselectedOptions.isEmpty) {
      return const [];
    }
    return generateSection(
      title: type.getLabel(context),
      items: unselectedOptions.map((option) {
        return ListItem(
          leading: Icon(type.icon),
          title: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              Flexible(child: Text(option)),
              Text(
                '${counts[option] ?? 0}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          onTap: () {
            _setFilter(_filter.add(type, option));
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final trackerInfos = widget.trackerInfos;
    final rawOptions = switch (widget.type) {
      TrackerInfoFilterType.process => trackerInfos.map(
        (item) => item.metadata.process,
      ),
      TrackerInfoFilterType.chain => trackerInfos.expand((item) => item.chains),
      TrackerInfoFilterType.network => trackerInfos.map(
        (item) => item.metadata.network,
      ),
      TrackerInfoFilterType.rule => trackerInfos.map(getTrackerInfoRuleText),
    };
    final items = _buildSection(
      context: context,
      type: widget.type,
      rawOptions: rawOptions,
    );
    return AdaptiveSheetScaffold(
      title: widget.type.getLabel(context),
      body: items.isEmpty
          ? NullStatus(label: appLocalizations.noData)
          : generateListView(items),
    );
  }
}

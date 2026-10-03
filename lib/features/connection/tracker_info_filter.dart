import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/filter_bar.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

enum TrackerInfoFilterType { process, chain, network, rule }

extension TrackerInfoFilterTypeExt on TrackerInfoFilterType {
  String getLabel(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (this) {
      TrackerInfoFilterType.process => appLocalizations.process,
      TrackerInfoFilterType.chain => appLocalizations.proxyGroup,
      TrackerInfoFilterType.network => appLocalizations.networkType,
      TrackerInfoFilterType.rule => appLocalizations.rule,
    };
  }

  IconData get icon {
    return switch (this) {
      TrackerInfoFilterType.process => Symbols.apps,
      TrackerInfoFilterType.chain => Symbols.account_tree,
      TrackerInfoFilterType.network => Symbols.hub,
      TrackerInfoFilterType.rule => Symbols.rule,
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

  bool contains(TrackerInfoFilterType type, String value) {
    return switch (type) {
      TrackerInfoFilterType.process => processes.contains(value),
      TrackerInfoFilterType.chain => chains.contains(value),
      TrackerInfoFilterType.network => networks.contains(value),
      TrackerInfoFilterType.rule => rules.contains(value),
    };
  }

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

  @override
  Widget build(BuildContext context) {
    return FilterChipBar(
      visible: visible,
      active: filter.isNotEmpty,
      chips: [
        for (final entry in filter.entries)
          FilterChipData(
            icon: entry.type.icon,
            label: entry.value,
            onDeleted: () {
              onChanged(filter.remove(entry.type, entry.value));
            },
          ),
      ],
      actions: [
        for (final type in TrackerInfoFilterType.values)
          FilterMenuAction(
            icon: type.icon,
            label: type.getLabel(context),
            onPressed: () {
              _showFilterSheet(context, type);
            },
          ),
      ],
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
    return FilterToggleButton(
      visible: visible,
      active: filter.isNotEmpty,
      onPressed: onPressed,
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

  Set<String> _selectedValues(TrackerInfoFilterType type) {
    return switch (type) {
      TrackerInfoFilterType.process => _filter.processes,
      TrackerInfoFilterType.chain => _filter.chains,
      TrackerInfoFilterType.network => _filter.networks,
      TrackerInfoFilterType.rule => _filter.rules,
    };
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final trackerInfos = widget.trackerInfos;
    return FilterValueSheet(
      title: type.getLabel(context),
      values: switch (type) {
        TrackerInfoFilterType.process => trackerInfos.map(
          (item) => item.metadata.process,
        ),
        TrackerInfoFilterType.chain => trackerInfos.expand(
          (item) => item.chains,
        ),
        TrackerInfoFilterType.network => trackerInfos.map(
          (item) => item.metadata.network,
        ),
        TrackerInfoFilterType.rule => trackerInfos.map(getTrackerInfoRuleText),
      },
      selected: _selectedValues(type),
      labelOf: (value) => value,
      onSelected: (value) {
        _setFilter(_filter.add(type, value));
      },
    );
  }
}

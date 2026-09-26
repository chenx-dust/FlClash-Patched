import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

enum DnsQueryFilterType { type, initiator, upstream, rcode }

extension DnsQueryFilterTypeExt on DnsQueryFilterType {
  String getLabel(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (this) {
      DnsQueryFilterType.type => appLocalizations.recordType,
      DnsQueryFilterType.initiator => appLocalizations.initiator,
      DnsQueryFilterType.upstream => appLocalizations.source,
      DnsQueryFilterType.rcode => appLocalizations.responseCode,
    };
  }

  IconData get icon {
    return switch (this) {
      DnsQueryFilterType.type => Icons.dns_outlined,
      DnsQueryFilterType.initiator => Icons.apps,
      DnsQueryFilterType.upstream => Icons.cloud_outlined,
      DnsQueryFilterType.rcode => Icons.tag,
    };
  }
}

class DnsQueryFilterEntry {
  final DnsQueryFilterType type;
  final String value;

  const DnsQueryFilterEntry({required this.type, required this.value});
}

class DnsQueryFilter {
  final Set<String> types;
  final Set<String> initiators;
  final Set<String> upstreams;
  final Set<String> rcodes;

  const DnsQueryFilter({
    this.types = const {},
    this.initiators = const {},
    this.upstreams = const {},
    this.rcodes = const {},
  });

  bool get isEmpty {
    return types.isEmpty &&
        initiators.isEmpty &&
        upstreams.isEmpty &&
        rcodes.isEmpty;
  }

  bool get isNotEmpty => !isEmpty;

  bool contains(DnsQueryFilterType type, String value) {
    return switch (type) {
      DnsQueryFilterType.type => types.contains(value),
      DnsQueryFilterType.initiator => initiators.contains(value),
      DnsQueryFilterType.upstream => upstreams.contains(value),
      DnsQueryFilterType.rcode => rcodes.contains(value),
    };
  }

  DnsQueryFilter copyWith({
    Set<String>? types,
    Set<String>? initiators,
    Set<String>? upstreams,
    Set<String>? rcodes,
  }) {
    return DnsQueryFilter(
      types: types ?? this.types,
      initiators: initiators ?? this.initiators,
      upstreams: upstreams ?? this.upstreams,
      rcodes: rcodes ?? this.rcodes,
    );
  }

  DnsQueryFilter toggle(DnsQueryFilterType type, String value) {
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
      DnsQueryFilterType.type => copyWith(types: toggleValue(types)),
      DnsQueryFilterType.initiator => copyWith(
        initiators: toggleValue(initiators),
      ),
      DnsQueryFilterType.upstream => copyWith(
        upstreams: toggleValue(upstreams),
      ),
      DnsQueryFilterType.rcode => copyWith(rcodes: toggleValue(rcodes)),
    };
  }

  DnsQueryFilter add(DnsQueryFilterType type, String value) {
    Set<String> addValue(Set<String> values) {
      return Set<String>.from(values)..add(value);
    }

    return switch (type) {
      DnsQueryFilterType.type => copyWith(types: addValue(types)),
      DnsQueryFilterType.initiator => copyWith(
        initiators: addValue(initiators),
      ),
      DnsQueryFilterType.upstream => copyWith(upstreams: addValue(upstreams)),
      DnsQueryFilterType.rcode => copyWith(rcodes: addValue(rcodes)),
    };
  }

  DnsQueryFilter remove(DnsQueryFilterType type, String value) {
    Set<String> removeValue(Set<String> values) {
      return Set<String>.from(values)..remove(value);
    }

    return switch (type) {
      DnsQueryFilterType.type => copyWith(types: removeValue(types)),
      DnsQueryFilterType.initiator => copyWith(
        initiators: removeValue(initiators),
      ),
      DnsQueryFilterType.upstream => copyWith(
        upstreams: removeValue(upstreams),
      ),
      DnsQueryFilterType.rcode => copyWith(rcodes: removeValue(rcodes)),
    };
  }

  Iterable<DnsQueryFilterEntry> get entries sync* {
    for (final type in types) {
      yield DnsQueryFilterEntry(type: DnsQueryFilterType.type, value: type);
    }
    for (final initiator in initiators) {
      yield DnsQueryFilterEntry(
        type: DnsQueryFilterType.initiator,
        value: initiator,
      );
    }
    for (final upstream in upstreams) {
      yield DnsQueryFilterEntry(
        type: DnsQueryFilterType.upstream,
        value: upstream,
      );
    }
    for (final rcode in rcodes) {
      yield DnsQueryFilterEntry(type: DnsQueryFilterType.rcode, value: rcode);
    }
  }

  bool matches(DnsQuery query) {
    return _matchesValue(types, query.type) &&
        _matchesValue(initiators, query.initiator?.name ?? '') &&
        _matchesValue(upstreams, query.upstream) &&
        _matchesValue(rcodes, query.rcode);
  }

  bool _matchesValue(Set<String> filters, String value) {
    return filters.isEmpty || filters.contains(value);
  }
}

String dnsQueryFilterLabel(DnsQueryFilterType type, String value) {
  if (type != DnsQueryFilterType.initiator) {
    return value;
  }
  return DnsQueryInitiator.values.asNameMap()[value]?.label ?? value;
}

extension DnsQueryFilterListExt on Iterable<DnsQuery> {
  List<DnsQuery> withDnsQueryFilter(DnsQueryFilter filter) {
    return where(filter.matches).toList();
  }
}

class DnsQueryFilterBar extends StatelessWidget {
  final bool visible;
  final List<DnsQuery> dnsQueries;
  final DnsQueryFilter filter;
  final ValueChanged<DnsQueryFilter> onChanged;

  const DnsQueryFilterBar({
    super.key,
    required this.visible,
    required this.dnsQueries,
    required this.filter,
    required this.onChanged,
  });

  Future<void> _showFilterSheet(
    BuildContext context,
    DnsQueryFilterType type,
  ) async {
    await showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_) {
        return _DnsQueryFilterSheet(
          type: type,
          dnsQueries: dnsQueries,
          filter: filter,
          onChanged: onChanged,
        );
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final items = DnsQueryFilterType.values.map((type) {
      return CommonPopupMenuItem(
        icon: type.icon,
        label: type.getLabel(context),
        onPressed: () {
          _showFilterSheet(context, type);
        },
      );
    }).toList();
    return CommonPopupBox(
      popupBuilder: (_) => CommonPopupMenu(items: items),
      targetBuilder: (open) {
        return IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          tooltip: context.appLocalizations.filter,
          onPressed: () => open(targetContext: context),
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
                              color: context
                                  .colorScheme
                                  .onSurfaceVariant
                                  .opacity60,
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              spacing: 8,
                              children: [
                                for (final entry in entries)
                                  CommonChip(
                                    label: dnsQueryFilterLabel(
                                      entry.type,
                                      entry.value,
                                    ),
                                    onDeleted: () {
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

class DnsQueryFilterButton extends StatelessWidget {
  final bool visible;
  final DnsQueryFilter filter;
  final VoidCallback onPressed;

  const DnsQueryFilterButton({
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

class _DnsQueryFilterSheet extends StatefulWidget {
  final DnsQueryFilterType type;
  final List<DnsQuery> dnsQueries;
  final DnsQueryFilter filter;
  final ValueChanged<DnsQueryFilter> onChanged;

  const _DnsQueryFilterSheet({
    required this.type,
    required this.dnsQueries,
    required this.filter,
    required this.onChanged,
  });

  @override
  State<_DnsQueryFilterSheet> createState() => _DnsQueryFilterSheetState();
}

class _DnsQueryFilterSheetState extends State<_DnsQueryFilterSheet> {
  late DnsQueryFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
  }

  void _setFilter(DnsQueryFilter filter) {
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

  Set<String> _selectedValues(DnsQueryFilterType type) {
    return switch (type) {
      DnsQueryFilterType.type => _filter.types,
      DnsQueryFilterType.initiator => _filter.initiators,
      DnsQueryFilterType.upstream => _filter.upstreams,
      DnsQueryFilterType.rcode => _filter.rcodes,
    };
  }

  List<Widget> _buildSection({
    required BuildContext context,
    required DnsQueryFilterType type,
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
              Flexible(child: Text(dnsQueryFilterLabel(type, option))),
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
    final dnsQueries = widget.dnsQueries;
    final rawOptions = switch (widget.type) {
      DnsQueryFilterType.type => dnsQueries.map((item) => item.type),
      DnsQueryFilterType.initiator => dnsQueries.map(
        (item) => item.initiator?.name ?? '',
      ),
      DnsQueryFilterType.upstream => dnsQueries.map((item) => item.upstream),
      DnsQueryFilterType.rcode => dnsQueries.map((item) => item.rcode),
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

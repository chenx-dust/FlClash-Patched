import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/filter_bar.dart';
import 'package:fl_clash/models/models.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

enum DnsQueryFilterType { type, initiator, upstream, rcode, cache }

const dnsQueryCachedFilterValue = 'true';
const dnsQueryUncachedFilterValue = 'false';

String dnsQueryCacheFilterValue(bool cached) {
  return cached ? dnsQueryCachedFilterValue : dnsQueryUncachedFilterValue;
}

extension DnsQueryFilterTypeExt on DnsQueryFilterType {
  String getLabel(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (this) {
      DnsQueryFilterType.type => appLocalizations.recordType,
      DnsQueryFilterType.initiator => appLocalizations.initiator,
      DnsQueryFilterType.upstream => appLocalizations.source,
      DnsQueryFilterType.rcode => appLocalizations.responseCode,
      DnsQueryFilterType.cache => appLocalizations.cache,
    };
  }

  IconData get icon {
    return switch (this) {
      DnsQueryFilterType.type => Symbols.dns,
      DnsQueryFilterType.initiator => Symbols.apps,
      DnsQueryFilterType.upstream => Symbols.cloud,
      DnsQueryFilterType.rcode => Symbols.tag,
      DnsQueryFilterType.cache => Symbols.cached,
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
  final Set<String> caches;

  const DnsQueryFilter({
    this.types = const {},
    this.initiators = const {},
    this.upstreams = const {},
    this.rcodes = const {},
    this.caches = const {},
  });

  bool get isEmpty {
    return types.isEmpty &&
        initiators.isEmpty &&
        upstreams.isEmpty &&
        rcodes.isEmpty &&
        caches.isEmpty;
  }

  bool get isNotEmpty => !isEmpty;

  Set<String> valuesOf(DnsQueryFilterType type) {
    return switch (type) {
      DnsQueryFilterType.type => types,
      DnsQueryFilterType.initiator => initiators,
      DnsQueryFilterType.upstream => upstreams,
      DnsQueryFilterType.rcode => rcodes,
      DnsQueryFilterType.cache => caches,
    };
  }

  bool contains(DnsQueryFilterType type, String value) {
    return valuesOf(type).contains(value);
  }

  DnsQueryFilter copyWith({
    Set<String>? types,
    Set<String>? initiators,
    Set<String>? upstreams,
    Set<String>? rcodes,
    Set<String>? caches,
  }) {
    return DnsQueryFilter(
      types: types ?? this.types,
      initiators: initiators ?? this.initiators,
      upstreams: upstreams ?? this.upstreams,
      rcodes: rcodes ?? this.rcodes,
      caches: caches ?? this.caches,
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
      DnsQueryFilterType.cache => copyWith(caches: toggleValue(caches)),
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
      DnsQueryFilterType.cache => copyWith(caches: addValue(caches)),
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
      DnsQueryFilterType.cache => copyWith(caches: removeValue(caches)),
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
    for (final cache in caches) {
      yield DnsQueryFilterEntry(type: DnsQueryFilterType.cache, value: cache);
    }
  }

  bool matches(DnsQuery query) {
    return _matchesValue(types, query.type) &&
        _matchesValue(initiators, query.initiator?.name ?? '') &&
        _matchesValue(upstreams, query.upstream) &&
        _matchesValue(rcodes, query.rcode) &&
        _matchesValue(caches, dnsQueryCacheFilterValue(query.cached));
  }

  bool _matchesValue(Set<String> filters, String value) {
    return filters.isEmpty || filters.contains(value);
  }
}

String dnsQueryFilterLabel(DnsQueryFilterType type, String value) {
  return switch (type) {
    DnsQueryFilterType.initiator =>
      DnsQueryInitiator.values.asNameMap()[value]?.label ?? value,
    DnsQueryFilterType.cache => switch (value) {
      dnsQueryCachedFilterValue => currentAppLocalizations.yes,
      dnsQueryUncachedFilterValue => currentAppLocalizations.no,
      _ => value,
    },
    DnsQueryFilterType.type ||
    DnsQueryFilterType.upstream ||
    DnsQueryFilterType.rcode => value,
  };
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

  Iterable<String> _valuesOf(DnsQueryFilterType type) {
    return switch (type) {
      DnsQueryFilterType.type => dnsQueries.map((item) => item.type),
      DnsQueryFilterType.initiator => dnsQueries.map(
        (item) => item.initiator?.name ?? '',
      ),
      DnsQueryFilterType.upstream => dnsQueries.map((item) => item.upstream),
      DnsQueryFilterType.rcode => dnsQueries.map((item) => item.rcode),
      DnsQueryFilterType.cache => dnsQueries.map(
        (item) => dnsQueryCacheFilterValue(item.cached),
      ),
    };
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
            label: dnsQueryFilterLabel(entry.type, entry.value),
            onDeleted: () {
              onChanged(filter.remove(entry.type, entry.value));
            },
          ),
      ],
      groups: [
        for (final type in DnsQueryFilterType.values)
          FilterMenuGroup(
            icon: type.icon,
            label: type.getLabel(context),
            values: _valuesOf(type),
            selected: filter.valuesOf(type),
            labelOf: (value) => dnsQueryFilterLabel(type, value),
            onToggled: (value) => onChanged(filter.toggle(type, value)),
          ),
      ],
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
    return FilterToggleButton(
      visible: visible,
      active: filter.isNotEmpty,
      onPressed: onPressed,
    );
  }
}

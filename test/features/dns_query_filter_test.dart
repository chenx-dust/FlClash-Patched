import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/dns/dns_query_filter.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

DnsQuery _query({
  required String domain,
  String type = 'A',
  String? initiator = 'app',
  String upstream = 'udp://1.1.1.1:53',
  String rcode = 'NOERROR',
  List<String> answers = const ['1.1.1.1'],
  String error = '',
}) {
  return DnsQuery(
    domain: domain,
    type: type,
    initiator: initiator == null
        ? null
        : DnsQueryInitiator.values.byName(initiator),
    upstream: upstream,
    rcode: rcode,
    answers: answers,
    error: error,
    time: DateTime.utc(2026),
  );
}

void main() {
  group('DnsQueryFilter', () {
    test('keeps the four filter dimensions independent', () {
      const empty = DnsQueryFilter();

      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);

      final filter = empty
          .add(DnsQueryFilterType.type, 'A')
          .add(DnsQueryFilterType.initiator, 'app')
          .add(DnsQueryFilterType.upstream, 'udp://1.1.1.1:53')
          .add(DnsQueryFilterType.rcode, 'NOERROR');

      expect(filter.isEmpty, isFalse);
      expect(filter.entries.map((entry) => (entry.type, entry.value)), [
        (DnsQueryFilterType.type, 'A'),
        (DnsQueryFilterType.initiator, 'app'),
        (DnsQueryFilterType.upstream, 'udp://1.1.1.1:53'),
        (DnsQueryFilterType.rcode, 'NOERROR'),
      ]);
      expect(empty.isEmpty, isTrue);
    });

    test('toggle and remove return updated copies', () {
      const original = DnsQueryFilter(
        types: {'A'},
        initiators: {'rule'},
        upstreams: {'udp://1.1.1.1:53'},
        rcodes: {'NXDOMAIN'},
      );

      for (final entry in original.entries) {
        final removed = original.toggle(entry.type, entry.value);
        expect(removed.contains(entry.type, entry.value), isFalse);
        expect(original.contains(entry.type, entry.value), isTrue);
        expect(
          removed
              .toggle(entry.type, entry.value)
              .contains(entry.type, entry.value),
          isTrue,
        );
        expect(
          original
              .remove(entry.type, entry.value)
              .contains(entry.type, entry.value),
          isFalse,
        );
      }
    });

    test('matches every active dimension and filters an iterable', () {
      final matching = _query(domain: 'matching.example');
      final otherType = _query(domain: 'type.example', type: 'AAAA');
      final otherInitiator = _query(
        domain: 'initiator.example',
        initiator: 'proxy',
      );
      final missingInitiator = _query(domain: 'empty.example', initiator: null);
      final otherUpstream = _query(
        domain: 'upstream.example',
        upstream: 'udp://8.8.8.8:53',
      );
      final otherRcode = _query(domain: 'rcode.example', rcode: 'SERVFAIL');
      const filter = DnsQueryFilter(
        types: {'A'},
        initiators: {'app'},
        upstreams: {'udp://1.1.1.1:53'},
        rcodes: {'NOERROR'},
      );

      expect(const DnsQueryFilter().matches(matching), isTrue);
      expect(filter.matches(matching), isTrue);
      expect(filter.matches(otherType), isFalse);
      expect(filter.matches(otherInitiator), isFalse);
      expect(filter.matches(missingInitiator), isFalse);
      expect(filter.matches(otherUpstream), isFalse);
      expect(filter.matches(otherRcode), isFalse);
      expect(
        [
          matching,
          otherType,
          otherInitiator,
          otherUpstream,
          otherRcode,
        ].withDnsQueryFilter(filter).map((item) => item.domain),
        ['matching.example'],
      );
    });

    test('stores initiator as the enum name', () {
      final filter = const DnsQueryFilter().add(
        DnsQueryFilterType.initiator,
        DnsQueryInitiator.direct.name,
      );

      expect(filter.initiators, {'direct'});
      expect(
        filter.matches(_query(domain: 'direct.example', initiator: 'direct')),
        isTrue,
      );
      expect(filter.matches(_query(domain: 'app.example')), isFalse);
    });
  });
}

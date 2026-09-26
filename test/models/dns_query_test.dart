import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  final time = DateTime.utc(2026, 9, 26, 4, 0);

  DnsQuery query({
    String domain = 'example.com',
    String type = 'A',
    String? initiator = 'app',
    bool cached = false,
    List<String> answers = const ['1.1.1.1'],
    String rcode = 'NOERROR',
    String error = '',
    String upstream = 'udp://1.1.1.1:53',
  }) {
    return DnsQuery(
      domain: domain,
      type: type,
      initiator: initiator == null
          ? null
          : DnsQueryInitiator.values.byName(initiator),
      cached: cached,
      answers: answers,
      rcode: rcode,
      error: error,
      upstream: upstream,
      delay: 12,
      time: time,
    );
  }

  test('fromJson keeps an unknown initiator empty', () {
    final parsed = DnsQuery.fromJson({
      'domain': 'example.com',
      'type': 'AAAA',
      'initiator': 'future',
      'answers': <String>[],
      'time': time.toIso8601String(),
    });

    expect(parsed.initiator, isNull);
    expect(parsed.type, 'AAAA');
    expect(parsed.answers, isEmpty);
  });

  test('search matches the domain and hides other queries', () {
    const state = DnsQueriesState(dnsQueries: []);
    final listed = state
        .copyWith(
          query: 'edge',
          dnsQueries: [
            query(domain: 'edge.example'),
            query(domain: 'other.example', answers: const ['9.9.9.9']),
          ],
        )
        .list;

    expect(listed, hasLength(1));
    expect(listed.single.domain, 'edge.example');
  });

  test('a failure rcode is searchable and marks the query failed', () {
    final failed = query(rcode: 'NXDOMAIN', answers: const []);

    expect(failed.isFailed, isTrue);
    expect(
      const DnsQueriesState()
          .copyWith(query: 'nxdomain', dnsQueries: [failed])
          .list,
      [failed],
    );
  });
}

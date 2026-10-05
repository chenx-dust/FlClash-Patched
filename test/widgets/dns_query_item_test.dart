import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/dns_queries.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

DnsQuery _query({
  String error = '',
  String rcode = 'NOERROR',
  bool cached = false,
  List<String> answers = const ['1.1.1.1'],
}) {
  return DnsQuery(
    domain: 'example.com',
    type: 'A',
    initiator: DnsQueryInitiator.app,
    upstream: 'udp://1.1.1.1:53',
    cached: cached,
    answers: answers,
    rcode: rcode,
    error: error,
    delay: 12,
    time: DateTime(2026, 9, 26, 12, 0),
  );
}

void main() {
  testWidgets('DNS detail wraps long errors within a narrow viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final error = List.filled(
      8,
      'exchange failed: read udp 192.168.1.2:54321->1.1.1.1:53: i/o timeout',
    ).join(' ');
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => Scaffold(body: child),
        child: DnsQueryItem(
          dnsQuery: _query(error: error, answers: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('example.com'));
    await tester.pumpAndSettle();
    final detailError = find.descendant(
      of: find.byType(DnsQueryDetailView),
      matching: find.text(error),
    );
    await tester.ensureVisible(detailError);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final errorRect = tester.getRect(detailError);
    expect(errorRect.left, greaterThanOrEqualTo(0));
    expect(errorRect.right, lessThanOrEqualTo(360));
    expect(errorRect.height, greaterThan(100));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('DnsQueryItem lays out a record and filters from its tags', (
    tester,
  ) async {
    final filtered = <(DnsQueryFilterType, String)>[];
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => Scaffold(body: child),
        child: DnsQueryItem(
          dnsQuery: _query(cached: true),
          onClickFilter: (type, value) => filtered.add((type, value)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('1.1.1.1'), findsOneWidget);
    expect(find.text('12 ms'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('udp://1.1.1.1:53'), findsOneWidget);
    final header = tester.getRect(find.byType(RecordHeader));
    final delay = tester.getRect(find.text('12 ms'));
    expect(header.right - delay.right, lessThanOrEqualTo(1));

    await tester.tap(find.text('example.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record type'));
    await tester.pump();
    await tester.tap(find.text('Cache').last);
    await tester.pump();
    expect(filtered, [
      (DnsQueryFilterType.type, 'A'),
      (DnsQueryFilterType.cache, dnsQueryCachedFilterValue),
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('DnsQueryItem marks a failed query', (tester) async {
    await tester.pumpWidget(
      TestApp(
        homeBuilder: (child) => Scaffold(body: child),
        child: DnsQueryItem(
          dnsQuery: _query(
            error: 'timeout',
            rcode: 'SERVFAIL',
            answers: const [],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('timeout'), findsOneWidget);
    expect(find.text('SERVFAIL'), findsOneWidget);
    final decorated = tester.widget<DecoratedBox>(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration && decoration.border is Border;
      }),
    );
    final border = (decorated.decoration as BoxDecoration).border! as Border;
    expect(border.left.width, 3);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

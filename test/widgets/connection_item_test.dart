import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

TrackerInfo _tracker({
  String rule = 'DOMAIN-SUFFIX',
  String rulePayload = '',
  String process = '',
  int uid = 0,
  String sourceIP = '',
  String sourcePort = '',
  String destinationIP = '',
  String destinationPort = '',
  String host = '',
  List<String> chains = const [],
}) {
  return TrackerInfo(
    id: '1',
    start: DateTime(2026, 1, 1, 10, 30),
    metadata: Metadata(
      network: 'tcp',
      process: process,
      uid: uid,
      sourceIP: sourceIP,
      sourcePort: sourcePort,
      destinationIP: destinationIP,
      destinationPort: destinationPort,
      host: host,
    ),
    chains: chains,
    rule: rule,
    rulePayload: rulePayload,
  );
}

void main() {
  testWidgets('proxy chain collapse setting updates connection rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => Scaffold(body: child),
        child: TrackerInfoItem(
          trackerInfo: _tracker(
            chains: const ['last', 'middle-b', 'middle-a', 'first'],
          ),
          detailTitle: 'detail',
        ),
      ),
    );
    expect(find.text('...', findRichText: true), findsOneWidget);
    expect(find.text('middle-a', findRichText: true), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TrackerInfoItem)),
    );
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(collapseProxyChains: false));
    await tester.pump();
    expect(find.text('...', findRichText: true), findsNothing);
    expect(find.text('middle-a', findRichText: true), findsOneWidget);
    expect(find.text('middle-b', findRichText: true), findsOneWidget);
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(collapseProxyChains: true));
    await tester.pump();
    expect(find.text('...', findRichText: true), findsOneWidget);
    expect(find.text('middle-a', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TrackerInfoDetailView renders formatted connection fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        homeBuilder: (child) => Scaffold(body: child),
        child: SheetProvider(
          type: SheetType.page,
          child: TrackerInfoDetailView(
            trackerInfo: _tracker(
              rule: 'DOMAIN-SUFFIX',
              rulePayload: 'example.com',
              process: 'chrome',
              uid: 1000,
              sourceIP: '1.2.3.4',
              sourcePort: '8080',
              destinationIP: '5.6.7.8',
              destinationPort: '443',
              host: 'example.com',
              chains: const ['DIRECT'],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('DOMAIN-SUFFIX(example.com)'), findsOneWidget);
    expect(find.text('chrome(1000)'), findsOneWidget);
    expect(find.text('1.2.3.4:8080'), findsOneWidget);
    expect(find.text('5.6.7.8:443'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('DIRECT', findRichText: true),
      100,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('DIRECT', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('TrackerInfoDetailView omits empty fields', (tester) async {
    await tester.pumpWidget(
      TestApp(
        homeBuilder: (child) => Scaffold(body: child),
        child: SheetProvider(
          type: SheetType.page,
          child: TrackerInfoDetailView(trackerInfo: _tracker()),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('('), findsNothing);
    expect(find.text('tcp'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('TrackerInfoItem shows all chains and forwards their clicks', (
    tester,
  ) async {
    final clicked = <String>[];
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => Scaffold(body: child),
        child: TrackerInfoItem(
          trackerInfo: _tracker(chains: const ['Proxy A', 'Proxy B']),
          detailTitle: 'detail',
          onClickKeyword: clicked.add,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TCP'), findsOneWidget);
    expect(find.text('DOMAIN-SUFFIX'), findsOneWidget);
    expect(find.text('Proxy A', findRichText: true), findsOneWidget);
    expect(find.text('Proxy B', findRichText: true), findsOneWidget);
    expect(find.text('→'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('DOMAIN-SUFFIX')).dx,
      lessThan(tester.getTopLeft(find.text('Proxy B', findRichText: true)).dx),
    );
    expect(
      tester.getTopLeft(find.text('Proxy B', findRichText: true)).dx,
      lessThan(tester.getTopLeft(find.text('Proxy A', findRichText: true)).dx),
    );

    await tester.tap(find.text('Proxy A', findRichText: true));
    await tester.pump();
    await tester.tap(find.text('Proxy B', findRichText: true));
    await tester.pump();

    expect(clicked, ['Proxy A', 'Proxy B']);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('TrackerInfoItem lays out destination and live speeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => Scaffold(body: child),
        child: TrackerInfoItem(
          isLive: true,
          detailTitle: 'detail',
          trackerInfo: _tracker(
            host: 'example.com',
            destinationIP: '5.6.7.8',
            destinationPort: '443',
            process: 'chrome',
            sourceIP: '1.2.3.4',
            sourcePort: '8080',
          ).copyWith(uploadSpeed: 1024, downloadSpeed: 2048),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('example.com:443'), findsOneWidget);
    expect(find.textContaining('5.6.7.8'), findsOneWidget);
    expect(find.textContaining('chrome'), findsOneWidget);
    expect(find.textContaining('1.2.3.4:8080'), findsOneWidget);
    expect(find.textContaining('1KB/s'), findsOneWidget);
    expect(find.textContaining('2KB/s'), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_upward), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_downward), findsOneWidget);
    final header = tester.getRect(find.byType(RecordHeader));
    final speed = tester.getRect(find.textContaining('2KB/s'));
    expect(header.right - speed.right, lessThanOrEqualTo(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('TrackerInfoItem keeps the close action outside the header', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => Scaffold(body: child),
        child: TrackerInfoItem(
          isLive: true,
          detailTitle: 'detail',
          trackerInfo: _tracker(
            chains: const ['Proxy A', 'Proxy B'],
          ).copyWith(uploadSpeed: 1024, downloadSpeed: 2048),
          trailing: IconButton(
            onPressed: () {},
            icon: const Icon(Symbols.close),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Symbols.close), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RecordHeader),
        matching: find.byIcon(Symbols.close),
      ),
      findsNothing,
    );
    final tile = tester.getRect(find.byType(ListTile));
    final header = tester.getRect(find.byType(RecordHeader));
    final button = tester.getRect(find.byType(IconButton));
    final speed = tester.getRect(find.textContaining('2KB/s'));
    expect(header.right - speed.right, lessThanOrEqualTo(1));
    expect((header.right - button.right).abs(), lessThanOrEqualTo(1));
    expect(button.top, greaterThanOrEqualTo(header.bottom));
    expect(tile.bottom - button.bottom, lessThanOrEqualTo(16));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

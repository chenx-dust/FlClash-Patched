import 'package:fl_clash/features/connection/connection.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

TrackerInfo _tracker({
  required String id,
  String process = 'curl',
  String network = 'tcp',
  List<String> chains = const ['Proxy'],
  String rule = 'DOMAIN',
  String rulePayload = 'example.com',
}) {
  return TrackerInfo(
    id: id,
    start: DateTime.utc(2026),
    metadata: Metadata(process: process, network: network),
    chains: chains,
    rule: rule,
    rulePayload: rulePayload,
  );
}

void main() {
  group('TrackerInfoFilter', () {
    test('keeps the four filter dimensions independent', () {
      const empty = TrackerInfoFilter();

      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);

      final filter = empty
          .add(TrackerInfoFilterType.process, 'curl')
          .add(TrackerInfoFilterType.chain, 'Proxy')
          .add(TrackerInfoFilterType.network, 'tcp')
          .add(TrackerInfoFilterType.rule, 'DOMAIN(example.com)');

      expect(filter.isEmpty, isFalse);
      expect(filter.isNotEmpty, isTrue);
      for (final entry in filter.entries) {
        expect(filter.contains(entry.type, entry.value), isTrue);
      }
      expect(filter.entries.map((entry) => (entry.type, entry.value)), [
        (TrackerInfoFilterType.process, 'curl'),
        (TrackerInfoFilterType.chain, 'Proxy'),
        (TrackerInfoFilterType.network, 'tcp'),
        (TrackerInfoFilterType.rule, 'DOMAIN(example.com)'),
      ]);
      expect(empty.isEmpty, isTrue);
    });

    test('toggle and remove return updated copies', () {
      const original = TrackerInfoFilter(
        processes: {'curl'},
        chains: {'Proxy'},
        networks: {'tcp'},
        rules: {'MATCH'},
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

      final copied = original.copyWith(processes: {'wget'});
      expect(copied.processes, {'wget'});
      expect(copied.chains, original.chains);
      expect(copied.networks, original.networks);
      expect(copied.rules, original.rules);
    });

    test('matches every active dimension and filters an iterable', () {
      final matching = _tracker(
        id: 'matching',
        chains: const ['Selector', 'Proxy'],
      );
      final otherProcess = _tracker(id: 'process', process: 'browser');
      final otherChain = _tracker(id: 'chain', chains: const ['Direct']);
      final otherNetwork = _tracker(id: 'network', network: 'udp');
      final otherRule = _tracker(id: 'rule', rule: 'MATCH', rulePayload: '');
      const filter = TrackerInfoFilter(
        processes: {'curl'},
        chains: {'Proxy'},
        networks: {'tcp'},
        rules: {'DOMAIN(example.com)'},
      );

      expect(const TrackerInfoFilter().matches(matching), isTrue);
      expect(filter.matches(matching), isTrue);
      expect(filter.matches(otherProcess), isFalse);
      expect(filter.matches(otherChain), isFalse);
      expect(filter.matches(otherNetwork), isFalse);
      expect(filter.matches(otherRule), isFalse);
      expect(
        [
          matching,
          otherProcess,
          otherChain,
          otherNetwork,
          otherRule,
        ].withTrackerFilter(filter).map((item) => item.id),
        ['matching'],
      );
      expect(getTrackerInfoRuleText(matching), 'DOMAIN(example.com)');
      expect(getTrackerInfoRuleText(otherRule), 'MATCH');
    });
  });

  testWidgets('filter types expose localized labels and distinct icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        child: Builder(
          builder: (context) {
            return Column(
              children: [
                for (final type in TrackerInfoFilterType.values) ...[
                  Text(type.getLabel(context)),
                  Icon(type.icon),
                ],
              ],
            );
          },
        ),
      ),
    );

    expect(find.text('Process'), findsOneWidget);
    expect(find.text('Proxy chain'), findsOneWidget);
    expect(find.text('Network type'), findsOneWidget);
    expect(find.text('Rule'), findsOneWidget);
    expect(find.byIcon(Icons.apps), findsOneWidget);
    expect(find.byIcon(Icons.account_tree), findsOneWidget);
    expect(find.byIcon(Icons.hub), findsOneWidget);
    expect(find.byIcon(Icons.rule), findsOneWidget);
  });

  testWidgets('filter bar shows its empty state and removes a chip', (
    tester,
  ) async {
    var filter = const TrackerInfoFilter(processes: {'curl'});

    await tester.pumpWidget(
      TestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            return TrackerInfoFilterBar(
              visible: false,
              trackerInfos: const [],
              filter: filter,
              onChanged: (value) {
                setState(() => filter = value);
              },
            );
          },
        ),
      ),
    );

    expect(find.byType(CommonChip), findsOneWidget);
    expect(find.text('curl'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(filter.isEmpty, isTrue);
    expect(find.byType(CommonChip), findsNothing);

    await tester.pumpWidget(
      TestApp(
        child: TrackerInfoFilterBar(
          visible: true,
          trackerInfos: const [],
          filter: filter,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No filter conditions'), findsOneWidget);
  });

  testWidgets('filter button remains actionable in both visual states', (
    tester,
  ) async {
    var presses = 0;

    Future<void> pumpButton({
      required bool visible,
      required TrackerInfoFilter filter,
    }) async {
      await tester.pumpWidget(
        TestApp(
          child: TrackerInfoFilterButton(
            visible: visible,
            filter: filter,
            onPressed: () => presses++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    }

    await pumpButton(visible: false, filter: const TrackerInfoFilter());
    await pumpButton(
      visible: false,
      filter: const TrackerInfoFilter(processes: {'curl'}),
    );
    await pumpButton(visible: true, filter: const TrackerInfoFilter());

    expect(presses, 3);
  });

  final sheetCases =
      <({TrackerInfoFilterType type, String menuLabel, String option})>[
        (
          type: TrackerInfoFilterType.process,
          menuLabel: 'Process',
          option: 'curl',
        ),
        (
          type: TrackerInfoFilterType.chain,
          menuLabel: 'Proxy chain',
          option: 'Proxy',
        ),
        (
          type: TrackerInfoFilterType.network,
          menuLabel: 'Network type',
          option: 'tcp',
        ),
        (
          type: TrackerInfoFilterType.rule,
          menuLabel: 'Rule',
          option: 'DOMAIN(example.com)',
        ),
      ];

  for (final sheetCase in sheetCases) {
    testWidgets('adds a ${sheetCase.type.name} filter from the sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var filter = const TrackerInfoFilter();
      final trackers = [
        _tracker(id: 'first'),
        _tracker(id: 'second'),
        _tracker(
          id: 'blank',
          process: ' ',
          network: '',
          chains: const [],
          rule: '',
          rulePayload: '',
        ),
      ];

      await tester.pumpWidget(
        TestApp(
          wrapInProviderScope: true,
          child: TrackerInfoFilterBar(
            visible: true,
            trackerInfos: trackers,
            filter: filter,
            onChanged: (value) => filter = value,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sheetCase.menuLabel));
      await tester.pumpAndSettle();

      expect(find.text(sheetCase.option), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text(sheetCase.option));
      await tester.pumpAndSettle();

      expect(filter.contains(sheetCase.type, sheetCase.option), isTrue);
      expect(find.text('No data'), findsOneWidget);
    });
  }
}

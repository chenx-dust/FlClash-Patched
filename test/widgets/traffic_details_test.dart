import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/views/dashboard/widgets/traffic_details.dart';
import 'package:fl_clash/views/dashboard/widgets/traffic_usage.dart';
import 'package:fl_clash/widgets/donut_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

class _Core extends Mock implements CoreHandlerInterface {}

const _sample = [
  NodeTraffic(name: 'Alpha', provider: 'One', up: 600, down: 100),
  NodeTraffic(name: 'Beta', provider: 'Two', down: 200),
  NodeTraffic(name: 'Boundary', down: 50),
  NodeTraffic(name: 'Small download', down: 40),
  NodeTraffic(name: 'Small upload', up: 10),
];

void main() {
  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'));
    await font.load();
  });

  testWidgets('opens on demand and groups shares at or below five percent', (
    tester,
  ) async {
    final core = _Core();
    when(() => core.getNodeTraffic()).thenAnswer((_) async => _sample);
    await _pumpCard(tester, core);
    verifyNever(() => core.getNodeTraffic());
    await tester.tap(find.byIcon(Symbols.info));
    await tester.pumpAndSettle();
    expect(_values(tester), [700, 200, 100]);
    expect(find.text('Boundary'), findsNothing);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('70.0%'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    verify(() => core.getNodeTraffic()).called(1);

    await tester.tap(_dialogText('Upload'));
    await tester.pumpAndSettle();
    expect(_values(tester), [600, 10]);
    expect(find.text('Beta'), findsNothing);
    await tester.tap(_dialogText('Download'));
    await tester.pumpAndSettle();
    expect(_values(tester), [200, 100, 50, 40]);
    expect(find.text('Boundary'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    clearInteractions(core);
    await tester.pump(const Duration(seconds: 3));
    verifyNever(() => core.getNodeTraffic());
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('polls while open and keeps the selected direction', (
    tester,
  ) async {
    final core = _Core();
    var nodes = _sample;
    when(() => core.getNodeTraffic()).thenAnswer((_) async => nodes);
    await _pumpCard(tester, core);
    await tester.tap(find.text('Traffic usage'));
    await tester.pumpAndSettle();
    await tester.tap(_dialogText('Upload'));
    await tester.pumpAndSettle();
    nodes = [const NodeTraffic(name: 'Replacement', up: 200, down: 300)];
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(_values(tester), [200]);
    expect(find.text('Replacement'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    verify(() => core.getNodeTraffic()).called(2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'zero direction and empty results do not create artificial slices',
    (tester) async {
      final core = _Core();
      var nodes = [const NodeTraffic(name: 'Download only', down: 100)];
      when(() => core.getNodeTraffic()).thenAnswer((_) async => nodes);
      await _pumpCard(tester, core);
      await tester.longPress(find.byType(TrafficUsage));
      await tester.pumpAndSettle();
      await tester.tap(_dialogText('Upload'));
      await tester.pumpAndSettle();
      expect(find.text('No data'), findsOneWidget);
      expect(_chart(), findsNothing);
      nodes = [];
      await tester.tap(_dialogText('Both'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('No data'), findsOneWidget);
      expect(_chart(), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('all shares at five percent collapse into Other', (tester) async {
    final core = _Core();
    when(() => core.getNodeTraffic()).thenAnswer(
      (_) async => [
        for (var i = 0; i < 20; i++) NodeTraffic(name: 'Node $i', up: 5),
      ],
    );
    await _pumpCard(tester, core);
    await tester.tap(find.byIcon(Symbols.info));
    await tester.pumpAndSettle();
    expect(_values(tester), [100]);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('100.0%'), findsOneWidget);
    expect(find.text('Node 0'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('loading failure retries and recovers', (tester) async {
    final core = _Core();
    final request = Completer<List<NodeTraffic>>();
    when(() => core.getNodeTraffic()).thenAnswer((_) => request.future);
    await _pumpCard(tester, core);
    await tester.tap(find.byIcon(Symbols.info));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TrafficDetails), findsOneWidget);
    expect(_chart(), findsNothing);
    request.completeError(StateError('unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to read traffic. Retrying…'), findsOneWidget);
    when(() => core.getNodeTraffic()).thenAnswer((_) async => _sample);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(_values(tester), [700, 200, 100]);
    expect(find.text('Unable to read traffic. Retrying…'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('background and dismissal discard pending reads', (tester) async {
    final core = _Core();
    final requests = <Completer<List<NodeTraffic>>>[];
    when(() => core.getNodeTraffic()).thenAnswer((_) {
      final request = Completer<List<NodeTraffic>>();
      requests.add(request);
      return request.future;
    });
    await _pumpCard(tester, core);
    await tester.tap(find.byIcon(Symbols.info));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    requests.first.complete(_sample);
    await tester.pump(const Duration(seconds: 3));
    expect(_chart(), findsNothing);
    expect(requests, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(requests, hasLength(2));
    await tester.tap(find.text('Confirm'));
    await tester.pump(const Duration(milliseconds: 500));
    requests.last.complete(_sample);
    await tester.pumpAndSettle();
    expect(find.byType(TrafficDetails), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [320.0, 800.0]) {
    testWidgets('long names and many slices scroll at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final core = _Core();
      when(() => core.getNodeTraffic()).thenAnswer(
        (_) async => [
          for (var i = 0; i < 19; i++)
            NodeTraffic(
              name: 'A very long node name that must not overflow $i',
              provider: 'Provider $i',
              up: 1024,
            ),
        ],
      );
      await _pumpCard(tester, core, width: width, textScale: 1.5);
      await tester.tap(find.byIcon(Symbols.info));
      await tester.pumpAndSettle();
      expect(_values(tester), hasLength(19));
      expect(find.text('Other'), findsNothing);
      await tester.ensureVisible(find.text('Provider 9'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _pumpCard(
  WidgetTester tester,
  CoreHandlerInterface core, {
  double width = 800,
  double textScale = 1,
}) async {
  final container = ProviderContainer(
    overrides: [
      coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
    ],
  );
  addTearDown(container.dispose);
  container.read(viewSizeProvider.notifier).value = Size(width, 800);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TestApp(
        homeBuilder: (child) => Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 240, child: child),
          ),
        ),
        child: const TrafficUsage(),
      ),
    ),
  );
  await tester.pump();
}

Finder _chart() => find.descendant(
  of: find.byType(TrafficDetails),
  matching: find.byType(DonutChart),
);

Iterable<double> _values(WidgetTester tester) =>
    tester.widget<DonutChart>(_chart()).data.map((item) => item.value);

Finder _dialogText(String text) =>
    find.descendant(of: find.byType(TrafficDetails), matching: find.text(text));

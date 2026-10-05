import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/views/dashboard/widgets/memory_info.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:fl_clash/widgets/donut_chart.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'));
    await font.load();
  });

  const sample = CoreMemoryInfo(
    sys: 4096,
    heapObjects: 1024,
    heapUnused: 256,
    heapIdle: 128,
    heapReleased: 2048,
    stacks: 256,
    metadata: 128,
    gc: 128,
    other: 128,
  );

  testWidgets('cleanup triggers GC once and immediately refreshes memory', (
    tester,
  ) async {
    final core = _MockCoreHandlerInterface();
    final gc = Completer<bool>();
    when(() => core.getMemory()).thenAnswer((_) async => sample);
    when(() => core.forceGc()).thenAnswer((_) => gc.future);
    final container = _containerWith(core, CoreStatus.connected);
    addTearDown(container.dispose);
    container.read(viewSizeProvider.notifier).value = const Size(800, 600);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(homeBuilder: _scaffoldBody, child: MemoryInfo()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Symbols.info));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('Clean up')).dx,
      lessThan(tester.getCenter(find.text('Confirm')).dx),
    );
    verify(() => core.getMemory()).called(1);
    await tester.tap(find.text('Clean up'));
    await tester.pump();
    final button = find.widgetWithText(TextButton, 'Clean up');
    expect(tester.widget<TextButton>(button).onPressed, isNull);
    await tester.tap(button);
    verify(() => core.forceGc()).called(1);
    gc.complete(true);
    await tester.pump();
    await tester.pump();
    verify(() => core.getMemory()).called(1);
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    expect(find.byType(CommonDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final closeBeforeCompletion in [false, true]) {
    testWidgets(
      'cleanup handles ${closeBeforeCompletion ? 'dismissal' : 'failure'} during GC',
      (tester) async {
        final core = _MockCoreHandlerInterface();
        final gc = Completer<bool>();
        when(() => core.getMemory()).thenAnswer((_) async => sample);
        when(() => core.forceGc()).thenAnswer((_) => gc.future);
        final container = _containerWith(core, CoreStatus.connected);
        addTearDown(container.dispose);
        container.read(viewSizeProvider.notifier).value = const Size(800, 600);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const TestApp(
              homeBuilder: _scaffoldBody,
              child: MemoryInfo(),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.byIcon(Symbols.info));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clean up'));
        await tester.pump();
        if (closeBeforeCompletion) {
          await tester.tap(find.text('Confirm'));
          await tester.pumpAndSettle();
          gc.complete(true);
        } else {
          gc.completeError(StateError('GC unavailable'));
        }
        await tester.pump();
        await tester.pump();
        if (!closeBeforeCompletion) {
          expect(
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, 'Clean up'))
                .onPressed,
            isNotNull,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final width in [320.0, 800.0]) {
    testWidgets(
      'released memory visibility animates its ring and Sys label and survives polling at width $width',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        container.read(viewSizeProvider.notifier).value = Size(width, 800);
        var current = sample;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: TestApp(
              homeBuilder: _scaffoldBody,
              child: MemoryInfo(memoryReader: () async => current),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.byIcon(Symbols.info));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Hide'), findsOneWidget);
        expect(
          tester
              .widget<DonutChart>(find.byType(DonutChart))
              .data
              .where((item) => item.dashed),
          hasLength(1),
        );

        await tester.ensureVisible(find.byIcon(Symbols.visibility));
        await tester.tap(find.byIcon(Symbols.visibility));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final hiding = _memoryChartPainter(tester);
        expect(hiding.progress, inExclusiveRange(0, 1));
        final sysLabel = find.text(' / 4 KB');
        final sysWidth = tester
            .widget<Align>(
              find.ancestor(of: sysLabel, matching: find.byType(Align)).first,
            )
            .widthFactor;
        expect(sysWidth, inExclusiveRange(0, 1));
        expect(hiding.oldData.length, hiding.newData.length);
        expect(
          hiding.oldData.where((item) => item.dashed).single.value,
          sample.heapReleased,
        );
        expect(hiding.newData.where((item) => item.dashed).single.value, 0);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Show'), findsOneWidget);
        expect(
          tester
              .widget<Align>(
                find.ancestor(of: sysLabel, matching: find.byType(Align)).first,
              )
              .widthFactor,
          0,
        );
        final hidden = tester.widget<DonutChart>(find.byType(DonutChart));
        expect(hidden.data.where((item) => item.dashed).single.value, 0);
        expect(
          hidden.data.fold<double>(0, (sum, item) => sum + item.value),
          sample.total,
        );
        expect(find.text('Returned to OS'), findsOneWidget);
        expect(find.textContaining('50.0%'), findsOneWidget);
        expect(find.text('0.0%'), findsNothing);
        expect(find.text('25.0%'), findsNothing);

        current = sample.copyWith(sys: 5120, heapObjects: 2048);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        final refreshed = tester.widget<DonutChart>(find.byType(DonutChart));
        expect(refreshed.data.where((item) => item.dashed).single.value, 0);
        expect(
          refreshed.data.fold<double>(0, (sum, item) => sum + item.value),
          current.total,
        );
        expect(find.text('66.7%'), findsOneWidget);
        expect(find.text('0.0%'), findsNothing);

        await tester.ensureVisible(find.byIcon(Symbols.visibility_off));
        await tester.tap(find.byIcon(Symbols.visibility_off));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final showing = _memoryChartPainter(tester);
        expect(showing.progress, inExclusiveRange(0, 1));
        expect(showing.oldData.length, showing.newData.length);
        expect(showing.oldData.where((item) => item.dashed).single.value, 0);
        expect(
          showing.newData.where((item) => item.dashed).single.value,
          current.heapReleased,
        );
        await tester.pumpAndSettle();
        final visible = tester.widget<DonutChart>(find.byType(DonutChart));
        expect(
          visible.data.where((item) => item.dashed).single.value,
          current.heapReleased,
        );
        expect(
          visible.data.fold<double>(0, (sum, item) => sum + item.value),
          current.sys,
        );
        expect(find.byTooltip('Hide'), findsOneWidget);
        expect(find.text('40.0%'), findsNWidgets(2));
        expect(
          tester
              .widget<Align>(
                find
                    .ancestor(
                      of: find.text(' / 5 KB'),
                      matching: find.byType(Align),
                    )
                    .first,
              )
              .widthFactor,
          1,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('details use Sys shares and exclude released memory from usage', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(viewSizeProvider.notifier).value = const Size(800, 600);
    var current = sample;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          homeBuilder: _scaffoldBody,
          child: MemoryInfo(memoryReader: () async => current),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Symbols.info));
    await tester.pumpAndSettle();

    final chart = tester.widget<DonutChart>(find.byType(DonutChart));
    expect(chart.data.fold<double>(0, (sum, item) => sum + item.value), 4096);
    expect(chart.data.where((item) => item.dashed).single.value, 2048);
    expect(find.text('Go memory usage'), findsOneWidget);
    expect(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Go memory usage'),
              matching: find.byType(Column),
            )
            .first,
        matching: find.text('2 KB'),
      ),
      findsOneWidget,
    );
    final releasedRow = find
        .ancestor(
          of: find.text('Returned to OS'),
          matching: find.byType(Padding),
        )
        .first;
    expect(
      find.descendant(of: releasedRow, matching: find.text('2 KB')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: releasedRow, matching: find.text('50.0%')),
      findsOneWidget,
    );
    expect(find.textContaining('50.0%'), findsOneWidget);
    expect(find.textContaining('25.0%'), findsOneWidget);

    current = const CoreMemoryInfo();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final emptyChart = tester.widget<DonutChart>(find.byType(DonutChart));
    expect(emptyChart.data.every((item) => item.value == 0), isTrue);
    expect(find.textContaining('0.0%'), findsNWidgets(8));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('long press opens details and failed reads recover', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).value = const Size(800, 600);
    var fail = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          homeBuilder: _scaffoldBody,
          child: MemoryInfo(
            memoryReader: () async {
              if (fail) throw StateError('unavailable');
              return sample;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.longPress(find.byType(MemoryInfo));
    await tester.pumpAndSettle();
    expect(find.text('Unable to read memory. Retrying…'), findsOneWidget);
    fail = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(DonutChart), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('MemoryInfo refreshes only while the app is resumed', (
    tester,
  ) async {
    var readCount = 0;

    Future<CoreMemoryInfo> readMemory() async {
      readCount++;
      return CoreMemoryInfo(sys: readCount);
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        child: MemoryInfo(memoryReader: readMemory),
        homeBuilder: (child) => Scaffold(body: child),
      ),
    );
    await tester.pump();

    expect(readCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(readCount, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(readCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));

    expect(readCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(readCount, 3);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('MemoryInfo ignores a request completed in the background', (
    tester,
  ) async {
    final requests = <Completer<CoreMemoryInfo>>[];

    Future<CoreMemoryInfo> readMemory() {
      final request = Completer<CoreMemoryInfo>();
      requests.add(request);
      return request.future;
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        child: MemoryInfo(memoryReader: readMemory),
        homeBuilder: (child) => Scaffold(body: child),
      ),
    );
    await tester.pump();

    expect(requests, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    requests.first.complete(const CoreMemoryInfo(sys: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(requests, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(requests, hasLength(2));

    requests.last.complete(const CoreMemoryInfo(sys: 2));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('MemoryInfo keeps polling after a failed read', (tester) async {
    var readCount = 0;

    Future<CoreMemoryInfo> readMemory() async {
      readCount++;
      if (readCount == 1) {
        throw StateError('core unavailable');
      }
      return CoreMemoryInfo(sys: readCount);
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        child: MemoryInfo(memoryReader: readMemory),
        homeBuilder: (child) => Scaffold(body: child),
      ),
    );
    await tester.pump();

    expect(readCount, 1);
    expect(tester.takeException(), null);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(readCount, 2);
    expect(tester.takeException(), null);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('MemoryInfo refreshes only while the page is active', (
    tester,
  ) async {
    var readCount = 0;

    Future<CoreMemoryInfo> readMemory() async {
      readCount++;
      return CoreMemoryInfo(sys: readCount);
    }

    Widget buildApp({required bool isPageActive}) {
      return TestApp(
        wrapInProviderScope: true,
        child: PageActivityScope(
          isActive: isPageActive,
          child: MemoryInfo(memoryReader: readMemory),
        ),
        homeBuilder: (child) => Scaffold(body: child),
      );
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(buildApp(isPageActive: false));
    await tester.pump(const Duration(seconds: 4));

    expect(readCount, 0);

    await tester.pumpWidget(buildApp(isPageActive: true));
    await tester.pump();

    expect(readCount, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(readCount, 2);

    await tester.pumpWidget(buildApp(isPageActive: false));
    await tester.pump(const Duration(seconds: 4));

    expect(readCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the default reader reads Core memory while connected', (
    tester,
  ) async {
    final coreInterface = _MockCoreHandlerInterface();
    when(
      () => coreInterface.getMemory(),
    ).thenAnswer((_) async => const CoreMemoryInfo(sys: 4096));
    final container = _containerWith(coreInterface, CoreStatus.connected);
    addTearDown(container.dispose);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(homeBuilder: _scaffoldBody, child: MemoryInfo()),
      ),
    );
    await tester.pump();
    await tester.pump();

    verify(() => coreInterface.getMemory()).called(greaterThanOrEqualTo(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the default reader still reports Core memory while disconnected',
    (tester) async {
      final coreInterface = _MockCoreHandlerInterface();
      when(
        () => coreInterface.getMemory(),
      ).thenAnswer((_) async => const CoreMemoryInfo(sys: 4096));
      final container = _containerWith(coreInterface, CoreStatus.disconnected);
      addTearDown(container.dispose);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(homeBuilder: _scaffoldBody, child: MemoryInfo()),
        ),
      );
      await tester.pump();
      await tester.pump();

      verify(() => coreInterface.getMemory()).called(greaterThanOrEqualTo(1));

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a remounted card never reuses a disposed notifier', (
    tester,
  ) async {
    var readCount = 0;

    Future<CoreMemoryInfo> readMemory() async {
      readCount++;
      return CoreMemoryInfo(sys: readCount);
    }

    Widget app() => TestApp(
      wrapInProviderScope: true,
      homeBuilder: _scaffoldBody,
      child: MemoryInfo(memoryReader: readMemory),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(app());
    await tester.pump();

    expect(readCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(readCount, greaterThan(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _scaffoldBody(Widget child) => Scaffold(body: child);

ProviderContainer _containerWith(
  CoreHandlerInterface coreInterface,
  CoreStatus status,
) {
  final container = ProviderContainer(
    overrides: [
      coreHandlerProvider.overrideWithValue(
        CoreController.scoped(coreInterface),
      ),
    ],
  );
  container.read(coreStatusProvider.notifier).value = status;
  return container;
}

DonutChartPainter _memoryChartPainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<DonutChartPainter>()
      .single;
}

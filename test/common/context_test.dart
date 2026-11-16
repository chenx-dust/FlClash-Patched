import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/status_manager.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  testWidgets('showSnackBar replaces the current fixed snack bar', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    context.showSnackBar('first');
    await tester.pump();
    context.showSnackBar('second', persist: true);
    await tester.pump();

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.fixed);
    expect(snackBar.persist, isTrue);
  });

  testWidgets('showSnackBar keeps the deadline while the pointer is over it', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));

    context.showSnackBar(
      'hold',
      persist: false,
      action: SnackBarAction(label: 'Close', onPressed: () {}),
    );
    await _showSnackBar(tester);
    expect(find.text('Close'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));

    final gesture = await _hoverSnackBar(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('hold'), findsOneWidget);

    await gesture.moveTo(const Offset(400, 10));
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpAndSettle();
    expect(find.text('hold'), findsNothing);
  });

  testWidgets('showSnackBar finishes closing when the pointer returns', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));

    context.showSnackBar('hold');
    await _showSnackBar(tester);
    final gesture = await _hoverSnackBar(tester);
    await tester.pump(const Duration(seconds: 2));

    await gesture.moveTo(const Offset(400, 10));
    await gesture.moveTo(tester.getCenter(find.byType(SnackBar)));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpAndSettle();
    expect(find.text('hold'), findsNothing);
  });

  testWidgets('showSnackBar dismisses after the duration', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));

    context.showSnackBar('gone');
    await _showSnackBar(tester);
    await tester.pump(const Duration(seconds: 3));

    await tester.pumpAndSettle();
    expect(find.text('gone'), findsNothing);
  });

  testWidgets('showSnackBar keeps its duration with animations disabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));
    context.showSnackBar('readable');
    await _showSnackBar(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('readable'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('readable'), findsNothing);
  });

  testWidgets('showSnackBar with an action persists by default', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));
    var pressed = false;
    context.showSnackBar(
      'action',
      action: SnackBarAction(label: 'Close', onPressed: () => pressed = true),
    );
    await _showSnackBar(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('action'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
    expect(find.text('action'), findsNothing);
  });

  testWidgets(
    'showSnackBar holds over the native action and keeps its layout',
    (tester) async {
      tester.view.physicalSize = const Size(480, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext context;
      await tester.pumpWidget(_snackBarApp((value) => context = value));
      const label = 'Close all connections';
      var pressed = false;
      context.showSnackBar(
        'hold',
        persist: false,
        action: SnackBarAction(label: label, onPressed: () => pressed = true),
      );
      await _showSnackBar(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text(label)).dy,
        greaterThan(tester.getBottomLeft(find.text('hold')).dy),
      );
      final gesture = await _hoverSnackBar(tester);
      await gesture.moveTo(tester.getCenter(find.text(label)));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('hold'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
      expect(find.text('hold'), findsNothing);
    },
  );

  testWidgets('replacing a timed snack bar cancels its deadline', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));
    context.showSnackBar('old');
    await _showSnackBar(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    context.showSnackBar('persistent', persist: true);
    await _showSnackBar(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('old'), findsNothing);
    expect(find.text('persistent'), findsOneWidget);
  });

  testWidgets('disposing a timed snack bar cancels its deadline', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(_snackBarApp((value) => context = value));
    context.showSnackBar('gone');
    await _showSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'two sibling Scaffolds under one ScaffoldMessenger share timed hover deadline',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              Expanded(
                child: Scaffold(
                  body: Builder(
                    builder: (value) {
                      context = value;
                      return const SizedBox();
                    },
                  ),
                ),
              ),
              const Expanded(child: Scaffold(body: SizedBox())),
            ],
          ),
        ),
      );

      context.showSnackBar('shared');
      await _showSnackBar(tester);
      expect(find.text('shared'), findsNWidgets(2));

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: 0,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(SnackBar).first));

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('shared'), findsNWidgets(2));

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.text('shared'), findsNothing);
    },
  );

  testWidgets('kept-alive CommonScaffolds show snack bar only on active page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext inactiveContext;
    await tester.pumpWidget(
      _statusManagedApp(
        home: Stack(
          children: [
            PageActivityScope(
              isActive: false,
              child: CommonScaffold(
                title: 'First',
                body: Builder(
                  builder: (value) {
                    inactiveContext = value;
                    return const Text('body-1');
                  },
                ),
              ),
            ),
            const PageActivityScope(
              isActive: true,
              child: CommonScaffold(title: 'Second', body: Text('body-2')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    inactiveContext.showSnackBar('active-only', persist: true);
    await _showSnackBar(tester);
    expect(find.text('active-only'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(CommonScaffold, 'Second'),
        matching: find.text('active-only'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(CommonScaffold, 'First'),
        matching: find.text('active-only'),
      ),
      findsNothing,
    );

    globalState.navigatorKey.currentContext!.showSnackBar('from-root');
    await _showSnackBar(tester);
    expect(find.text('from-root'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(CommonScaffold, 'Second'),
        matching: find.text('from-root'),
      ),
      findsOneWidget,
    );

    final gesture = await _hoverSnackBar(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('from-root'), findsOneWidget);

    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('from-root'), findsNothing);
  });

  testWidgets(
    'side sheet CommonScaffold owns snack bar and clears covered page snack bar',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late BuildContext pageContext;
      late BuildContext sheetContext;
      await tester.pumpWidget(
        _statusManagedApp(
          overrides: [isMobileViewProvider.overrideWithValue(false)],
          home: CommonScaffold(
            title: 'Main',
            body: Builder(
              builder: (value) {
                pageContext = value;
                return const Text('main-body');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      pageContext.showSnackBar('on-main', persist: true);
      await _showSnackBar(tester);
      expect(find.text('on-main'), findsOneWidget);

      unawaited(
        showExtend<void>(
          pageContext,
          builder: (_) => CommonScaffold(
            title: 'Sheet',
            body: Builder(
              builder: (value) {
                sheetContext = value;
                return const Text('sheet-body');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('on-main'), findsNothing);

      sheetContext.showSnackBar('on-sheet', persist: true);
      await _showSnackBar(tester);
      expect(find.text('on-sheet'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(CommonScaffold, 'Sheet'),
          matching: find.text('on-sheet'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(CommonScaffold, 'Main'),
          matching: find.text('on-sheet'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'bottom sheet without CommonScaffold falls back to StatusManager pass-through overlay',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late BuildContext pageContext;
      var sheetButtonTapped = false;
      var actionPressed = false;
      await tester.pumpWidget(
        _statusManagedApp(
          overrides: [isMobileViewProvider.overrideWithValue(true)],
          home: CommonScaffold(
            title: 'Main',
            body: Builder(
              builder: (value) {
                pageContext = value;
                return const Text('main-body');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(
        showSheet<void>(
          context: pageContext,
          builder: (_) => SizedBox(
            height: 260,
            child: Center(
              child: TextButton(
                onPressed: () => sheetButtonTapped = true,
                child: const Text('Sheet Button'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      globalState.navigatorKey.currentContext!.showSnackBar(
        'above-sheet',
        persist: true,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => actionPressed = true,
        ),
      );
      await _showSnackBar(tester);

      expect(find.text('above-sheet'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CommonScaffold),
          matching: find.text('above-sheet'),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Sheet Button'));
      await tester.pump();
      expect(sheetButtonTapped, isTrue);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(actionPressed, isTrue);
      expect(find.text('above-sheet'), findsNothing);
    },
  );
}

Widget _statusManagedApp({
  required Widget home,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      navigatorKey: globalState.navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        globalState.measure = Measure.of(context, 1);
        globalState.theme = CommonTheme.of(context, 1);
        // ignore: deprecated_member_use
        return MaterialUiCompatibilityBridge(
          child: IconTheme(
            data: Theme.of(context).iconTheme,
            child: StatusManager(child: child!),
          ),
        );
      },
      home: home,
    ),
  );
}

Widget _snackBarApp(ValueChanged<BuildContext> onContext) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (value) {
          onContext(value);
          return const SizedBox();
        },
      ),
    ),
  );
}

Future<TestGesture> _hoverSnackBar(WidgetTester tester) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: 0,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(find.byType(SnackBar)));
  return gesture;
}

Future<void> _showSnackBar(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

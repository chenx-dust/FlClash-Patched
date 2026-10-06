import 'dart:async';

import 'package:fl_clash/application.dart';
import 'package:fl_clash/common/navigator.dart';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final initialWidth in [1000.0, 400.0]) {
    testWidgets('routes survive resizing from width $initialWidth', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(initialWidth, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(_buildHome(Size(initialWidth, 800)));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Symbols.construction));
        await tester.pumpAndSettle();

        final context = tester.element(find.text('page-tools'));
        final container = ProviderScope.containerOf(context);
        final navigator = Navigator.of(context);
        var completed = false;
        unawaited(
          navigator
              .push<void>(
                CommonRoute(builder: (_) => const Scaffold(body: TextField())),
              )
              .then((_) => completed = true),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'unsaved draft');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final fieldState = tester.state(find.byType(TextField));
        unawaited(
          navigator.push<void>(
            CommonRoute(
              builder: (_) => const Scaffold(body: Text('second route')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final width in [
          initialWidth == 1000 ? 400.0 : 1000.0,
          initialWidth,
          400.0,
        ]) {
          tester.view.physicalSize = Size(width, 800);
          container.read(viewSizeProvider.notifier).value = Size(width, 800);
          await tester.pumpAndSettle();
          expect(find.text('second route'), findsOneWidget);
          expect(
            Navigator.of(tester.element(find.text('second route'))),
            same(navigator),
          );
          expect(completed, isFalse);
          if (width == 400) {
            expect(find.byType(NavigationBar).hitTestable(), findsNothing);
            expect(tester.getBottomRight(find.byType(Scaffold)).dy, 800);
          } else {
            expect(find.byType(NavigationRail).hitTestable(), findsOneWidget);
            expect(tester.getTopLeft(find.byType(Scaffold)).dx, greaterThan(0));
          }
          expect(tester.takeException(), isNull);
        }

        await navigator.maybePop();
        await tester.pumpAndSettle();
        expect(find.text('unsaved draft'), findsOneWidget);
        expect(tester.state(find.byType(TextField)), same(fieldState));
        expect(find.byType(NavigationBar).hitTestable(), findsNothing);
        final transitions = find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(FadeTransition),
        );
        final transitionElements = transitions.evaluate().toList();
        for (final width in [1000.0, 400.0]) {
          tester.view.physicalSize = Size(width, 800);
          container.read(viewSizeProvider.notifier).value = Size(width, 800);
          await tester.pumpAndSettle();
          expect(find.text('unsaved draft'), findsOneWidget);
          expect(tester.state(find.byType(TextField)), same(fieldState));
          expect(transitions.evaluate(), orderedEquals(transitionElements));
          expect(tester.takeException(), isNull);
        }
        await navigator.maybePop();
        await tester.pumpAndSettle();
        expect(find.text('page-tools'), findsOneWidget);
        expect(completed, isTrue);
        expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);

        unawaited(
          navigator.push<void>(
            CommonRoute(
              builder: (_) => const Scaffold(body: Text('new mobile route')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar).hitTestable(), findsNothing);
        expect(tester.getBottomRight(find.byType(Scaffold)).dy, 800);
        await navigator.maybePop();
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('back after shrinking respects the nested route pop guard', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHome(const Size(1000, 800)));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('page-dashboard'));
    final container = ProviderScope.containerOf(context);
    final navigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final decision = Completer<bool>();
    var popRequested = false;
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => CommonPopScope(
            onPop: (_) {
              popRequested = true;
              return decision.future;
            },
            child: const Scaffold(body: Text('unsaved route')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(viewSizeProvider.notifier).value = const Size(400, 800);
    await tester.pumpAndSettle();

    await rootNavigator.maybePop();
    await tester.pumpAndSettle();
    expect(popRequested, isTrue);
    expect(find.text('unsaved route'), findsOneWidget);
    decision.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('unsaved route'), findsOneWidget);
    expect(navigator.canPop(), isTrue);
    expect(container.read(currentPageLabelProvider), PageLabel.dashboard);
  });

  testWidgets('HomeNavigatorObserver pops immediate routes to root', (
    tester,
  ) async {
    final observer = HomeNavigatorObserver();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(_TestApp(observer, navigatorKey));
    _pushDetails(navigatorKey);
    _pushDetails(navigatorKey, label: 'details 2');
    await tester.pumpAndSettle();

    expect(await observer.popToRoot(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('root'), findsOneWidget);
    expect(find.text('details'), findsNothing);
    expect(find.text('details 2'), findsNothing);
  });

  testWidgets('HomeNavigatorObserver waits for async pop approval', (
    tester,
  ) async {
    final observer = HomeNavigatorObserver();
    final navigatorKey = GlobalKey<NavigatorState>();
    final decision = Completer<bool>();

    await tester.pumpWidget(_TestApp(observer, navigatorKey));
    _pushGuardedDetails(navigatorKey, decision.future);
    await tester.pumpAndSettle();

    var completed = false;
    final popFuture = observer.popToRoot().then((result) {
      completed = true;
      return result;
    });
    await tester.pump();

    expect(completed, isFalse);
    expect(find.text('guarded details'), findsOneWidget);

    decision.complete(true);
    await tester.pumpAndSettle();

    expect(await popFuture, isTrue);
    expect(find.text('root'), findsOneWidget);
    expect(find.text('guarded details'), findsNothing);
  });

  testWidgets('HomeNavigatorObserver stays put when async pop is rejected', (
    tester,
  ) async {
    final observer = HomeNavigatorObserver();
    final navigatorKey = GlobalKey<NavigatorState>();
    final decision = Completer<bool>();

    await tester.pumpWidget(_TestApp(observer, navigatorKey));
    _pushGuardedDetails(navigatorKey, decision.future);
    await tester.pumpAndSettle();

    final popFuture = observer.popToRoot();
    await tester.pump();
    decision.complete(false);
    await tester.pumpAndSettle();

    expect(await popFuture, isFalse);
    expect(find.text('guarded details'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isTrue);
  });

  testWidgets('HomeNavigatorObserver waits for a handler-managed async pop', (
    tester,
  ) async {
    final observer = HomeNavigatorObserver();
    final navigatorKey = GlobalKey<NavigatorState>();
    final save = Completer<void>();

    await tester.pumpWidget(_TestApp(observer, navigatorKey));
    _pushSavingDetails(navigatorKey, save.future);
    await tester.pumpAndSettle();

    var completed = false;
    final popFuture = observer.popToRoot().then((result) {
      completed = true;
      return result;
    });
    await tester.pump();

    expect(completed, isFalse);
    expect(find.text('saving details'), findsOneWidget);

    save.complete();
    await tester.pumpAndSettle();

    expect(await popFuture, isTrue);
    expect(find.text('root'), findsOneWidget);
    expect(find.text('saving details'), findsNothing);
  });

  testWidgets('mobile swipe updates the page and navigation indicator', (
    tester,
  ) async {
    await tester.pumpWidget(_buildMobileHome());

    final pageView = find.byType(PageView);
    expect(tester.widget<PageView>(pageView).scrollDirection, Axis.horizontal);
    final bar = find.byType(NavigationBar);
    final barElement = tester.element(bar);
    final barRect = tester.getRect(bar);
    final pageWidth = tester.getSize(pageView).width;
    final gesture = await tester.startGesture(tester.getCenter(pageView));
    await gesture.moveBy(Offset(-pageWidth * 0.4, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(bar, findsOneWidget);
    expect(tester.element(bar), same(barElement));
    expect(tester.getRect(bar), barRect);
    await gesture.moveBy(Offset(-pageWidth * 0.4, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomePage));
    final container = ProviderScope.containerOf(context);
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(container.read(currentPageLabelProvider), PageLabel.profiles);
    expect(navigationBar.selectedIndex, 1);
    expect(find.text('page-profiles'), findsOneWidget);
  });

  testWidgets('mobile navigation animation ignores intermediate pages', (
    tester,
  ) async {
    await tester.pumpWidget(_buildMobileHome());

    final bar = find.byType(NavigationBar);
    final barElement = tester.element(bar);
    final barRect = tester.getRect(bar);
    await tester.tap(find.byIcon(Symbols.construction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(bar, findsOneWidget);
    expect(tester.element(bar), same(barElement));
    expect(tester.getRect(bar), barRect);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomePage));
    final container = ProviderScope.containerOf(context);
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(container.read(currentPageLabelProvider), PageLabel.tools);
    expect(navigationBar.selectedIndex, 2);
    expect(find.text('page-tools'), findsOneWidget);
  });

  testWidgets('mobile swipe can be disabled in app settings', (tester) async {
    await tester.pumpWidget(_buildMobileHome());

    final context = tester.element(find.byType(HomePage));
    final container = ProviderScope.containerOf(context);
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(isSwipeToPage: false));
    await tester.pump();

    final pageView = find.byType(PageView);
    final pageWidth = tester.getSize(pageView).width;
    await tester.drag(pageView, Offset(-pageWidth * 0.8, 0));
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(container.read(currentPageLabelProvider), PageLabel.dashboard);
    expect(navigationBar.selectedIndex, 0);
    expect(find.text('page-dashboard'), findsOneWidget);
  });

  testWidgets('desktop navigation scrolls between pages vertically', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHome(const Size(1000, 800)));

    final pageView = tester.widget<PageView>(find.byType(PageView));

    expect(pageView.scrollDirection, Axis.vertical);
    expect(pageView.physics, isA<NeverScrollableScrollPhysics>());
  });
}

Widget _buildMobileHome() {
  return _buildHome(const Size(400, 800));
}

Widget _buildHome(Size viewSize) {
  final navigationItems = [
    _navigationItem(PageLabel.dashboard),
    _navigationItem(PageLabel.profiles),
    NavigationItem(
      icon: const Icon(Symbols.ballot),
      label: PageLabel.connections,
      modes: const [NavigationItemMode.desktop],
      builder: (_) => const Text('page-connections'),
    ),
    _navigationItem(PageLabel.tools),
  ];
  return ProviderScope(
    overrides: [
      viewSizeProvider.overrideWithBuild((_, _) => viewSize),
      navigationItemsStateProvider.overrideWith(
        (_) => NavigationItemsState(value: navigationItems),
      ),
    ],
    child: Consumer(
      builder: (_, ref, _) => MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: buildPageTransitionsTheme(
            predictiveBack: false,
            isMobile: ref.watch(isMobileViewProvider),
          ),
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        onGenerateRoute: (settings) => CommonRoute<void>(
          settings: settings,
          builder: (_) => const HomePage(),
        ),
      ),
    ),
  );
}

NavigationItem _navigationItem(PageLabel label) {
  return NavigationItem(
    icon: Icon(switch (label) {
      PageLabel.dashboard => Symbols.home,
      PageLabel.profiles => Symbols.folder,
      PageLabel.tools => Symbols.construction,
      _ => Symbols.circle,
    }),
    label: label,
    builder: (_) => Center(child: Text('page-${label.name}')),
  );
}

class _TestApp extends StatelessWidget {
  final HomeNavigatorObserver observer;
  final GlobalKey<NavigatorState> navigatorKey;

  const _TestApp(this.observer, this.navigatorKey);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: NotificationListener<CommonPopScopeAttemptNotification>(
        onNotification: observer.onPopScopeAttempt,
        child: Navigator(
          key: navigatorKey,
          observers: [observer],
          onGenerateRoute: (_) {
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('root')),
            );
          },
        ),
      ),
    );
  }
}

void _pushDetails(
  GlobalKey<NavigatorState> navigatorKey, {
  String label = 'details',
}) {
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => Scaffold(body: Text(label))),
  );
}

void _pushGuardedDetails(
  GlobalKey<NavigatorState> navigatorKey,
  Future<bool> decision,
) {
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => CommonPopScope(
        onPop: (_) => decision,
        child: const Scaffold(body: Text('guarded details')),
      ),
    ),
  );
}

void _pushSavingDetails(
  GlobalKey<NavigatorState> navigatorKey,
  Future<void> save,
) {
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => CommonPopScope(
        onPop: (context) async {
          await save;
          if (context.mounted) {
            Navigator.of(context).pop();
          }
          return false;
        },
        child: const Scaffold(body: Text('saving details')),
      ),
    ),
  );
}

import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    final pageWidth = tester.getSize(pageView).width;
    await tester.drag(pageView, Offset(-pageWidth * 0.8, 0));
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

    await tester.tap(find.text(PageLabel.tools.name));
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
}

Widget _buildMobileHome() {
  final navigationItems = [
    _navigationItem(PageLabel.dashboard),
    _navigationItem(PageLabel.profiles),
    _navigationItem(PageLabel.tools),
  ];
  return ProviderScope(
    overrides: [
      viewSizeProvider.overrideWithBuild((_, _) => const Size(400, 800)),
      currentNavigationItemsStateProvider.overrideWith(
        (_) => NavigationItemsState(value: navigationItems),
      ),
    ],
    child: const MaterialApp(home: HomePage()),
  );
}

NavigationItem _navigationItem(PageLabel label) {
  return NavigationItem(
    icon: Icon(switch (label) {
      PageLabel.dashboard => Icons.home,
      PageLabel.profiles => Icons.folder,
      PageLabel.tools => Icons.construction,
      _ => Icons.circle,
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

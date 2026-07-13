import 'dart:async';

import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:flutter/material.dart';
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

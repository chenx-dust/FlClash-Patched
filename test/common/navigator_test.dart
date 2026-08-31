import 'package:fl_clash/common/navigator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => BaseNavigator.push(
                context,
                const Scaffold(body: Text('pushed page')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('BaseNavigator.push', () {
    testWidgets('uses the app-themed material route', (tester) async {
      await pumpHost(tester);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('pushed page'), findsOneWidget);
      final route = ModalRoute.of(tester.element(find.text('pushed page')));
      expect(route, isA<CommonRoute<void>>());
    });

    testWidgets('pops back to the origin', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('pushed page'));
      Navigator.of(context).pop();
      await tester.pumpAndSettle();

      expect(find.text('pushed page'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('route configuration', () {
    test('CommonRoute can update the predictive-back pop result', () {
      final route = CommonRoute<int>(builder: (_) => const SizedBox());

      expect(route.currentResult, isNull);
      route.updateCurrentResult(7);
      expect(route.currentResult, 7);
    });
  });

  group('CommonPageTransition', () {
    Future<void> pumpTransitionHost(
      WidgetTester tester, {
      required PageTransitionsBuilder builder,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {TargetPlatform.android: builder},
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('second')),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('drives the slide and shadow transitions on push', (
      tester,
    ) async {
      await pumpTransitionHost(
        tester,
        builder: const CommonPageTransitionsBuilder(),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(CommonPageTransition), findsWidgets);
      expect(find.byType(DecoratedBoxTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
      expect(tester.takeException(), null);
    });

    testWidgets('reverses cleanly and disposes its curves', (tester) async {
      await pumpTransitionHost(
        tester,
        builder: const CommonPageTransitionsBuilder(),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.text('second'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();

      expect(find.text('second'), findsNothing);
      expect(tester.takeException(), null);
    });

    testWidgets('rebuilds its animations when the inputs change', (
      tester,
    ) async {
      final first = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      final second = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      final secondary = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(secondary.dispose);

      Widget build(Animation<double> primary, {required bool linear}) {
        return MaterialApp(
          home: Builder(
            builder: (context) => CommonPageTransition(
              context: context,
              primaryRouteAnimation: primary,
              secondaryRouteAnimation: secondary,
              linearTransition: linear,
              child: const Text('content'),
            ),
          ),
        );
      }

      await tester.pumpWidget(build(first, linear: false));
      expect(find.text('content'), findsOneWidget);

      await tester.pumpWidget(build(second, linear: false));
      await tester.pump();
      expect(find.text('content'), findsOneWidget);

      await tester.pumpWidget(build(second, linear: true));
      await tester.pump();
      expect(find.text('content'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), null);
    });

    testWidgets('delegatedTransition slides the outgoing route', (
      tester,
    ) async {
      final secondary = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(secondary.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) =>
                CommonPageTransition.delegatedTransition(
                  context,
                  const AlwaysStoppedAnimation<double>(0),
                  secondary,
                  false,
                  const Text('outgoing'),
                ) ??
                const SizedBox(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('outgoing'), findsOneWidget);
      expect(find.byType(SlideTransition), findsWidgets);

      secondary.value = 0.5;
      await tester.pump();
      expect(tester.takeException(), null);
    });
  });
}

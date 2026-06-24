import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CommonScaffold consumes escape while searching', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;

    var bubbledEscapeCount = 0;
    var searchValue = '';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                bubbledEscapeCount++;
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: CommonScaffold(
              title: 'Profiles',
              searchState: AppBarSearchState(
                onSearch: (value) {
                  searchValue = value;
                },
              ),
              body: const SizedBox(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'proxy');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Profiles'), findsOneWidget);
    expect(searchValue, '');
    expect(bubbledEscapeCount, 0);
  });

  testWidgets('CommonScaffold handles system back while searching', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;

    var searchValue = '';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: CommonScaffold(
            title: 'Profiles',
            searchState: AppBarSearchState(
              onSearch: (value) {
                searchValue = value;
              },
            ),
            body: const SizedBox(),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'proxy');
    await tester.pump();

    final handled = await SystemBackBlock.maybeHandleBack();
    await tester.pumpAndSettle();

    expect(handled, true);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Profiles'), findsOneWidget);
    expect(searchValue, '');
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        globalState.theme = CommonTheme.of(context, 1);
        return child!;
      },
      home: child,
    );
  }
}

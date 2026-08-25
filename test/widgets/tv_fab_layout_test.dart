import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.delegate.supportedLocales,
    home: home,
  );
}

Widget _action() {
  return CommonFloatingActionButton(
    key: const ValueKey('action'),
    onPressed: () {},
    icon: const Icon(Icons.add),
    label: 'action',
  );
}

Widget _content() {
  return ListView(
    children: [
      for (var index = 0; index < 20; index++)
        SizedBox(
          height: 80,
          child: TextButton(
            key: ValueKey('item$index'),
            onPressed: () {},
            child: Text('item $index'),
          ),
        ),
    ],
  );
}

bool _isActionFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<FloatingActionButton>() != null;
}

void main() {
  testWidgets('non-TV CommonScaffold keeps the Scaffold FAB', (tester) async {
    await tester.pumpWidget(
      _app(
        CommonScaffold(
          title: 'page',
          isTV: false,
          floatingActionButton: _action(),
          body: _content(),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

    expect(scaffold.floatingActionButton, isNotNull);
  });

  testWidgets('CommonScaffold puts the TV FAB before search in the AppBar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CommonScaffold(
          title: 'page',
          isTV: true,
          searchState: AppBarSearchState(onSearch: (_) {}),
          floatingActionButton: _action(),
          body: _content(),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final action = find.byKey(const ValueKey('action'));
    final search = find.byIcon(Icons.search);

    expect(scaffold.floatingActionButton, isNull);
    expect(
      find.ancestor(of: action, matching: find.byType(AppBar)),
      findsOneWidget,
    );
    expect(tester.getCenter(action).dx, lessThan(tester.getCenter(search).dx));

    await tester.tap(search);
    await tester.pumpAndSettle();

    expect(action, findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('TV AppBar action is the first focus target in page content', (
    tester,
  ) async {
    final outsideFocus = FocusNode();
    addTearDown(outsideFocus.dispose);
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            Focus(focusNode: outsideFocus, child: const SizedBox()),
            Expanded(
              child: CommonScaffold(
                title: 'page',
                isTV: true,
                floatingActionButton: _action(),
                body: _content(),
              ),
            ),
          ],
        ),
      ),
    );
    outsideFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(_isActionFocused(), isTrue);
  });

  testWidgets('FloatLayout uses the same fixed top action layout on TV', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: FloatLayout(
            isTV: true,
            floatingWidget: _action(),
            child: _content(),
          ),
        ),
      ),
    );

    final action = find.byKey(const ValueKey('action'));
    final firstItem = find.byKey(const ValueKey('item0'));
    final initialActionTop = tester.getTopLeft(action).dy;

    expect(initialActionTop, lessThan(tester.getTopLeft(firstItem).dy));

    await tester.drag(firstItem, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(action).dy, initialActionTop);
  });
}

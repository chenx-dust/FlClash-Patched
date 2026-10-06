import 'package:fl_clash/widgets/proxy_chain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('collapses middle hops and preserves selection after expansion', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      TestApp(
        child: SizedBox(
          width: 240,
          child: ProxyChain(
            chain: const ['first', 'middle-a', 'middle-b', 'last'],
            onSelected: selected.add,
          ),
        ),
      ),
    );
    expect(find.text('first'), findsOneWidget);
    expect(find.text('last'), findsOneWidget);
    expect(find.text('middle-a'), findsNothing);
    await tester.tap(find.text('...'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.text('...'), findsNothing);
    expect(find.text('middle-a'), findsOneWidget);
    expect(find.text('middle-b'), findsOneWidget);
    await tester.tap(find.text('middle-a'));
    expect(selected, ['middle-a']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short chains stay visible and changed chains collapse again', (
    tester,
  ) async {
    Future<void> show(List<String> chain) =>
        tester.pumpWidget(TestApp(child: ProxyChain(chain: chain)));
    await show(['first', 'last']);
    expect(find.text('...'), findsNothing);
    await show(['first', 'middle', 'last']);
    await tester.tap(find.text('...'));
    await tester.pump();
    await show(['first', 'middle', 'last']);
    expect(find.text('middle'), findsOneWidget);
    await show(['first', 'new-middle', 'last']);
    expect(find.text('new-middle'), findsNothing);
    expect(find.text('...'), findsOneWidget);
  });
}

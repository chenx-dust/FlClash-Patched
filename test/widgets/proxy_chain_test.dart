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
    expect(find.text('first', findRichText: true), findsOneWidget);
    expect(find.text('last', findRichText: true), findsOneWidget);
    expect(find.text('middle-a', findRichText: true), findsNothing);
    await tester.tap(find.text('...', findRichText: true));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.text('...', findRichText: true), findsNothing);
    expect(find.text('middle-a', findRichText: true), findsOneWidget);
    expect(find.text('middle-b', findRichText: true), findsOneWidget);
    await tester.tap(find.text('middle-a', findRichText: true));
    expect(selected, ['middle-a']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short chains stay visible and changed chains collapse again', (
    tester,
  ) async {
    Future<void> show(List<String> chain) =>
        tester.pumpWidget(TestApp(child: ProxyChain(chain: chain)));
    await show(['first', 'last']);
    expect(find.text('...', findRichText: true), findsNothing);
    await show(['first', 'middle', 'last']);
    expect(find.text('middle', findRichText: true), findsOneWidget);
    expect(find.text('...', findRichText: true), findsNothing);
    await show(['first', 'middle', 'other-middle', 'last']);
    await tester.tap(find.text('...', findRichText: true));
    await tester.pump();
    await show(['first', 'middle', 'other-middle', 'last']);
    expect(find.text('middle', findRichText: true), findsOneWidget);
    await show(['first', 'new-middle', 'other-middle', 'last']);
    expect(find.text('new-middle', findRichText: true), findsNothing);
    expect(find.text('...', findRichText: true), findsOneWidget);
  });
}

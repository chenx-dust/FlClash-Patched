import 'dart:async';

import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/rules/query.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

const _result = RuleQuery(
  target: 'example.com',
  port: 53,
  network: Network.udp,
  mode: Mode.rule,
  rule: 'DomainSuffix',
  rulePayload: 'example.com',
  proxy: 'DIRECT',
  ip: '',
  delay: 0,
);

Future<void> _pumpDialog(
  WidgetTester tester,
  Future<RuleQuery> Function(RuleQueryParams) onQuery,
) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(viewSizeProvider.notifier).update((_) => const Size(800, 600));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TestApp(child: RuleQueryDialog(onQuery: onQuery)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('advanced metadata is collapsed and retained after folding', (
    tester,
  ) async {
    RuleQueryParams? submitted;
    await _pumpDialog(tester, (params) async {
      submitted = params;
      return _result;
    });
    expect(find.byKey(const ValueKey('sourceIP')), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'example.com');
    await tester.tap(find.text('Advanced configuration'));
    await tester.pumpAndSettle();
    for (final (key, value) in [
      ('sourceIP', '2001:db8::1'),
      ('sourcePort', '12345'),
      ('process', 'browser'),
      ('uid', '123'),
      ('dscp', '64'),
    ]) {
      final field = find.byKey(ValueKey(key));
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }
    await tester.ensureVisible(find.text('Advanced configuration'));
    await tester.tap(find.text('Advanced configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Query'));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
    expect(find.byKey(const ValueKey('dscp')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('dscp')));
    await tester.enterText(find.byKey(const ValueKey('dscp')), '63');
    await tester.ensureVisible(find.text('Advanced configuration'));
    await tester.tap(find.text('Advanced configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Query'));
    await tester.pumpAndSettle();
    expect(submitted?.sourceIP, '2001:db8::1');
    expect(submitted?.sourcePort, 12345);
    expect(submitted?.process, 'browser');
    expect(submitted?.uid, 123);
    expect(submitted?.dscp, 63);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates input and submits network and port once', (
    tester,
  ) async {
    final pending = Completer<RuleQuery>();
    final calls = <RuleQueryParams>[];
    await _pumpDialog(tester, (params) {
      calls.add(params);
      return pending.future;
    });
    await tester.tap(find.text('Query'));
    await tester.pump();
    expect(calls, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, ' example.com ');
    await tester.enterText(find.byType(TextFormField).last, '65536');
    await tester.tap(find.text('Query'));
    await tester.pump();
    expect(calls, isEmpty);
    await tester.enterText(find.byType(TextFormField).last, '53');
    await tester.tap(find.text('UDP'));
    await tester.tap(find.text('Query'));
    await tester.pump();
    expect(calls, [
      const RuleQueryParams(
        target: 'example.com',
        port: 53,
        network: Network.udp,
      ),
    ]);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
      false,
    );
    pending.complete(_result);
    await tester.pumpAndSettle();
    expect(find.text('DomainSuffix(example.com)'), findsNWidgets(2));
    expect(tester.widget<ProxyChain>(find.byType(ProxyChain)).chain, [
      'DIRECT',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('query failure permits retry', (tester) async {
    var calls = 0;
    await _pumpDialog(tester, (_) async {
      if (calls++ == 0) {
        throw const CoreMethodException(
          code: 'core_error',
          message: 'query failed',
        );
      }
      return _result;
    });
    await tester.enterText(find.byType(TextFormField).first, 'example.com');
    await tester.tap(find.text('Query'));
    await tester.pumpAndSettle();
    expect(find.textContaining('query failed'), findsOneWidget);
    await tester.tap(find.text('Query'));
    await tester.pumpAndSettle();
    expect(tester.widget<ProxyChain>(find.byType(ProxyChain)).chain, [
      'DIRECT',
    ]);
    expect(find.textContaining('query failed'), findsNothing);
  });

  testWidgets('completion after disposal does not update the dialog', (
    tester,
  ) async {
    final pending = Completer<RuleQuery>();
    await _pumpDialog(tester, (_) => pending.future);
    await tester.enterText(find.byType(TextFormField).first, 'example.com');
    await tester.tap(find.text('Query'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(_result);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

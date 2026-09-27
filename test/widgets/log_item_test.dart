import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/logs.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('LogItem shows the payload as plain text and toggles its level', (
    tester,
  ) async {
    final levels = <LogLevel>[];
    const payload =
        '[TCP] 10.0.0.2:40000 --> a.example:443 match '
        'DomainSuffix(example.com) using Proxy';
    await tester.pumpWidget(
      TestApp(
        homeBuilder: (child) => Scaffold(body: child),
        child: LogItem(
          onToggleLevel: levels.add,
          log: const Log(
            logLevel: LogLevel.error,
            source: LogSource.core,
            payload: payload,
            dateTime: '2026-09-27 20:00:00',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('20:00:00'), findsOneWidget);
    expect(find.text('CORE'), findsOneWidget);
    expect(find.text('ERROR'), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      payload,
    );
    final header = tester.getRect(find.byType(RecordHeader));
    expect(
      tester.getTopLeft(find.text('ERROR')).dy,
      lessThan(header.bottom + 1),
    );
    final decorated = tester.widget<DecoratedBox>(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration && decoration.border is Border;
      }),
    );
    final border = (decorated.decoration as BoxDecoration).border! as Border;
    expect(border.left.width, 3);

    await tester.tap(find.text('ERROR'));
    await tester.pump();
    expect(levels, [LogLevel.error]);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

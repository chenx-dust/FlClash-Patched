import 'package:fl_clash/views/dashboard/widgets/goroutine_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('GoroutineInfo displays and refreshes the count', (tester) async {
    var count = 2;

    Future<int> readCount() async => count;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => Scaffold(body: child),
        child: GoroutineInfo(countReader: readCount),
      ),
    );
    await tester.pump();

    expect(find.text('Goroutines'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('2')).dx,
      lessThan(tester.getRect(find.byType(OutlinedButton)).center.dx),
    );

    count = 5;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('5'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

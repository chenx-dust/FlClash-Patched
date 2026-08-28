import 'package:fl_clash/views/dashboard/widgets/connection_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('ConnectionInfo displays and refreshes the connection count', (
    tester,
  ) async {
    var count = 2;

    Future<int> readConnectionCount() async => count;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => Scaffold(body: child),
        child: ConnectionInfo(connectionCountReader: readConnectionCount),
      ),
    );
    await tester.pump();

    expect(find.text('Connection count'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    count = 5;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('5'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

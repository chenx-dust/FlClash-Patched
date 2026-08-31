import 'package:fl_clash/views/dashboard/widgets/connection_info.dart';
import 'package:fl_clash/widgets/inherited.dart';
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

  testWidgets('ConnectionInfo refreshes only while the page is active', (
    tester,
  ) async {
    var readCount = 0;

    Future<int> readConnectionCount() async => ++readCount;

    Widget buildApp({required bool isPageActive}) {
      return TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => Scaffold(body: child),
        child: PageActivityScope(
          isActive: isPageActive,
          child: ConnectionInfo(connectionCountReader: readConnectionCount),
        ),
      );
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(buildApp(isPageActive: false));
    await tester.pump(const Duration(seconds: 2));

    expect(readCount, 0);

    await tester.pumpWidget(buildApp(isPageActive: true));
    await tester.pump();

    expect(readCount, 1);

    await tester.pumpWidget(buildApp(isPageActive: false));
    await tester.pump(const Duration(seconds: 2));

    expect(readCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

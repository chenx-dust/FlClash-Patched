import 'package:code_forge/code_forge.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('shows the unavailable state when RustLib was not started', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        wrapInProviderScope: true,
        child: EditorPage(title: 'Editor', content: ''),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editor unavailable'), findsOneWidget);
    expect(find.byType(CodeForge), findsNothing);
  });
}

import 'package:code_forge/code_forge.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('editor app bar follows $brightness with an editable title', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          wrapInProviderScope: true,
          child: Theme(
            data: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: brightness,
              ),
            ),
            child: const EditorPage(
              title: 'Editor',
              content: '',
              titleEditable: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appBar = find.byType(AppBar);
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: appBar,
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(
        overlay.value.statusBarIconBrightness,
        brightness == Brightness.light ? Brightness.dark : Brightness.light,
      );
      final title = find.descendant(
        of: appBar,
        matching: find.byType(TextField),
      );
      await tester.enterText(title, 'Renamed');
      expect(find.text('Renamed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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

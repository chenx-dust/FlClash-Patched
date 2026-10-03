import 'package:code_forge/code_forge.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../plugins/code_forge/support.dart';

final _viewSizeOverride = viewSizeProvider.overrideWithBuild(
  (_, _) => const Size(1200, 1000),
);

void main() {
  setUpAll(initEditorNative);

  testWidgets('mounts after the route settles and tracks edits', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [_viewSizeOverride],
        child: const EditorPage(title: 'Editor', content: 'name: a'),
      ),
    );
    await tester.pumpAndSettle();

    final view = tester.state<EditorViewState>(find.byType(EditorView));
    expect(view.isModified, isFalse);

    tester.widget<CodeForge>(find.byType(CodeForge)).controller.text =
        'name: b';
    expect(view.isModified, isTrue);
  });

  testWidgets('right click keeps the menu open under the pointer', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [_viewSizeOverride],
        child: const EditorPage(title: 'Editor', content: 'name: a'),
      ),
    );
    await tester.pumpAndSettle();

    final editor = find.byType(CodeForge);
    final click = tester.getCenter(editor);
    await tester.tap(editor, buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Select all'), findsOneWidget);
    final item = tester.getTopLeft(find.text('Select all'));
    expect(item.dx, greaterThan(click.dx));
    expect(item.dx, lessThan(click.dx + 120));
    expect(item.dy, greaterThan(click.dy));
  });
}

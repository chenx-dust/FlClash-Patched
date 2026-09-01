import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import '../helpers/test_app.dart';

final _viewSizeOverride = viewSizeProvider.overrideWithBuild(
  (_, _) => const Size(1200, 1000),
);

void main() {
  testWidgets('allows predictive pop while guarded content is unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [_viewSizeOverride],
        child: const EditorPage(title: 'Editor', content: ''),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<CommonPopScope>(find.byType(CommonPopScope)).canPop,
      isTrue,
    );

    await tester.pumpWidget(
      TestApp(
        overrides: [_viewSizeOverride],
        child: EditorPage(
          title: 'Editor',
          content: '',
          onPop: (context, title, content) async => true,
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<CommonPopScope>(find.byType(CommonPopScope)).canPop,
      isTrue,
    );

    final controller = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    controller.text = 'changed';
    await tester.pump();

    expect(
      tester.widget<CommonPopScope>(find.byType(CommonPopScope)).canPop,
      isFalse,
    );

    controller.text = '';
    await tester.pump();

    expect(
      tester.widget<CommonPopScope>(find.byType(CommonPopScope)).canPop,
      isTrue,
    );
  });

  testWidgets('import from URL shows a translated network error message', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [_viewSizeOverride],
        child: const EditorPage(
          title: 'Editor',
          content: '',
          onSave: _noopSave,
          supportRemoteDownload: true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('External fetch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from URL'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField),
      'http://127.0.0.1/anything',
    );
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // flutter_test's mocked HttpClient answers with HTTP 400, which maps to
    // the localized network exception message in the snackbar.
    expect(
      find.text('Network error, please check your connection and try again'),
      findsOneWidget,
    );
  });
}

void _noopSave(BuildContext context, String title, String content) {}

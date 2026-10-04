import 'package:code_forge/code_forge.dart';
import 'package:fl_clash/common/navigator.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/popup.dart';
import 'package:flutter/gestures.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../plugins/code_forge/support.dart';

final _viewSizeOverride = viewSizeProvider.overrideWithBuild(
  (_, _) => const Size(1200, 1000),
);

void main() {
  setUpAll(initEditorNative);

  Future<CommonRoute<void>> pushEditor(
    WidgetTester tester,
    EditorPage page,
  ) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [_viewSizeOverride],
        child: const Scaffold(body: Text('origin')),
      ),
    );
    final context = tester.element(find.text('origin'));
    final route = CommonRoute<void>(builder: (_) => page);
    Navigator.of(context).push(route);
    await settle(tester, 12);
    return route;
  }

  Future<void> swipeBack(WidgetTester tester) async {
    await tester.dragFrom(const Offset(1, 200), const Offset(600, 0));
    await settle(tester, 12);
  }

  testWidgets('iOS swipe returns from an unmodified editor', (tester) async {
    var popCalls = 0;
    final route = await pushEditor(
      tester,
      EditorPage(
        title: 'Editor',
        content: 'name: a',
        onSave: (_, _, _) {},
        onPop: (_, _, _) async {
          popCalls++;
          return false;
        },
      ),
    );

    expect(route.popGestureEnabled, isTrue);
    await swipeBack(tester);

    expect(find.byType(EditorPage), findsNothing);
    expect(find.text('origin'), findsOneWidget);
    expect(popCalls, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS swipe returns from a read-only editor', (tester) async {
    final route = await pushEditor(
      tester,
      const EditorPage(title: 'Editor', content: 'name: a'),
    );

    expect(route.popGestureEnabled, isTrue);
    await swipeBack(tester);

    expect(find.byType(EditorPage), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('dirty edits require confirmation and undo restores iOS swipe', (
    tester,
  ) async {
    var popCalls = 0;
    final route = await pushEditor(
      tester,
      EditorPage(
        title: 'Editor',
        content: 'name: a',
        onSave: (_, _, _) {},
        onPop: (_, title, content) async {
          popCalls++;
          expect(title, 'Editor');
          expect(content, 'name: b');
          return false;
        },
      ),
    );
    final controller = tester
        .widget<CodeForge>(find.byType(CodeForge))
        .controller;
    controller.replaceRange(6, 7, 'b');
    await tester.pump();

    expect(route.popGestureEnabled, isFalse);
    await Navigator.of(tester.element(find.byType(EditorPage))).maybePop();
    await tester.pump();
    expect(popCalls, 1);
    expect(find.byType(EditorPage), findsOneWidget);

    tester.widget<CodeForge>(find.byType(CodeForge)).undoController!.undo();
    await tester.pump();
    expect(controller.text, 'name: a');
    expect(route.popGestureEnabled, isTrue);
    await swipeBack(tester);
    expect(find.byType(EditorPage), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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

  Future<CodeForgeController> openMobileMenu(
    WidgetTester tester, {
    bool dirty = false,
    Future<bool> Function(BuildContext, String, String)? onPop,
  }) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [_viewSizeOverride],
        child: EditorPage(
          title: 'Editor',
          content: 'name: a\nname: b',
          onSave: (_, _, _) {},
          onPop: onPop,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = find.byType(CodeForge);
    final code = tester.widget<CodeForge>(editor);
    if (dirty) code.controller.replaceRange(6, 7, 'c');
    code.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    code.onContextMenu(
      tester.element(editor),
      CodeForgeContextMenuRequest(
        isMobile: true,
        globalPosition: tester.getCenter(editor),
        hasSelection: true,
        isAllSelected: false,
        readOnly: true,
        copy: () {},
        cut: () {},
        paste: () {},
        selectAll: code.controller.selectAll,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CommonPopupMenu), findsOneWidget);
    return code.controller;
  }

  testWidgets(
    'mobile selection changes close the menu without interrupting listeners',
    (tester) async {
      final controller = await openMobileMenu(tester);
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CommonPopupMenu), findsNothing);
      expect(find.byType(EditorPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back closes the mobile menu before leaving the editor', (
    tester,
  ) async {
    await openMobileMenu(tester);
    final navigator = Navigator.of(tester.element(find.byType(EditorPage)));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(CommonPopupMenu), findsNothing);
    expect(find.byType(EditorPage), findsOneWidget);
  });

  testWidgets('disposing the editor removes the mobile menu', (tester) async {
    await openMobileMenu(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(find.byType(CommonPopupMenu), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back closes a mobile menu before dirty edit confirmation', (
    tester,
  ) async {
    var confirmations = 0;
    await openMobileMenu(
      tester,
      dirty: true,
      onPop: (_, _, _) async {
        confirmations++;
        return false;
      },
    );
    final navigator = Navigator.of(tester.element(find.byType(EditorPage)));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(CommonPopupMenu), findsNothing);
    expect(confirmations, 0);
    await navigator.maybePop();
    await tester.pump();
    expect(confirmations, 1);
    expect(find.byType(EditorPage), findsOneWidget);
  });

  testWidgets('the search button toggles the find panel', (tester) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [_viewSizeOverride],
        child: const EditorPage(title: 'Editor', content: 'name: a'),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.widgetWithIcon(IconButton, Symbols.search);
    expect(find.byType(FindPanel), findsNothing);
    expect(tester.widget<IconButton>(search).onPressed, isNotNull);

    OutlinedBorder? searchShape() {
      final material = tester.widget<Material>(
        find.descendant(of: search, matching: find.byType(Material)),
      );
      final shape = material.shape;
      return shape is OutlinedBorder ? shape : null;
    }

    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.byType(FindPanel), findsOneWidget);
    expect(find.byTooltip('Close'), findsNothing);
    expect(searchShape()?.side.width ?? 0, 0);
    expect(
      tester
          .widget<Material>(
            find.descendant(of: search, matching: find.byType(Material)),
          )
          .color,
      Theme.of(tester.element(search)).colorScheme.secondaryContainer,
    );

    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.byType(FindPanel), findsNothing);
    expect(searchShape()?.side.width ?? 0, 0);
  });

  testWidgets('find panel height follows its content', (tester) async {
    final code = CodeForgeController()..text = 'name: a';
    final finder = FindController(code);
    addTearDown(finder.dispose);
    addTearDown(code.dispose);

    Future<void> pumpPanel({required bool mobile}) {
      return tester.pumpWidget(
        TestApp(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ListenableBuilder(
                listenable: finder,
                builder: (context, _) => FindPanel(
                  controller: finder,
                  readOnly: false,
                  isMobileView: mobile,
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pumpPanel(mobile: false);
    await tester.pumpAndSettle();
    final searchHeight = tester.getSize(find.byType(FindPanel)).height;
    final fieldHeight = tester.getSize(find.byType(TextField)).height;

    finder.toggleReplaceMode();
    await tester.pumpAndSettle();
    final replaceHeight = tester.getSize(find.byType(FindPanel)).height;

    await pumpPanel(mobile: true);
    await tester.pumpAndSettle();
    final mobileHeight = tester.getSize(find.byType(FindPanel)).height;

    expect(searchHeight, closeTo(fieldHeight + 12, 1));
    expect(replaceHeight - searchHeight, closeTo(fieldHeight + 12, 1));
    expect(mobileHeight, greaterThan(replaceHeight));
  });
}

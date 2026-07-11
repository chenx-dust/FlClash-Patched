import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the page focus structure in lib/pages/home.dart: a
/// [PageTraversalPolicy] group hosting page content, so the FAB is first in the
/// tab order, tabbing past the page reaches the
/// sidebar/bottom navigation, and directional edges reach the FAB or the
/// enclosing scope.
Widget _buildPage({bool wrapNavigator = false}) {
  final page = Scaffold(
    body: Column(
      children: [
        for (var i = 0; i < 10; i++)
          TextButton(
            key: ValueKey('item$i'),
            onPressed: () {},
            child: Text('item $i'),
          ),
      ],
    ),
    floatingActionButton: CommonFloatingActionButton(
      onPressed: () {},
      icon: const Icon(Icons.add),
      label: 'add',
    ),
  );
  final scopedPage = PageFocusScope(child: page);
  return FocusTraversalGroup(
    policy: PageTraversalPolicy(),
    child: wrapNavigator
        ? Navigator(
            pages: [MaterialPage(child: scopedPage)],
            onDidRemovePage: (_) {},
          )
        : scopedPage,
  );
}

Future<FocusNode> pumpWithOutsideFocus(
  WidgetTester tester,
  Widget child,
) async {
  final outsideFocus = FocusNode();
  addTearDown(outsideFocus.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Column(
        children: [
          Focus(focusNode: outsideFocus, child: const SizedBox()),
          Expanded(child: child),
        ],
      ),
    ),
  );
  await tester.pump();
  outsideFocus.requestFocus();
  await tester.pump();
  return outsideFocus;
}

bool _isFabFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<FloatingActionButton>() != null;
}

String? _focusedItemKey() {
  final context = FocusManager.instance.primaryFocus?.context;
  final button = context?.findAncestorWidgetOfExactType<TextButton>();
  final key = button?.key;
  if (key is! ValueKey<String>) {
    return null;
  }
  return key.value;
}

void main() {
  testWidgets('tabbing into a page focuses the FAB first', (tester) async {
    final outsideFocus = await pumpWithOutsideFocus(tester, _buildPage());
    expect(FocusManager.instance.primaryFocus, outsideFocus);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      _isFabFocused(),
      isTrue,
      reason:
          'the FAB should be the first focusable target in the page, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('tabbing into a desktop page navigator focuses the FAB first', (
    tester,
  ) async {
    final outsideFocus = await pumpWithOutsideFocus(
      tester,
      _buildPage(wrapNavigator: true),
    );
    expect(FocusManager.instance.primaryFocus, outsideFocus);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      _isFabFocused(),
      isTrue,
      reason:
          'the FAB should be the first focusable target inside the page '
          'navigator, actual: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('tabbing visits every page node in order without skipping', (
    tester,
  ) async {
    final outsideFocus = await pumpWithOutsideFocus(
      tester,
      _buildPage(wrapNavigator: true),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_isFabFocused(), isTrue, reason: 'first tab reaches the FAB');

    for (var i = 0; i < 10; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _focusedItemKey(),
        'item$i',
        reason:
            'tab ${i + 1} should reach item$i without skipping, '
            'actual: ${FocusManager.instance.primaryFocus}',
      );
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus,
      outsideFocus,
      reason:
          'tabbing past the last page node escapes to the enclosing scope, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('shift-tab from the FAB escapes the page navigator', (
    tester,
  ) async {
    final outsideFocus = await pumpWithOutsideFocus(
      tester,
      _buildPage(wrapNavigator: true),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_isFabFocused(), isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, outsideFocus);
  });

  testWidgets('pressing right at the page edge focuses the FAB', (
    tester,
  ) async {
    await pumpWithOutsideFocus(tester, _buildPage());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedItemKey(), 'item0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(
      _isFabFocused(),
      isTrue,
      reason:
          'right at the page edge should jump to the FAB, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('pressing down past the last row focuses the FAB', (
    tester,
  ) async {
    await pumpWithOutsideFocus(tester, _buildPage());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedItemKey(), 'item0');

    for (var i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(_focusedItemKey(), 'item9');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(
      _isFabFocused(),
      isTrue,
      reason:
          'down past the last row should reach the FAB, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('up/left at the page edge does not jump to the FAB', (
    tester,
  ) async {
    await pumpWithOutsideFocus(tester, _buildPage());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedItemKey(), 'item0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(_focusedItemKey(), 'item0');
  });

  testWidgets('arrow keys still navigate the page content normally', (
    tester,
  ) async {
    await pumpWithOutsideFocus(tester, _buildPage());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedItemKey(), 'item0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(
      _focusedItemKey(),
      'item1',
      reason:
          'down from an item should move to the item below, not the FAB, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('down past the content reaches the FAB, not the bottom bar', (
    tester,
  ) async {
    final page = Scaffold(
      body: Column(
        children: [
          for (var i = 0; i < 10; i++)
            TextButton(
              key: ValueKey('item$i'),
              onPressed: () {},
              child: Text('item $i'),
            ),
        ],
      ),
      floatingActionButton: CommonFloatingActionButton(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: 'add',
      ),
    );
    await pumpWithOutsideFocus(
      tester,
      Column(
        children: [
          Expanded(
            child: FocusTraversalGroup(
              policy: PageTraversalPolicy(),
              child: PageFocusScope(child: page),
            ),
          ),
          SizedBox(
            height: 80,
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('bottomBarButton'),
                  onPressed: () {},
                  icon: const Icon(Icons.home),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // 聚焦内容最后一项 item9
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    for (var i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(_focusedItemKey(), 'item9');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(
      _isFabFocused(),
      isTrue,
      reason:
          'down past the content should reach the FAB, not the bottom bar, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets(
    'down from the focused FAB keeps moving into the enclosing scope',
    (tester) async {
      final outsideFocus = await pumpWithOutsideFocus(
        tester,
        _buildPage(wrapNavigator: true),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_isFabFocused(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        _isFabFocused(),
        isFalse,
        reason:
            'down from the focused FAB should keep navigating out of the page, '
            'actual: ${FocusManager.instance.primaryFocus}',
      );
      expect(
        FocusManager.instance.primaryFocus,
        outsideFocus,
        reason: 'down from the FAB should escape to the enclosing scope',
      );
    },
  );

  testWidgets('left at the content edge jumps to the sidebar', (tester) async {
    final outsideFocus = await pumpWithOutsideFocus(
      tester,
      _buildPage(wrapNavigator: true),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedItemKey(), 'item0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus,
      outsideFocus,
      reason:
          'left at the content edge should escape to the enclosing scope, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('up at the content edge jumps to the sidebar', (tester) async {
    final outsideFocus = await pumpWithOutsideFocus(
      tester,
      _buildPage(wrapNavigator: true),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedItemKey(), 'item0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus,
      outsideFocus,
      reason:
          'up at the content edge should escape to the enclosing scope, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('down from the FAB reaches the bottom bar on mobile', (
    tester,
  ) async {
    final page = Scaffold(
      body: Column(
        children: [
          for (var i = 0; i < 10; i++)
            TextButton(
              key: ValueKey('item$i'),
              onPressed: () {},
              child: Text('item $i'),
            ),
        ],
      ),
      floatingActionButton: CommonFloatingActionButton(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: 'add',
      ),
    );
    await pumpWithOutsideFocus(
      tester,
      Column(
        children: [
          Expanded(
            child: FocusTraversalGroup(
              policy: PageTraversalPolicy(),
              child: PageFocusScope(child: page),
            ),
          ),
          SizedBox(
            height: 80,
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('bottomBarButton'),
                  onPressed: () {},
                  icon: const Icon(Icons.home),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Tab 进入页面 → FAB
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_isFabFocused(), isTrue);

    // FAB 按 down → 一次到底栏
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    final inBottomBar =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<IconButton>() !=
        null;
    expect(
      inBottomBar,
      isTrue,
      reason:
          'down from the FAB should reach the bottom bar in one press, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
  });
}

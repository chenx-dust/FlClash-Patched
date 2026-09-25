import 'dart:async';

import 'package:fl_clash/widgets/card.dart';
import 'package:fl_clash/widgets/grid.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:fl_clash/widgets/super_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

GridItem _item(String label, {int crossAxisCellCount = 2}) {
  return GridItem(
    crossAxisCellCount: crossAxisCellCount,
    mainAxisCellCount: 1,
    child: SizedBox(
      key: ValueKey(label),
      height: 100,
      child: ColoredBox(
        color: Colors.blue,
        child: Center(child: Text(label)),
      ),
    ),
  );
}

Element _deleteButtonStack(WidgetTester tester, Finder icon) {
  Element? stack;
  tester.element(icon).visitAncestorElements((element) {
    if (element.widget is Stack) {
      stack = element;
      return false;
    }
    return true;
  });
  return stack!;
}

Color deleteFill(WidgetTester tester, Finder icon) {
  final stack = _deleteButtonStack(tester, icon);
  late AnimatedContainer container;
  stack.visitChildElements((element) {
    element.visitChildElements((child) {
      if (child.widget is AnimatedContainer) {
        container = child.widget as AnimatedContainer;
      }
    });
  });
  return (container.decoration! as ShapeDecoration).color!;
}

Color paintedDeleteFill(WidgetTester tester, Finder icon) {
  final stack = _deleteButtonStack(tester, icon);
  late RenderDecoratedBox box;
  stack.visitChildElements((element) {
    element.visitChildElements((child) {
      if (child.widget is! AnimatedContainer) {
        return;
      }
      child.visitChildElements((decorated) {
        final render = decorated.renderObject;
        if (render is RenderDecoratedBox) {
          box = render;
        }
      });
    });
  });
  return (box.decoration as ShapeDecoration).color!;
}

void main() {
  testWidgets('SuperGrid adds and deletes items while reporting updates', (
    tester,
  ) async {
    final key = GlobalKey<SuperGridState>();
    var updates = 0;

    await tester.pumpWidget(
      TestApp(
        child: Scaffold(
          body: SingleChildScrollView(
            child: SuperGrid(
              key: key,
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              onUpdate: () => updates++,
              children: [_item('A'), _item('B'), _item('C')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(key.currentState!.length, 3);
    expect(find.byIcon(Icons.close), findsNWidgets(3));

    key.currentState!.handleAdd(_item('D', crossAxisCellCount: 4));
    await tester.pump();
    expect(key.currentState!.length, 4);
    expect(find.byKey(const ValueKey('D')), findsOneWidget);

    final deleteButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.close).at(1),
        matching: find.byType(IconButton),
      ),
    );
    final deleteButtonContext = tester.element(
      find.ancestor(
        of: find.byIcon(Icons.close).at(1),
        matching: find.byType(IconButton),
      ),
    );
    final colorScheme = Theme.of(deleteButtonContext).colorScheme;
    expect(
      deleteButton.style?.foregroundColor?.resolve({}),
      colorScheme.onPrimary,
    );
    expect(
      deleteButton.style?.foregroundColor?.resolve({WidgetState.hovered}),
      colorScheme.onError,
    );
    expect(
      deleteFill(tester, find.byIcon(Icons.close).at(1)),
      colorScheme.primary,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.byIcon(Icons.close).at(1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      paintedDeleteFill(tester, find.byIcon(Icons.close).at(1)),
      Color.lerp(colorScheme.primary, colorScheme.error, 0.5),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      paintedDeleteFill(tester, find.byIcon(Icons.close).at(1)),
      colorScheme.error,
    );
    await gesture.moveTo(Offset.zero);
    await gesture.removePointer();
    await tester.pump(const Duration(milliseconds: 200));
    deleteButton.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 421));
    await tester.pump();
    expect(key.currentState!.length, 3);
    expect(find.byKey(const ValueKey('B')), findsNothing);
    expect(updates, greaterThanOrEqualTo(2));
    expect(tester.takeException(), null);
  });

  testWidgets('SuperGrid handles a desktop drag and keeps items mounted', (
    tester,
  ) async {
    final key = GlobalKey<SuperGridState>();

    await tester.pumpWidget(
      TestApp(
        child: Scaffold(
          body: SingleChildScrollView(
            child: SuperGrid(
              key: key,
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [_item('A'), _item('B'), _item('C'), _item('D')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('A'))),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('D'))));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));

    expect(key.currentState!.length, 4);
    for (final label in ['A', 'B', 'C', 'D']) {
      expect(find.byKey(ValueKey(label)), findsOneWidget);
    }
    expect(tester.takeException(), null);
  });

  testWidgets('SuperGrid moves the dragged item into the hovered slot', (
    tester,
  ) async {
    final key = GlobalKey<SuperGridState>();

    await tester.pumpWidget(
      TestApp(
        child: Scaffold(
          body: SingleChildScrollView(
            child: SuperGrid(
              key: key,
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [_item('A'), _item('B'), _item('C'), _item('D')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    List<String> labels() => key.currentState!.snapshotChildren
        .map(
          (item) => ((item.child as SizedBox).key! as ValueKey).value as String,
        )
        .toList();

    expect(labels(), ['A', 'B', 'C', 'D']);

    final target = tester.getCenter(find.byKey(const ValueKey('D')));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('A'))),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    await gesture.moveTo(target);
    // Past the hover delay, so the grid opens a slot at D's position.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));

    expect(labels(), ['B', 'C', 'D', 'A']);
    expect(tester.takeException(), null);
  });

  testWidgets('SuperGrid completes a pending drop when disposed', (
    tester,
  ) async {
    final key = GlobalKey<SuperGridState>();

    await tester.pumpWidget(
      TestApp(
        child: Scaffold(
          body: SingleChildScrollView(
            child: SuperGrid(
              key: key,
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [_item('A'), _item('B'), _item('C'), _item('D')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('A'))),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('D'))));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump();

    final transformCompleted = key.currentState!.isTransformCompleter;
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(await transformCompleted, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), null);
  });

  testWidgets('edit mode keeps focus on the card instead of its action', (
    tester,
  ) async {
    final key = GlobalKey<SuperGridState>();
    var cardPresses = 0;

    await tester.pumpWidget(
      TestApp(
        child: Scaffold(
          body: SuperGrid(
            key: key,
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              GridItem(
                crossAxisCellCount: 2,
                mainAxisCellCount: 1,
                child: SizedBox(
                  height: 100,
                  child: CommonCard(
                    skipTraversal: true,
                    onPressed: () => cardPresses++,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('inner'),
                    ),
                  ),
                ),
              ),
              _item('B'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(IconButton).first), const Size(24, 24));
    var cardChildExcluded = false;
    var cornerExcluded = false;
    tester.element(find.text('inner')).visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is ExcludeFocus && widget.excluding) {
        cardChildExcluded = true;
        return false;
      }
      return true;
    });
    tester.element(find.byIcon(Icons.close).first).visitAncestorElements((
      element,
    ) {
      final widget = element.widget;
      if (widget is ExcludeFocus && widget.excluding) {
        cornerExcluded = true;
        return false;
      }
      return true;
    });
    expect(cardChildExcluded, isTrue);
    expect(cornerExcluded, isTrue);

    for (var i = 0; i < 8; i++) {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused?.findAncestorWidgetOfExactType<OutlinedButton>() != null) {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<OutlinedButton>(),
      isNotNull,
      reason: 'edit mode keeps focus on the card',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(cardPresses, 0);
    expect(key.currentState!.length, 2);
    expect(find.text('inner'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  List<String> labelsByX(WidgetTester tester, List<String> labels) {
    final entries = [
      for (final label in labels)
        (label, tester.getTopLeft(find.text(label)).dx),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final entry in entries) entry.$1];
  }

  double cardScale(WidgetTester tester, String label) {
    return tester
        .renderObject<RenderBox>(find.text(label))
        .getTransformTo(null)
        .getMaxScaleOnAxis();
  }

  double cardOpacity(WidgetTester tester, String label) {
    Opacity? opacity;
    tester.element(find.text(label)).visitAncestorElements((element) {
      if (element.widget is Opacity) {
        opacity = element.widget as Opacity;
        return false;
      }
      return true;
    });
    return opacity!.opacity;
  }

  Future<void> settleSlide(WidgetTester tester) {
    return tester.pump(const Duration(milliseconds: 420));
  }

  Future<void> focusCard(WidgetTester tester, String label) async {
    final button = tester.widget<OutlinedButton>(
      find
          .ancestor(of: find.text(label), matching: find.byType(OutlinedButton))
          .first,
    );
    for (var i = 0; i < 8; i++) {
      if (button.focusNode!.hasFocus) {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    expect(button.focusNode!.hasFocus, isTrue);
  }

  GridItem card(String label) {
    return GridItem(
      crossAxisCellCount: 2,
      mainAxisCellCount: 1,
      child: SizedBox(
        height: 80,
        child: CommonCard(onPressed: () {}, child: Text(label)),
      ),
    );
  }

  Future<GlobalKey<SuperGridState>> pumpEditableGrid(
    WidgetTester tester,
  ) async {
    final key = GlobalKey<SuperGridState>();

    await tester.pumpWidget(
      TestApp(
        child: Scaffold(
          body: BackLayerScope(
            onBack: () => key.currentState!.cancelHeldMove(),
            child: SuperGrid(
              key: key,
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [card('A'), card('B')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await focusCard(tester, 'A');
    return key;
  }

  testWidgets('edit mode releases a lifted card after a boundary move', (
    tester,
  ) async {
    final key = await pumpEditableGrid(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(key.currentState!.isHolding, isTrue, reason: 'enter holds the card');
    await tester.pump(const Duration(milliseconds: 100));
    expect(cardScale(tester, 'A') / cardScale(tester, 'B'), greaterThan(1.005));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      cardScale(tester, 'A') / cardScale(tester, 'B'),
      closeTo(1.03, 0.01),
    );
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(key.currentState!.isHolding, isTrue);
    expect(labelsByX(tester, ['A', 'B']), ['A', 'B']);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(key.currentState!.isHolding, isFalse);
    expect(key.currentState!.length, 2);
    await tester.pump(const Duration(milliseconds: 200));
    expect(cardScale(tester, 'A') / cardScale(tester, 'B'), closeTo(1, 0.01));
  });

  testWidgets('edit mode moves a held card and restores it on cancel', (
    tester,
  ) async {
    final key = await pumpEditableGrid(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await settleSlide(tester);

    expect(labelsByX(tester, ['A', 'B']), ['B', 'A']);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await settleSlide(tester);
    expect(key.currentState!.isHolding, isFalse);
    expect(labelsByX(tester, ['A', 'B']), ['A', 'B']);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets('edit mode keeps a reversing card above its neighbors', (
    tester,
  ) async {
    final key = await pumpEditableGrid(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(
      tester.renderObject<RenderGrid>(find.byType(Grid)).foregroundIndex,
      0,
      reason: 'the held card paints above the slot it is leaving',
    );
    await settleSlide(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(key.currentState!.isHolding, isFalse);
    expect(key.currentState!.length, 2);
    expect(labelsByX(tester, ['A', 'B']), ['A', 'B']);
  });

  testWidgets('edit mode commits a move before its animation ends', (
    tester,
  ) async {
    final key = await pumpEditableGrid(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(key.currentState!.isHolding, isFalse);
    expect(key.currentState!.length, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await settleSlide(tester);

    expect(labelsByX(tester, ['A', 'B']), ['B', 'A']);
  });

  testWidgets('adding a card clears the held move', (tester) async {
    final key = await pumpEditableGrid(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(key.currentState!.isHolding, isTrue);
    final added = card('C');
    key.currentState!.handleAdd(added);
    await tester.pump();
    expect(key.currentState!.isHolding, isFalse);
    expect(key.currentState!.cancelHeldMove(), isFalse);
    expect(key.currentState!.snapshotChildren, contains(added));
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('disposing the grid completes a canceled deletion', (
    tester,
  ) async {
    await pumpEditableGrid(tester);
    final button = tester.widget<IconButton>(find.byType(IconButton).first);
    final completion =
        Function.apply(button.onPressed!, const []) as Future<void>;
    var completed = false;
    unawaited(completion.then((_) => completed = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(completed, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit mode deletes a held card that has not moved', (
    tester,
  ) async {
    final key = await pumpEditableGrid(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    final scheme = Theme.of(tester.element(find.byType(SuperGrid))).colorScheme;
    final icons = find.byIcon(Icons.close);
    final fillsByX = [
      for (var i = 0; i < 2; i++)
        (tester.getTopLeft(icons.at(i)).dx, deleteFill(tester, icons.at(i))),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    expect(fillsByX.first.$2, scheme.error);
    expect(fillsByX.last.$2, scheme.primary);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(cardOpacity(tester, 'A'), lessThan(1));
    expect(find.text('A'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 151));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 421));
    await tester.pump();

    expect(key.currentState!.length, 1);
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}

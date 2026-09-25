import 'package:fl_clash/widgets/activate_box.dart';
import 'package:fl_clash/widgets/card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets(
    'add tile confirms the focused card and keeps the corner button',
    (tester) async {
      var cardPresses = 0;
      var adds = 0;

      await tester.pumpWidget(
        TestApp(
          child: Scaffold(
            body: Stack(
              clipBehavior: Clip.none,
              children: [
                CardPressOverride(
                  onPressed: () => adds++,
                  child: ActivateBox(
                    child: SizedBox(
                      height: 100,
                      width: 200,
                      child: CommonCard(
                        onPressed: () => cardPresses++,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text('inner'),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: ExcludeFocus(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton.filled(
                        onPressed: () => adds++,
                        icon: const Icon(Icons.add),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      var excluded = false;
      tester.element(find.text('inner')).visitAncestorElements((element) {
        final widget = element.widget;
        if (widget is ExcludeFocus && widget.excluding) {
          excluded = true;
          return false;
        }
        return true;
      });
      expect(excluded, isTrue);
      var cornerExcluded = false;
      tester.element(find.byIcon(Icons.add)).visitAncestorElements((element) {
        final widget = element.widget;
        if (widget is ExcludeFocus && widget.excluding) {
          cornerExcluded = true;
          return false;
        }
        return true;
      });
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
        reason: 'add tile keeps focus on the card',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(cardPresses, 0);
      expect(adds, 1);
      expect(tester.getSize(find.byType(IconButton)), const Size(24, 24));
    },
  );
}

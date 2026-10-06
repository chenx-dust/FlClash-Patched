import 'package:fl_clash/common/shape.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/widgets/chip.dart';
import 'package:fl_clash/widgets/text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

double _channelProgress(Color from, Color to, Color value) {
  final span = to.r - from.r;
  if (span.abs() < 0.001) {
    return (value.g - from.g) / (to.g - from.g);
  }
  return (value.r - from.r) / span;
}

void main() {
  testWidgets('chip labels use Twemoji only for emoji spans', (tester) async {
    const label = '🇭🇰 Hong Kong 👩‍💻';
    await tester.pumpWidget(
      const TestApp(
        child: Column(
          children: [
            CommonChip(label: label),
            TonalChip(
              label: label,
              color: Colors.blue,
              foregroundColor: Colors.white,
            ),
            MetaChip(label: label),
          ],
        ),
      ),
    );

    final texts = tester.widgetList<RichText>(
      find.text(label, findRichText: true),
    );
    expect(texts, hasLength(3));
    for (final text in texts) {
      final spans = (text.text as TextSpan).children!.cast<TextSpan>();
      expect(spans.map((span) => span.text), ['🇭🇰', ' Hong Kong ', '👩‍💻']);
      expect(spans.first.style?.fontFamily, FontFamily.twEmoji.value);
      expect(spans.last.style?.fontFamily, FontFamily.twEmoji.value);
      expect(
        spans.elementAt(1).style?.fontFamily,
        isNot(FontFamily.twEmoji.value),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    }
    expect(tester.takeException(), isNull);
  });

  Material chipMaterial(WidgetTester tester) {
    return tester.widget<Material>(
      find
          .descendant(
            of: find.byType(CommonChip),
            matching: find.byType(Material),
          )
          .first,
    );
  }

  testWidgets('TonalChip paints its fill and forwards taps', (tester) async {
    var presses = 0;
    const color = Color(0xFFD0E4FF);
    const foreground = Color(0xFF001D36);

    await tester.pumpWidget(
      TestApp(
        child: TonalChip(
          label: 'proxy',
          color: color,
          foregroundColor: foreground,
          onPressed: () => presses++,
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(TonalChip),
        matching: find.byType(Material),
      ),
    );
    final text = tester.widget<EmojiText>(find.byType(EmojiText));

    expect(material.color, color);
    expect(material.shape, AppShape.sm);
    expect(text.style?.color, foreground);

    await tester.tap(find.text('proxy', findRichText: true));
    await tester.pump();

    expect(presses, 1);
  });

  testWidgets('CommonChip calls onPressed when it cannot be deleted', (
    tester,
  ) async {
    var presses = 0;

    await tester.pumpWidget(
      TestApp(
        child: CommonChip(label: 'direct', onPressed: () => presses++),
      ),
    );

    expect(find.byIcon(Symbols.close), findsNothing);
    await tester.tap(find.text('direct', findRichText: true));
    await tester.pump();

    expect(presses, 1);
    expect(find.byIcon(Symbols.close), findsNothing);
  });

  testWidgets(
    'deletable CommonChip arms on the first tap and deletes on the second',
    (tester) async {
      var presses = 0;
      var deletions = 0;

      await tester.pumpWidget(
        TestApp(
          child: CommonChip(
            label: 'curl',
            onPressed: () => presses++,
            onDeleted: () => deletions++,
          ),
        ),
      );

      final scheme = Theme.of(
        tester.element(find.byType(CommonChip)),
      ).colorScheme;
      expect(chipMaterial(tester).color, scheme.surfaceContainerHighest);
      expect(find.byIcon(Symbols.close), findsNothing);

      await tester.tap(find.text('curl', findRichText: true));
      await tester.pump();

      expect(presses, 0);
      expect(deletions, 0);
      await tester.pumpAndSettle();
      expect(chipMaterial(tester).color, scheme.errorContainer);
      expect(find.byIcon(Symbols.close), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.close));
      await tester.pump();

      expect(presses, 0);
      expect(deletions, 1);
    },
  );

  Color chipBorderColor(WidgetTester tester) {
    final shape = chipMaterial(tester).shape! as RoundedSuperellipseBorder;
    return shape.side.color;
  }

  testWidgets('deletable CommonChip animates its width and border', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CommonChip(label: 'curl', onDeleted: () {}),
        ),
      ),
    );

    final scheme = Theme.of(
      tester.element(find.byType(CommonChip)),
    ).colorScheme;
    final restingWidth = tester.getSize(find.byType(CommonChip)).width;
    expect(chipBorderColor(tester), scheme.outlineVariant);

    await tester.tap(find.text('curl', findRichText: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final midWidth = tester.getSize(find.byType(CommonChip)).width;
    final midBorder = chipBorderColor(tester);
    final midFill = chipMaterial(tester).color!;
    expect(midWidth, greaterThan(restingWidth));
    expect(midBorder, isNot(scheme.outlineVariant));
    expect(midBorder, isNot(scheme.error));
    expect(
      _channelProgress(scheme.outlineVariant, scheme.error, midBorder),
      closeTo(
        _channelProgress(
          scheme.surfaceContainerHighest,
          scheme.errorContainer,
          midFill,
        ),
        0.01,
      ),
    );

    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(CommonChip)).width,
      greaterThan(midWidth),
    );
    expect(chipBorderColor(tester), scheme.error);
  });

  testWidgets('hovering a deletable CommonChip arms it and click deletes it', (
    tester,
  ) async {
    var deletions = 0;

    await tester.pumpWidget(
      TestApp(
        child: CommonChip(label: 'curl', onDeleted: () => deletions++),
      ),
    );

    final scheme = Theme.of(
      tester.element(find.byType(CommonChip)),
    ).colorScheme;
    expect(
      tester.widget<InkWell>(find.byType(InkWell)).mouseCursor,
      SystemMouseCursors.click,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(
      tester.getCenter(find.text('curl', findRichText: true)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(chipMaterial(tester).color, scheme.errorContainer);
    expect(find.byIcon(Symbols.close), findsOneWidget);
    expect(deletions, 0);

    await gesture.moveTo(Offset.zero);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(chipMaterial(tester).color, scheme.surfaceContainerHighest);
    expect(find.byIcon(Symbols.close), findsNothing);

    await gesture.moveTo(
      tester.getCenter(find.text('curl', findRichText: true)),
    );
    await tester.pump();
    final center = tester.getCenter(find.text('curl', findRichText: true));
    await gesture.moveTo(center);
    await gesture.down(center);
    await gesture.up();
    await tester.pump();

    expect(deletions, 1);
  });

  testWidgets('focus arms a deletable CommonChip and activate deletes it', (
    tester,
  ) async {
    var deletions = 0;

    await tester.pumpWidget(
      TestApp(
        child: CommonChip(label: 'curl', onDeleted: () => deletions++),
      ),
    );

    final scheme = Theme.of(
      tester.element(find.byType(CommonChip)),
    ).colorScheme;
    Focus.of(
      tester.element(find.text('curl', findRichText: true)),
    ).requestFocus();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(deletions, 0);
    expect(chipMaterial(tester).color, scheme.errorContainer);
    expect(find.byIcon(Symbols.close), findsOneWidget);

    Focus.of(tester.element(find.text('curl', findRichText: true))).unfocus();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(chipMaterial(tester).color, scheme.surfaceContainerHighest);
    expect(find.byIcon(Symbols.close), findsNothing);

    Focus.of(
      tester.element(find.text('curl', findRichText: true)),
    ).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(deletions, 1);
  });

  Finder closeIconOf(String label) {
    return find.descendant(
      of: find.ancestor(
        of: find.text(label, findRichText: true),
        matching: find.byType(CommonChip),
      ),
      matching: find.byIcon(Symbols.close),
    );
  }

  testWidgets('tapping outside a touch-armed CommonChip cancels deletion', (
    tester,
  ) async {
    var deletions = 0;

    await tester.pumpWidget(
      TestApp(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: CommonChip(label: 'curl', onDeleted: () => deletions++),
        ),
      ),
    );

    await tester.tap(find.text('curl', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byIcon(Symbols.close), findsOneWidget);

    final chip = tester.getRect(find.byType(CommonChip));
    await tester.tapAt(chip.bottomRight + const Offset(32, 32));
    await tester.pumpAndSettle();

    expect(deletions, 0);
    expect(find.byIcon(Symbols.close), findsNothing);

    await tester.tap(find.text('curl', findRichText: true));
    await tester.pumpAndSettle();
    expect(deletions, 0);
    expect(find.byIcon(Symbols.close), findsOneWidget);
  });

  testWidgets(
    'tapping another chip cancels the armed one and arms the new one',
    (tester) async {
      var deletions = 0;

      await tester.pumpWidget(
        TestApp(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommonChip(label: 'curl', onDeleted: () => deletions++),
                CommonChip(label: 'wget', onDeleted: () => deletions++),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('curl', findRichText: true));
      await tester.pumpAndSettle();
      expect(closeIconOf('curl'), findsOneWidget);

      await tester.tap(find.text('wget', findRichText: true));
      await tester.pumpAndSettle();

      expect(deletions, 0);
      expect(closeIconOf('curl'), findsNothing);
      expect(closeIconOf('wget'), findsOneWidget);
    },
  );

  testWidgets('CommonChip shows a leading category icon', (tester) async {
    await tester.pumpWidget(
      TestApp(
        child: CommonChip(icon: Symbols.hub, label: 'tcp', onDeleted: () {}),
      ),
    );

    expect(find.byIcon(Symbols.hub), findsOneWidget);
    expect(find.text('tcp', findRichText: true), findsOneWidget);
    expect(find.byIcon(Symbols.close), findsNothing);
  });
}

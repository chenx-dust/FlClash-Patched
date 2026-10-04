import 'package:code_forge/code_forge.dart';
import 'package:fl_clash/widgets/popup.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  setUpAll(initEditorNative);

  for (final dragStart in [true, false]) {
    testWidgets(
      'an open menu allows dragging the ${dragStart ? 'start' : 'end'} handle',
      (tester) async {
        final controller = CodeForgeController()
          ..text = 'abcdef\nabcdef\nabcdef';
        VoidCallback? dismiss;
        addTearDown(controller.dispose);
        var requests = 0;
        await pumpEditor(
          tester,
          controller,
          isMobile: true,
          onContextMenu: (context, request) {
            expect(request.isMobile, isTrue);
            requests++;
            dismiss?.call();
            dismiss = showCommonPopupOverlay(
              context: context,
              anchorOf: () => request.globalPosition & Size.zero,
              avoid: request.selectionRect,
              builder: (_, close) => CommonPopupMenu(
                items: [
                  CommonPopupMenuItem(label: 'Copy', onPressed: request.copy),
                ],
                onDismiss: close,
              ),
              onDismiss: () => dismiss = null,
            );
          },
        );
        final glyph = TextPainter(
          text: const TextSpan(text: 'a', style: TextStyle(fontSize: 16)),
          textDirection: TextDirection.ltr,
        )..layout();
        final glyphWidth = glyph.width;
        glyph.dispose();
        final origin = tester.getTopLeft(find.byType(CodeForge));
        final press = await tester.startGesture(
          origin + Offset(57.6 + 2 * glyphWidth, editorTopPadding + 10),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump(const Duration(milliseconds: 600));
        await press.up();
        await settle(tester);
        expect(
          controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 6),
        );
        expect(find.byType(CommonPopupMenu), findsOneWidget);
        final handle =
            origin +
            Offset(
              57.6 + (dragStart ? -8 : 6 * glyphWidth + 8),
              editorTopPadding + editorLineHeight + 10,
            );
        final gesture = await tester.startGesture(
          handle,
          kind: PointerDeviceKind.touch,
        );
        await tester.pump();
        expect(find.byType(CommonPopupMenu), findsNothing);
        await gesture.moveBy(
          dragStart ? Offset(glyphWidth, 0) : const Offset(0, editorLineHeight),
        );
        await tester.pump();
        expect(
          controller.selection,
          dragStart
              ? const TextSelection(baseOffset: 6, extentOffset: 1)
              : const TextSelection(baseOffset: 0, extentOffset: 13),
        );
        await gesture.moveBy(Offset(dragStart ? glyphWidth : -glyphWidth, 0));
        await tester.pump();
        expect(controller.selection.extentOffset, dragStart ? 2 : 12);
        await gesture.up();
        await settle(tester);
        expect(find.byType(CommonPopupMenu), findsOneWidget);
        expect(requests, 2);
        dismiss?.call();
        await tester.pump();
      },
    );
  }
}

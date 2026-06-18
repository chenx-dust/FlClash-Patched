import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

Future<void> copyText(BuildContext context, String? text) async {
  if (text == null || text.isEmpty) {
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) {
    return;
  }
  context.showNotifier(
    context.appLocalizations.copySuccess,
    level: MessageLevel.success,
  );
}

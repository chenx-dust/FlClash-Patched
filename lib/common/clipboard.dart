import 'package:fl_clash/common/context.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

Future<void> copyText(BuildContext context, String? text) async {
  if (text == null || text.isEmpty) {
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) {
    return;
  }
  context.showSnackBar(context.appLocalizations.copySuccess);
}

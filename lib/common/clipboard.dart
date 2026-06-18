import 'package:fl_clash/common/context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> copyText(BuildContext context, String? text) async {
  if (text == null || text.isEmpty) {
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) {
    return;
  }
  context.showNotifier(context.appLocalizations.copySuccess);
}

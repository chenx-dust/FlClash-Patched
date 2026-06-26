import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';

class ProviderEditorView extends StatefulWidget {
  final ExternalProvider provider;
  final bool editable;

  const ProviderEditorView({
    super.key,
    required this.provider,
    this.editable = false,
  });

  @override
  State<ProviderEditorView> createState() => _ProviderEditorViewState();
}

class _ProviderEditorViewState extends State<ProviderEditorView> {
  final contentNotifier = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final path = widget.provider.path;
      final content = path == null
          ? ''
          : await globalState.safeRun<String>(() async {
              return File(path).readAsString();
            });
      if (!mounted) {
        return;
      }
      contentNotifier.value = content ?? '';
    });
  }

  Future<void> _handleSave(
    BuildContext context,
    String _,
    String content,
  ) async {
    final path = widget.provider.path;
    if (path == null) return;
    final res = await globalState.safeRun<bool>(() async {
      await File(path).safeWriteAsString(content);
      final message = await coreController.sideLoadExternalProvider(
        providerName: widget.provider.name,
        data: content,
      );
      if (message.isNotEmpty) throw message;
      globalState.container
          .read(providersProvider.notifier)
          .setProvider(
            await coreController.getExternalProvider(widget.provider.name),
          );
      globalState.container
          .read(proxiesActionProvider.notifier)
          .updateGroupsDebounce();
      return true;
    }, silence: false);
    if (res == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _handlePop(
    BuildContext context,
    String title,
    String content,
  ) async {
    if (content == contentNotifier.value) {
      return true;
    }
    final res = await globalState.showMessage(
      context: context,
      message: TextSpan(text: context.appLocalizations.saveChanges),
    );
    if (res == true && context.mounted) {
      await _handleSave(context, title, content);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    contentNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: contentNotifier,
      builder: (_, content, _) {
        return EditorPage(
          key: const Key('content'),
          title: widget.provider.name,
          content: content,
          onSave: widget.editable ? _handleSave : null,
          onPop: widget.editable ? _handlePop : null,
        );
      },
    );
  }
}

import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProviderEditorView extends ConsumerStatefulWidget {
  final ExternalProvider provider;
  final bool editable;

  const ProviderEditorView({
    super.key,
    required this.provider,
    this.editable = false,
  });

  @override
  ConsumerState<ProviderEditorView> createState() => _ProviderEditorViewState();
}

class _ProviderEditorViewState extends ConsumerState<ProviderEditorView> {
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
      final proxiesAction = ref.read(proxiesActionProvider.notifier);
      final message = await proxiesAction.sideLoadExternalProvider(
        widget.provider,
        content,
      );
      if (message.isNotEmpty) throw MessageException(message);
      proxiesAction.updateGroupsDebounce();
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
    final res = await dialogs.showMessage(
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

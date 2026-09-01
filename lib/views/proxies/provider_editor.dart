import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProviderEditorView extends ConsumerStatefulWidget {
  const ProviderEditorView({
    super.key,
    required this.provider,
    this.editable = false,
  });

  final ExternalProvider provider;
  final bool editable;

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
          : await globalState.safeRun<String>(() => File(path).readAsString());
      if (mounted) {
        contentNotifier.value = content ?? '';
      }
    });
  }

  Future<void> _handleSave(
    BuildContext context,
    String _,
    String content,
  ) async {
    final path = widget.provider.path;
    if (path == null) {
      return;
    }
    final result = await globalState.safeRun<bool>(() async {
      await File(path).safeWriteAsString(content);
      final action = ref.read(proxiesActionProvider.notifier);
      final message = await action.sideLoadExternalProvider(
        widget.provider,
        content,
        showLoading: true,
      );
      if (message.isNotEmpty) {
        throw MessageException(message);
      }
      action.updateGroupsDebounce();
      return true;
    }, silence: false);
    if (result == true && context.mounted) {
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
    final result = await dialogs.showMessage(
      message: TextSpan(text: context.appLocalizations.saveChanges),
    );
    if (result == true && context.mounted) {
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

import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScriptsView extends ConsumerStatefulWidget {
  const ScriptsView({super.key});

  @override
  ConsumerState<ScriptsView> createState() => _ScriptsViewState();
}

class _ScriptsViewState extends ConsumerState<ScriptsView> {
  final _key = utils.id;
  final _remoteUrlFutures = <int, Future<String?>>{};
  String? _editingRemoteUrl;

  Future<void> _handleDelScript(int id) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.script),
      ),
    );
    if (res != true) {
      return;
    }
    final script = ref.read(scriptsProvider.notifier).value.get(id);
    if (script != null && ref.read(isUpdatingProvider(script.updatingKey))) {
      return;
    }
    ref.read(scriptsProvider.notifier).del(id);
    ref.read(itemProvider(_key).notifier).value = null;
    _clearEffect(id);
  }

  Future<void> _clearEffect(int id) async {
    final path = await appPath.getScriptPath(id.toString());
    await File(path).safeDelete();
    final urlPath = await getScriptRemoteUrlPath(id);
    await File(urlPath).safeDelete();
    _remoteUrlFutures.remove(id);
  }

  void _handleSelected(int id) {
    ref.read(itemProvider(_key).notifier).update((value) {
      if (value == id) {
        return null;
      }
      return id;
    });
  }

  Future<void> _handleSyncScript(Script script) async {
    final appLocalizations = currentAppLocalizations;
    final url = await script.remoteUrl;
    if (url == null || url.isEmpty) {
      globalState.showNotifier(appLocalizations.emptyTip(appLocalizations.url));
      return;
    }
    final updatingKey = script.updatingKey;
    ref.read(isUpdatingProvider(updatingKey).notifier).value = true;
    globalState.showNotifier(appLocalizations.geoUpdating(script.label));
    try {
      await globalState.safeRun<void>(() async {
        final res = await request.getTextResponseForUrl(url);
        final content = res.data;
        if (content == null) {
          globalState.showNotifier(
            appLocalizations.nullTip(appLocalizations.content),
          );
          return;
        }
        final oldContent = await script.content;
        if (oldContent == content) {
          globalState.showNotifier(appLocalizations.geoSkipped(script.label));
          return;
        }
        final currentScript = ref
            .read(scriptsProvider.notifier)
            .value
            .get(script.id);
        if (currentScript == null) {
          return;
        }
        final newScript = await currentScript.save(content);
        ref.read(scriptsProvider.notifier).put(newScript);
        globalState.showNotifier(appLocalizations.geoUpdated(script.label));
      }, silence: false);
    } finally {
      ref.read(isUpdatingProvider(updatingKey).notifier).value = false;
    }
  }

  Future<String?> _remoteUrlFutureFor(Script script) {
    return _remoteUrlFutures[script.id] ??= script.remoteUrl;
  }

  Widget _buildScriptTitle(Script script) {
    return FutureBuilder<String?>(
      future: _remoteUrlFutureFor(script),
      builder: (_, snapshot) {
        final url = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              script.label,
              style: context.textTheme.bodyLarge,
              maxLines: 3,
            ),
            const SizedBox(height: 4),
            Text(
              script.lastUpdateTime.getLastUpdateTimeDesc(context),
              style: context.textTheme.bodyMedium,
            ),
            if (url != null && url.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                url,
                style: context.textTheme.bodyMedium?.toLight,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildContent(List<Script> scripts, int? selectedScriptId) {
    final appLocalizations = context.appLocalizations;
    if (scripts.isEmpty) {
      return NullStatus(
        illustration: const ScriptEmptyIllustration(),
        label: appLocalizations.nullTip(appLocalizations.script),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: scripts.length,
      itemBuilder: (_, index) {
        final script = scripts[index];
        return CommonSelectedListItem(
          isSelected: selectedScriptId == script.id,
          title: _buildScriptTitle(script),
          onSelected: () {
            _handleSelected(script.id);
          },
          onPressed: () {
            _handleSelected(script.id);
          },
        );
      },
    );
  }

  Future<void> _handleEditorSave(
    BuildContext _,
    String title,
    String content, {
    Script? script,
  }) async {
    final appLocalizations = context.appLocalizations;
    Script newScript =
        (script?.copyWith(label: title) ?? Script.create(label: title));
    newScript = await newScript.save(content);
    if (newScript.label.isEmpty) {
      final res = await globalState.showCommonDialog<String>(
        child: InputDialog(
          title: appLocalizations.save,
          value: '',
          hintText: appLocalizations.pleaseEnterScriptName,
          inputFormatters: TextInputLimits.limit(TextInputLimits.name),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return appLocalizations.emptyTip(appLocalizations.name);
            }
            if (value != script?.label) {
              final isExits = ref
                  .read(scriptsProvider.notifier)
                  .isExits(value);
              if (isExits) {
                return appLocalizations.existsTip(appLocalizations.name);
              }
            }
            return null;
          },
        ),
      );
      if (res == null || res.isEmpty) {
        return;
      }
      newScript = newScript.copyWith(label: res);
    }
    if (newScript.label != script?.label) {
      final isExits = ref
          .read(scriptsProvider.notifier)
          .isExits(newScript.label);
      if (isExits) {
        globalState.showMessage(
          message: TextSpan(
            text: appLocalizations.existsTip(appLocalizations.name),
          ),
        );
        return;
      }
    }
    if (_editingRemoteUrl != null) {
      if (_editingRemoteUrl!.isEmpty) {
        await newScript.clearRemoteUrl();
        _remoteUrlFutures[newScript.id] = Future.value(null);
      } else {
        await newScript.saveRemoteUrl(_editingRemoteUrl!);
        _remoteUrlFutures[newScript.id] = Future.value(_editingRemoteUrl);
      }
    }
    ref.read(scriptsProvider.notifier).put(newScript);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _handleEditorPop(
    BuildContext _,
    String title,
    String content,
    String raw, {
    Script? script,
  }) async {
    final appLocalizations = context.appLocalizations;
    if (content == raw) {
      return true;
    }
    final res = await globalState.showMessage(
      message: TextSpan(text: appLocalizations.saveChanges),
    );
    if (res == true && mounted) {
      await _handleEditorSave(context, title, content, script: script);
    } else {
      return true;
    }
    return false;
  }

  void _handleToEditor([int? id]) async {
    _editingRemoteUrl = null;
    final script = await ref.read(scriptProvider(id).future);
    _editingRemoteUrl = await script?.remoteUrl;
    final title = script?.label ?? '';
    final raw = (await script?.content) ?? scriptTemplate;
    if (!mounted) {
      return;
    }
    BaseNavigator.push(
      context,
      EditorPage(
        titleEditable: true,
        title: title,
        supportRemoteDownload: true,
        onRemoteDownload: (url) {
          _editingRemoteUrl = url;
        },
        onLocalImport: () {
          _editingRemoteUrl = '';
        },
        onSave: (context, title, content) {
          _handleEditorSave(context, title, content, script: script);
        },
        onPop: (context, title, content) {
          return _handleEditorPop(context, title, content, raw, script: script);
        },
        languages: const [Language.javaScript],
        content: raw,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final scripts = ref.watch(scriptsProvider).value ?? [];
    final selectedScriptId = ref.watch(itemProvider(_key));
    final selectedScript = scripts.get(selectedScriptId);
    final isSelectedScriptUpdating = selectedScript == null
        ? false
        : ref.watch(isUpdatingProvider(selectedScript.updatingKey));
    return CommonPopScope(
      canPop: selectedScriptId == null,
      onPop: (_) {
        if (selectedScriptId != null) {
          ref.read(itemProvider(_key).notifier).value = null;
          return false;
        }
        Navigator.of(context).pop();
        return false;
      },
      child: CommonScaffold(
        actions: [
          if (selectedScript != null) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                tooltip: appLocalizations.sync,
                onPressed: isSelectedScriptUpdating
                    ? null
                    : () {
                        _handleSyncScript(selectedScript);
                      },
                icon: isSelectedScriptUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
            ),
            const SizedBox(width: 2),
          ],
          if (selectedScriptId != null) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                tooltip: context.appLocalizations.delete,
                onPressed: isSelectedScriptUpdating
                    ? null
                    : () {
                        _handleDelScript(selectedScriptId);
                      },
                icon: const Icon(Icons.delete),
              ),
            ),
            const SizedBox(width: 2),
          ],
          CommonMinFilledButtonTheme(
            child: selectedScriptId != null
                ? FilledButton(
                    onPressed: () {
                      _handleToEditor(selectedScriptId);
                    },
                    child: Text(appLocalizations.edit),
                  )
                : FilledButton.tonal(
                    onPressed: () {
                      _handleToEditor();
                    },
                    child: Text(appLocalizations.add),
                  ),
          ),
          const SizedBox(width: 8),
        ],
        body: _buildContent(scripts, selectedScriptId),
        title: appLocalizations.script,
      ),
    );
  }
}

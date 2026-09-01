import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScriptsView extends ConsumerStatefulWidget {
  const ScriptsView({super.key});

  @override
  ConsumerState<ScriptsView> createState() => _ScriptsViewState();
}

class _ScriptsViewState extends ConsumerState<ScriptsView> {
  final _key = uniqueId;
  final _remoteUrlFutures = <int, Future<String?>>{};
  String? _editingRemoteUrl;

  Future<void> _handleDelete() async {
    final appLocalizations = context.appLocalizations;
    final res = await dialogs.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteMultipTip(appLocalizations.script),
      ),
    );
    if (res != true) {
      return;
    }
    final selectedScriptIds = ref.read(itemsProvider(_key)).cast<int>();
    final selectedScripts = ref
        .read(scriptsProvider.notifier)
        .value
        .where((script) => selectedScriptIds.contains(script.id));
    if (selectedScripts.any(
      (script) => ref.read(isUpdatingProvider(script.updatingKey)),
    )) {
      return;
    }
    ref.read(scriptsProvider.notifier).delAll(selectedScriptIds);
    ref.read(itemsProvider(_key).notifier).value = {};
    for (final id in selectedScriptIds) {
      unawaited(_clearEffect(id));
    }
  }

  Future<void> _clearEffect(int id) async {
    final path = await appPath.getScriptPath(id.toString());
    await File(path).safeDelete();
    await File(await getScriptRemoteUrlPath(id)).safeDelete();
    unawaited(_remoteUrlFutures.remove(id));
  }

  void _handleSelected(int id) {
    ref.read(itemsProvider(_key).notifier).update((selectedScriptIds) {
      return Set<int>.from(selectedScriptIds)..addOrRemove(id);
    });
  }

  void _handleSelectAll() {
    final ids =
        ref.read(scriptsProvider).value?.map((item) => item.id).toSet() ?? {};
    ref.read(itemsProvider(_key).notifier).update((selected) {
      return selected.containsAll(ids) ? {} : ids;
    });
  }

  Future<void> _handleSyncScript(Script script) async {
    final appLocalizations = context.appLocalizations;
    final url = await script.remoteUrl;
    if (url == null || url.isEmpty) {
      dialogs.showNotifier(appLocalizations.emptyTip(appLocalizations.url));
      return;
    }
    final updatingKey = script.updatingKey;
    final updatingKeys = ref.read(updatingKeysProvider.notifier);
    final updatingOperation = updatingKeys.start(updatingKey);
    dialogs.showNotifier(appLocalizations.geoUpdating(script.label));
    try {
      await globalState.safeRun<void>(() async {
        final response = await request.getTextResponseForUrl(url);
        final content = response.data;
        if (content == null) {
          dialogs.showNotifier(
            appLocalizations.nullTip(appLocalizations.content),
          );
          return;
        }
        if (await script.content == content) {
          dialogs.showNotifier(appLocalizations.geoSkipped(script.label));
          return;
        }
        if (!mounted) {
          return;
        }
        final currentScript = ref
            .read(scriptsProvider.notifier)
            .value
            .get(script.id);
        if (currentScript == null) {
          return;
        }
        final updatedScript = await currentScript.save(content);
        ref.read(scriptsProvider.notifier).put(updatedScript);
        dialogs.showNotifier(appLocalizations.geoUpdated(script.label));
      }, silence: false);
    } finally {
      updatingKeys.stop(updatingKey, updatingOperation);
    }
  }

  Future<String?> _remoteUrlFutureFor(Script script) {
    return _remoteUrlFutures[script.id] ??= script.remoteUrl;
  }

  Widget _buildScriptTitle(Script script) {
    return FutureBuilder<String?>(
      future: _remoteUrlFutureFor(script),
      builder: (_, snapshot) {
        final remoteUrl = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(script.label, style: context.textTheme.bodyLarge, maxLines: 3),
            const SizedBox(height: 4),
            Text(
              script.lastUpdateTime.getLastUpdateTimeDesc(context),
              style: context.textTheme.bodyMedium,
            ),
            if (remoteUrl != null && remoteUrl.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                remoteUrl,
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

  Widget _buildContent(List<Script> scripts, Set<dynamic> selectedScriptIds) {
    final appLocalizations = context.appLocalizations;
    if (scripts.isEmpty) {
      return NullStatus(
        illustration: const ScriptEmptyIllustration(),
        label: appLocalizations.nullTip(appLocalizations.script),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: scripts.length,
      itemBuilder: (_, index) {
        final script = scripts[index];
        return ItemPositionProvider(
          position: ItemPosition.get(index, scripts.length),
          child: SelectedDecorationListItem(
            isSelected: selectedScriptIds.contains(script.id),
            isEditing: selectedScriptIds.isNotEmpty,
            title: _buildScriptTitle(script),
            onSelected: () {
              _handleSelected(script.id);
            },
            onPressed: () {
              _handleToEditor(script.id);
            },
          ),
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
      final res = await dialogs.showCommonDialog<String>(
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
              final isExits = ref.read(scriptsProvider.notifier).isExits(value);
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
        unawaited(
          dialogs.showMessage(
            message: TextSpan(
              text: appLocalizations.existsTip(appLocalizations.name),
            ),
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
    final res = await dialogs.showMessage(
      message: TextSpan(text: appLocalizations.saveChanges),
    );
    if (res == true && mounted) {
      unawaited(_handleEditorSave(context, title, content, script: script));
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
    unawaited(
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
            return _handleEditorPop(
              context,
              title,
              content,
              raw,
              script: script,
            );
          },
          languages: const [Language.javaScript],
          content: raw,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final scripts = ref.watch(scriptsProvider).value ?? [];
    final selectedScriptIds = ref.watch(itemsProvider(_key));
    final selectedScripts = scripts
        .where((script) => selectedScriptIds.contains(script.id))
        .toList();
    final selectedScript = selectedScripts.length == 1
        ? selectedScripts.single
        : null;
    final selectedUpdatingStates = {
      for (final script in selectedScripts)
        script.id: ref.watch(isUpdatingProvider(script.updatingKey)),
    };
    final isSelectedScriptUpdating = selectedScript == null
        ? false
        : selectedUpdatingStates[selectedScript.id] ?? false;
    final isAnySelectedScriptUpdating = selectedUpdatingStates.values.any(
      (value) => value,
    );
    return CommonPopScope(
      canPop: selectedScriptIds.isEmpty,
      onPop: (_) {
        if (selectedScriptIds.isNotEmpty) {
          ref.read(itemsProvider(_key).notifier).value = {};
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
          if (selectedScriptIds.isNotEmpty) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                tooltip: context.appLocalizations.delete,
                onPressed: isAnySelectedScriptUpdating ? null : _handleDelete,
                icon: const Icon(Icons.delete),
              ),
            ),
            const SizedBox(width: 2),
          ],
          CommonMinFilledButtonTheme(
            child: selectedScriptIds.isNotEmpty
                ? FilledButton(
                    onPressed: _handleSelectAll,
                    child: Text(appLocalizations.selectAll),
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
        body: _buildContent(scripts, selectedScriptIds),
        title: appLocalizations.script,
      ),
    );
  }
}

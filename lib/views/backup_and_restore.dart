import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/backup_file_name.dart';
import 'package:fl_clash/common/dav_client.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/chip.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/fade_box.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/loading.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/text.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackupAndRestore extends ConsumerStatefulWidget {
  const BackupAndRestore({super.key});

  @override
  ConsumerState<BackupAndRestore> createState() => _BackupAndRestoreState();
}

class _BackupAndRestoreState extends ConsumerState<BackupAndRestore>
    with UniqueKeyStateMixin {
  final _davConnection = DAVConnectionController();

  @override
  void initState() {
    super.initState();
    ref.listenManual(davSettingProvider, (_, _) {
      _updateDAVClient();
    }, fireImmediately: true);
  }

  void _updateDAVClient() {
    unawaited(_davConnection.update(ref.read(davSettingProvider)));
  }

  @override
  void dispose() {
    _davConnection.dispose();
    super.dispose();
  }

  Future<void> _showAddWebDAV(DAVProps? dav) async {
    await dialogs.showCommonDialog<String>(
      child: WebDAVFormDialog(dav: dav?.copyWith()),
    );
  }

  Future<void> _backupOnWebDAV() async {
    final appLocalizations = context.appLocalizations;
    final fileName = await globalState.loadingRun<String?>(
      () async {
        final client = _davConnection.client;
        if (client == null) {
          return null;
        }
        final now = DateTime.now();
        final version = globalState.packageInfo.version;
        final error = BackupFileName.validate(
          client.fileName,
          version: version,
          platform: Platform.operatingSystem,
          now: now,
        );
        if (error != null) {
          throw MessageException(appLocalizations.invalidBackupFileName);
        }
        final name = BackupFileName.render(
          client.fileName,
          version: version,
          platform: Platform.operatingSystem,
          now: now,
        );
        final success = await ref
            .read(backupActionProvider.notifier)
            .consumeBackup((path) => client.backup(path, name: name));
        return success ? name : null;
      },
      tag: LoadingTag.backup_restore,
      title: appLocalizations.backup,
    );
    if (fileName == null || !mounted) return;
    unawaited(
      dialogs.showMessage(
        title: appLocalizations.backup,
        cancelable: false,
        message: TextSpan(
          children: [
            TextSpan(text: '${appLocalizations.backupSuccess}\n'),
            TextSpan(
              text: fileName,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreOnWebDAV(
    RestoreOption option,
    DAVClient client,
    String name,
  ) async {
    final appLocalizations = context.appLocalizations;
    final backupAction = ref.read(backupActionProvider.notifier);
    final res = await globalState.loadingRun<bool>(
      () async {
        await client.restore(name: name);
        await backupAction.restore(option);
        return true;
      },
      tag: LoadingTag.backup_restore,
      title: appLocalizations.restore,
    );
    if (res != true || !mounted) return;
    unawaited(
      dialogs.showMessage(
        title: appLocalizations.restore,
        cancelable: false,
        message: TextSpan(text: appLocalizations.restoreSuccess),
      ),
    );
  }

  Future<void> _handleRestoreOnWebDAV() async {
    final client = _davConnection.client;
    if (client == null) return;
    final appLocalizations = context.appLocalizations;
    final files = await globalState.loadingRun<List<DAVFile>>(
      client.listBackups,
      tag: LoadingTag.backup_restore,
      title: appLocalizations.restore,
    );
    if (files == null || !mounted) return;
    if (files.isEmpty) {
      await dialogs.showMessage(
        title: appLocalizations.restore,
        cancelable: false,
        message: TextSpan(text: appLocalizations.noRemoteBackups),
      );
      return;
    }
    final name = await dialogs.showCommonDialog<String>(
      child: RemoteBackupsDialog(files: files, onDelete: client.deleteBackup),
    );
    if (name == null || !mounted) return;
    final restoreOption = await dialogs.showCommonDialog<RestoreOption>(
      child: const RestoreOptionsDialog(),
    );
    if (restoreOption == null || !context.mounted) return;
    unawaited(_restoreOnWebDAV(restoreOption, client, name));
  }

  Future<void> _backupOnLocal() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.loadingRun<bool>(
      () async {
        return ref.read(backupActionProvider.notifier).consumeBackup((
          path,
        ) async {
          final value = await picker.saveFileWithPath(
            getBackupFileName(),
            path,
          );
          return value != null;
        });
      },
      title: appLocalizations.backup,
      tag: LoadingTag.backup_restore,
    );
    if (res != true) return;
    unawaited(
      dialogs.showMessage(
        title: appLocalizations.backup,
        cancelable: false,
        message: TextSpan(text: appLocalizations.backupSuccess),
      ),
    );
  }

  Future<void> _restoreOnLocal(RestoreOption option) async {
    final backupAction = ref.read(backupActionProvider.notifier);
    final appLocalizations = context.appLocalizations;
    final file = await picker.pickerFile();
    final path = file?.path;
    if (path == null) return;
    await File(path).safeCopy(await appPath.backupFilePath);
    final res = await globalState.loadingRun<bool>(
      () async {
        await backupAction.restore(option);
        return true;
      },
      tag: LoadingTag.backup_restore,
      title: appLocalizations.restore,
    );
    if (res != true) return;
    unawaited(
      dialogs.showMessage(
        title: appLocalizations.restore,
        cancelable: false,
        message: TextSpan(text: appLocalizations.restoreSuccess),
      ),
    );
  }

  Future<void> _handleRestoreOnLocal() async {
    final option = await dialogs.showCommonDialog<RestoreOption>(
      child: const RestoreOptionsDialog(),
    );
    if (option == null || !mounted) return;
    unawaited(_restoreOnLocal(option));
  }

  Future<void> _editFileName(DAVProps dav) async {
    final value = await dialogs.showCommonDialog<String>(
      child: BackupFileNameDialog(
        value: dav.fileName,
        version: globalState.packageInfo.version,
        platform: Platform.operatingSystem,
      ),
    );
    if (value == null || !mounted) return;
    if (ref.read(davSettingProvider) != dav) return;
    ref
        .read(davSettingProvider.notifier)
        .update((state) => state?.copyWith(fileName: value));
  }

  Future<void> _editDirectory(DAVProps dav) async {
    final appLocalizations = context.appLocalizations;
    final value = await dialogs.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.davDirectory,
        value: dav.directory,
        labelText: appLocalizations.davDirectory,
        maxLength: TextInputLimits.uri,
        keyboardType: TextInputType.text,
        validator: (value) => DAVDirectory.isValid(value ?? '')
            ? null
            : appLocalizations.invalidDavDirectory,
        actionsBuilder: (controller, submit) => [
          _DAVDirectoryActions(
            controller: controller,
            loadDirectories: DAVClient(dav).listDirectories,
            submit: submit,
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    if (ref.read(davSettingProvider) != dav) return;
    ref
        .read(davSettingProvider.notifier)
        .update(
          (state) => state?.copyWith(directory: DAVDirectory.normalize(value)),
        );
  }

  Future<void> _handleUpdateRestoreStrategy() async {
    final restoreStrategy = ref.read(
      appSettingProvider.select((state) => state.restoreStrategy),
    );
    final res = await dialogs.showCommonDialog(
      child: OptionsDialog<RestoreStrategy>(
        title: currentAppLocalizations.restoreStrategy,
        options: RestoreStrategy.values,
        textBuilder: (mode) => mode.label,
        value: restoreStrategy,
      ),
    );
    if (res == null) {
      return;
    }
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(restoreStrategy: res));
  }

  Future<void> _handleClearData() async {
    final appLocalizations = context.appLocalizations;
    final types = await dialogs.showCommonDialog<Set<ResetDataType>>(
      child: const ResetDataOptionsDialog(),
    );
    if (types == null || types.isEmpty || !mounted) {
      return;
    }
    final confirmed = await dialogs.showMessage(
      title: appLocalizations.clearData,
      message: TextSpan(text: appLocalizations.confirmClearSelectedData),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(storeActionProvider.notifier).handleClear(types);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final dav = ref.watch(davSettingProvider);
    final isLoading = ref.watch(loadingProvider(LoadingTag.backup_restore));
    return CommonScaffold(
      isLoading: isLoading,
      title: appLocalizations.backupAndRestore,
      body: ListView(
        padding: sectionPagePadding,
        children: [
          generateSectionV3(
            title: appLocalizations.remote,
            isFirst: true,
            items: [
              if (dav == null)
                ListItem(
                  leading: const Icon(Symbols.account_box),
                  title: Text(appLocalizations.noInfo),
                  subtitle: Text(appLocalizations.pleaseBindWebDAV),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      _showAddWebDAV(dav);
                    },
                    child: Text(appLocalizations.bind),
                  ),
                )
              else ...[
                ListItem(
                  leading: const Icon(Symbols.account_box),
                  title: TooltipText(
                    text: Text(
                      dav.user.isEmpty ? dav.uri : dav.user,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(appLocalizations.connectivity),
                        _DavConnectionIndicator(connection: _davConnection),
                      ],
                    ),
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      _showAddWebDAV(dav);
                    },
                    child: Text(appLocalizations.edit),
                  ),
                ),
                ListItem(
                  title: Text(appLocalizations.fileName),
                  subtitle: Text(dav.fileName),
                  onTap: () => _editFileName(dav),
                ),
                ListItem(
                  title: Text(appLocalizations.davDirectory),
                  subtitle: Text(DAVDirectory.normalize(dav.directory)),
                  onTap: () => _editDirectory(dav),
                ),
                ListItem(
                  onTap: _backupOnWebDAV,
                  title: Text(appLocalizations.backup),
                  subtitle: Text(appLocalizations.remoteBackupDesc),
                ),
                ListItem(
                  onTap: _handleRestoreOnWebDAV,
                  title: Text(appLocalizations.restore),
                  subtitle: Text(appLocalizations.restoreFromWebDAVDesc),
                ),
              ],
            ],
          ),
          generateSectionV3(
            title: appLocalizations.local,
            items: [
              ListItem(
                onTap: _backupOnLocal,
                title: Text(appLocalizations.backup),
                subtitle: Text(appLocalizations.localBackupDesc),
              ),
              ListItem(
                onTap: _handleRestoreOnLocal,
                title: Text(appLocalizations.restore),
                subtitle: Text(appLocalizations.restoreFromFileDesc),
              ),
            ],
          ),
          generateSectionV3(
            title: appLocalizations.options,
            items: [
              _RestoreStrategyItem(onPressed: _handleUpdateRestoreStrategy),
              ListItem(
                onTap: _handleClearData,
                title: Text(
                  appLocalizations.clearData,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ResetDataOptionsDialog extends StatefulWidget {
  const ResetDataOptionsDialog({super.key});

  @override
  State<ResetDataOptionsDialog> createState() => _ResetDataOptionsDialogState();
}

class _ResetDataOptionsDialogState extends State<ResetDataOptionsDialog> {
  final _selected = <ResetDataType>{};

  void _update(ResetDataType type, bool? selected) {
    setState(() {
      _selected.remove(ResetDataType.allData);
      if (selected == true) {
        _selected.add(type);
      } else {
        _selected.remove(type);
      }
    });
  }

  void _updateAll(bool? selected) {
    setState(() {
      _selected
        ..clear()
        ..addAll(selected == true ? allResetDataTypes : const {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.clearData,
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _selected.isEmpty
              ? null
              : () {
                  Navigator.of(context).pop(Set<ResetDataType>.of(_selected));
                },
          style: TextButton.styleFrom(
            foregroundColor: context.colorScheme.error,
          ),
          child: Text(appLocalizations.confirm),
        ),
      ],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListItem.checkbox(
            title: Text(appLocalizations.allData),
            value: _selected.contains(ResetDataType.allData),
            onChanged: _updateAll,
          ),
          ListItem.checkbox(
            title: Text(appLocalizations.resetSettingsData),
            value: _selected.contains(ResetDataType.settings),
            onChanged: (value) {
              _update(ResetDataType.settings, value);
            },
          ),
          ListItem.checkbox(
            title: Text(appLocalizations.resetProfilesAndScripts),
            value: _selected.contains(ResetDataType.profilesAndScripts),
            onChanged: (value) {
              _update(ResetDataType.profilesAndScripts, value);
            },
          ),
        ],
      ),
    );
  }
}

class _DavConnectionIndicator extends StatelessWidget {
  const _DavConnectionIndicator({required this.connection});

  final ValueNotifier<bool?> connection;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: connection,
      builder: (context, isConnected, _) {
        return Center(
          child: FadeThroughBox(
            child: isConnected == null
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CommonCircleLoading(),
                  )
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !isConnected
                          ? context.colorScheme.error
                          : Colors.green.harmonizeWith(
                              context.colorScheme.primary,
                            ),
                    ),
                    width: 12,
                    height: 12,
                  ),
          ),
        );
      },
    );
  }
}

class _RestoreStrategyItem extends ConsumerWidget {
  const _RestoreStrategyItem({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restoreStrategy = ref.watch(
      appSettingProvider.select((state) => state.restoreStrategy),
    );
    return ListItem(
      onTap: onPressed,
      title: Text(context.appLocalizations.restoreStrategy),
      trailing: FilledButton(
        onPressed: onPressed,
        child: Text(restoreStrategy.label),
      ),
    );
  }
}

class RestoreOptionsDialog extends StatefulWidget {
  const RestoreOptionsDialog({super.key});

  @override
  State<RestoreOptionsDialog> createState() => _RestoreOptionsDialogState();
}

class _RestoreOptionsDialogState extends State<RestoreOptionsDialog> {
  void _handleOnTab(RestoreOption? option) {
    if (option == null) return;
    Navigator.of(context).pop(option);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.restore,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Wrap(
        children: [
          ListItem(
            onTap: () {
              _handleOnTab(RestoreOption.onlyProfiles);
            },
            title: Text(appLocalizations.restoreOnlyConfig),
          ),
          ListItem(
            onTap: () {
              _handleOnTab(RestoreOption.all);
            },
            title: Text(appLocalizations.restoreAllData),
          ),
        ],
      ),
    );
  }
}

class BackupFileNameDialog extends StatefulWidget {
  final String value;
  final String version;
  final String platform;

  const BackupFileNameDialog({
    super.key,
    required this.value,
    required this.version,
    required this.platform,
  });

  @override
  State<BackupFileNameDialog> createState() => _BackupFileNameDialogState();
}

class _BackupFileNameDialogState extends State<BackupFileNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  late final DateTime _previewTime;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _previewTime = DateTime.now();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _render(String value) => BackupFileName.render(
    value,
    version: widget.version,
    platform: widget.platform,
    now: _previewTime,
  );

  String? _validate(String? value) {
    final appLocalizations = context.appLocalizations;
    final error = BackupFileName.validate(
      value ?? '',
      version: widget.version,
      platform: widget.platform,
      now: _previewTime,
    );
    return switch (error) {
      null => null,
      BackupFileNameError.empty => appLocalizations.emptyTip(
        appLocalizations.fileName,
      ),
      BackupFileNameError.unknownVariable =>
        appLocalizations.unknownBackupVariable,
      _ => appLocalizations.invalidBackupFileName,
    };
  }

  void _insert(String variable) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : start;
    final token = '{$variable}';
    _controller.value = TextEditingValue(
      text: _controller.text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final value = _controller.text;
    Navigator.of(context).pop(BackupFileName.ensureZipExtension(value));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final replacements = {
      'version': appLocalizations.backupVersionDescription,
      'date': appLocalizations.backupDateDescription,
      'time': appLocalizations.backupTimeDescription,
      'platform': appLocalizations.backupPlatformDescription,
    };
    return CommonDialog(
      title: appLocalizations.fileName,
      maxWidth: 420,
      actions: [
        TextButton(
          onPressed: () => _controller.text = defaultDavFileName,
          child: Text(appLocalizations.reset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(appLocalizations.save)),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _controller,
              maxLength: TextInputLimits.fileName,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: appLocalizations.fileName,
                hintText: defaultDavFileName,
              ),
              validator: _validate,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(appLocalizations.textReplacement),
                for (final entry in replacements.entries)
                  Row(
                    spacing: 12,
                    children: [
                      TonalChip(
                        label: '{${entry.key}}',
                        color: context.colorScheme.secondaryContainer,
                        foregroundColor:
                            context.colorScheme.onSecondaryContainer,
                        onPressed: () => _insert(entry.key),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${appLocalizations.preview}: '),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (_, value, _) => Text(
                      _render(value.text),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DAVDirectoryActions extends StatefulWidget {
  final TextEditingController controller;
  final Future<List<String>> Function(String path) loadDirectories;
  final VoidCallback submit;

  const _DAVDirectoryActions({
    required this.controller,
    required this.loadDirectories,
    required this.submit,
  });

  @override
  State<_DAVDirectoryActions> createState() => _DAVDirectoryActionsState();
}

class _DAVDirectoryActionsState extends State<_DAVDirectoryActions> {
  bool _browsing = false;

  Future<void> _browse() async {
    if (_browsing) return;
    setState(() => _browsing = true);
    try {
      final value = await dialogs.showCommonDialog<String>(
        context: context,
        child: DAVDirectoryBrowserDialog(
          directory: DAVDirectory.isValid(widget.controller.text)
              ? DAVDirectory.normalize(widget.controller.text)
              : '/',
          loadDirectories: widget.loadDirectories,
        ),
      );
      if (mounted && value != null) widget.controller.text = value;
    } finally {
      if (mounted) setState(() => _browsing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _browsing ? null : _browse,
          child: Text(appLocalizations.browse),
        ),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: _browsing
                    ? null
                    : () => Navigator.of(context).pop(defaultDavDirectory),
                child: Text(appLocalizations.reset),
              ),
              TextButton(
                onPressed: _browsing ? null : widget.submit,
                child: Text(appLocalizations.submit),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DAVDirectoryBrowserDialog extends StatefulWidget {
  final String directory;
  final Future<List<String>> Function(String path) loadDirectories;

  const DAVDirectoryBrowserDialog({
    super.key,
    required this.directory,
    required this.loadDirectories,
  });

  @override
  State<DAVDirectoryBrowserDialog> createState() =>
      _DAVDirectoryBrowserDialogState();
}

class _DAVDirectoryBrowserDialogState extends State<DAVDirectoryBrowserDialog> {
  late String _directory;
  List<String> _directories = [];
  bool _loading = true;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _directory = DAVDirectory.normalize(widget.directory);
    unawaited(_load(_directory));
  }

  Future<void> _load(String path) async {
    final requestId = ++_requestId;
    setState(() {
      _directory = DAVDirectory.normalize(path);
      _directories = [];
      _error = null;
      _loading = true;
    });
    try {
      final directories = await widget.loadDirectories(_directory);
      if (mounted && requestId == _requestId) {
        setState(() => _directories = directories);
      }
    } catch (error) {
      if (mounted && requestId == _requestId) setState(() => _error = error);
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  void _parent() {
    final segments = _directory
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (segments.isEmpty) return;
    segments.removeLast();
    unawaited(_load('/${segments.join('/')}'));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.browse,
      maxWidth: 360,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _loading || _error != null
              ? null
              : () => Navigator.of(context).pop(_directory),
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _directory,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_directory != '/')
            ListItem(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Symbols.arrow_upward),
              title: Text(appLocalizations.parentDirectory),
              onTap: _parent,
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null) ...[
            Text(userFacingErrorMessage(_error!, appLocalizations)),
            TextButton(
              onPressed: () => _load(_directory),
              child: Text(appLocalizations.retry),
            ),
          ] else if (_directories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  appLocalizations.noDirectories,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final directory in _directories)
              ListItem(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Symbols.folder),
                title: Text(directory),
                onTap: () =>
                    _load(DAVDirectory.normalize('$_directory/$directory')),
              ),
        ],
      ),
    );
  }
}

class RemoteBackupsDialog extends StatefulWidget {
  final List<DAVFile> files;
  final Future<void> Function(String name)? onDelete;

  const RemoteBackupsDialog({super.key, required this.files, this.onDelete});

  @override
  State<RemoteBackupsDialog> createState() => _RemoteBackupsDialogState();
}

class _RemoteBackupsDialogState extends State<RemoteBackupsDialog> {
  late List<DAVFile> _files;
  String? _selected;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _files = [...widget.files];
    _selected = _files.firstOrNull?.name;
  }

  Future<void> _delete() async {
    final name = _selected;
    final onDelete = widget.onDelete;
    if (_deleting || name == null || onDelete == null) return;
    final appLocalizations = context.appLocalizations;
    setState(() => _deleting = true);
    try {
      final confirmed = await dialogs.showMessage(
        context: context,
        title: appLocalizations.delete,
        message: TextSpan(text: appLocalizations.deleteTip(name)),
      );
      if (confirmed != true || !mounted) return;
      final deleted = await globalState.safeRun<bool>(
        () async {
          await onDelete(name);
          return true;
        },
        title: appLocalizations.delete,
        silence: false,
      );
      if (deleted != true || !mounted) return;
      setState(() {
        _files.removeWhere((file) => file.name == name);
        _selected = _files.firstOrNull?.name;
      });
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return PopScope(
      canPop: !_deleting,
      child: CommonDialog(
        title: appLocalizations.selectRemoteBackup,
        maxWidth: 420,
        actions: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.onDelete != null)
                TextButton(
                  onPressed: _deleting || _selected == null ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: context.colorScheme.error,
                  ),
                  child: Text(appLocalizations.delete),
                ),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _deleting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(appLocalizations.cancel),
                    ),
                    TextButton(
                      onPressed: _deleting || _selected == null
                          ? null
                          : () => Navigator.of(context).pop(_selected),
                      child: Text(appLocalizations.confirm),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        child: _files.isEmpty
            ? Text(appLocalizations.noRemoteBackups)
            : RadioGroup<String>(
                groupValue: _selected,
                onChanged: (value) {
                  if (_deleting || value == null) return;
                  setState(() => _selected = value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final file in _files)
                      ListItem.radio(
                        value: file.name,
                        padding: EdgeInsets.zero,
                        title: Text(
                          file.name,
                          style: context.textTheme.bodyMedium,
                        ),
                        subtitle: file.modified == null
                            ? null
                            : Text(
                                file.modified!.toLocal().show,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                        onTap: _deleting
                            ? null
                            : () => setState(() => _selected = file.name),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class WebDAVFormDialog extends ConsumerStatefulWidget {
  final DAVProps? dav;

  const WebDAVFormDialog({super.key, this.dav});

  @override
  ConsumerState<WebDAVFormDialog> createState() => _WebDAVFormDialogState();
}

class _WebDAVFormDialogState extends ConsumerState<WebDAVFormDialog> {
  late TextEditingController _uriController;
  late TextEditingController _userController;
  late TextEditingController _passwordController;
  final _obscureController = ValueNotifier<bool>(true);
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _uriController = TextEditingController(text: widget.dav?.uri);
    _userController = TextEditingController(text: widget.dav?.user);
    _passwordController = TextEditingController(text: widget.dav?.password);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(davSettingProvider.notifier)
        .update(
          (_) => DAVProps(
            uri: _uriController.text,
            user: _userController.text,
            password: _passwordController.text,
            fileName: widget.dav?.fileName ?? defaultDavFileName,
            directory: widget.dav?.directory ?? defaultDavDirectory,
          ),
        );
    Navigator.pop(context);
  }

  void _delete() {
    ref.read(davSettingProvider.notifier).update((_) => null);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _obscureController.dispose();
    _uriController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.webDAVConfiguration,
      actions: [
        if (widget.dav != null)
          TextButton(onPressed: _delete, child: Text(appLocalizations.delete)),
        TextButton(onPressed: _submit, child: Text(appLocalizations.save)),
      ],
      child: Form(
        key: _formKey,
        child: Wrap(
          runSpacing: 16,
          children: [
            TextFormField(
              controller: _uriController,
              inputFormatters: TextInputLimits.limit(TextInputLimits.uri),
              keyboardType: TextInputType.url,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Symbols.link),
                labelText: appLocalizations.address,
                helperText: appLocalizations.addressHelp,
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty || !value.isUrl) {
                  return appLocalizations.addressTip;
                }
                return null;
              },
            ),
            TextFormField(
              controller: _userController,
              inputFormatters: TextInputLimits.limit(TextInputLimits.userName),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Symbols.account_circle),
                labelText: appLocalizations.account,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _obscureController,
              builder: (_, obscure, _) {
                return TextFormField(
                  controller: _passwordController,
                  inputFormatters: TextInputLimits.limit(
                    TextInputLimits.password,
                  ),
                  obscureText: obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    _submit();
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Symbols.password),
                    suffixIcon: IconButton(
                      tooltip: obscure
                          ? context.appLocalizations.showPassword
                          : context.appLocalizations.hidePassword,
                      icon: Icon(
                        obscure ? Symbols.visibility : Symbols.visibility_off,
                      ),
                      onPressed: () {
                        _obscureController.value = !obscure;
                      },
                    ),
                    labelText: appLocalizations.password,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

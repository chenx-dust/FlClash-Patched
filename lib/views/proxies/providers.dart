import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'provider_editor.dart';

typedef UpdatingMap = Map<String, bool>;

class ProvidersView extends ConsumerStatefulWidget {
  const ProvidersView({super.key});

  @override
  ConsumerState<ProvidersView> createState() => _ProvidersViewState();
}

class _ProvidersViewState extends ConsumerState<ProvidersView> {
  Future<void> _updateProviders() async {
    final ref = globalState.container;
    final providers = ref.read(providersProvider);
    final List<UpdatingMessage> messages = [];
    final updateProviders = providers.map<Future>((provider) async {
      final message = await ref
          .read(proxiesActionProvider.notifier)
          .updateProvider(provider);
      if (message.isNotEmpty) {
        messages.add(UpdatingMessage(label: provider.name, message: message));
      }
    });
    await Future.wait(updateProviders);
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
    if (messages.isNotEmpty) {
      globalState.showAllUpdatingMessagesDialog(messages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final providers = ref.watch(providersProvider);
    final proxyProviders = providers
        .where((item) => item.type == 'Proxy')
        .map((item) => ProviderItem(provider: item));
    final ruleProviders = providers
        .where((item) => item.type == 'Rule')
        .map((item) => ProviderItem(provider: item));
    final proxySection = generateSection(
      title: appLocalizations.proxyProviders,
      items: proxyProviders,
    );
    final ruleSection = generateSection(
      title: appLocalizations.ruleProviders,
      items: ruleProviders,
    );
    return AdaptiveSheetScaffold(
      actions: [
        IconButtonData(
          icon: Icons.sync,
          tooltip: appLocalizations.sync,
          onPressed: _updateProviders,
        ),
      ],
      body: generateListView([...proxySection, ...ruleSection]),
      title: appLocalizations.providers,
    );
  }
}

class ProviderItem extends StatelessWidget {
  final ExternalProvider provider;

  const ProviderItem({super.key, required this.provider});

  Future<void> _handleUpdateProvider() async {
    if (provider.vehicleType != 'HTTP') return;
    final ref = globalState.container;
    await globalState.safeRun(() async {
      final message = await ref
          .read(proxiesActionProvider.notifier)
          .updateProvider(provider);
      if (message.isNotEmpty) throw message;
    }, silence: false);
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
  }

  Future<void> _handleSideLoadProvider() async {
    final ref = globalState.container;
    await globalState.safeRun<void>(() async {
      final platformFile = await picker.pickerFile();
      if (platformFile == null || provider.path == null) return;
      final bytes = await platformFile.readBytes();
      await File(provider.path!).safeWriteAsBytes(bytes);
      final providerName = provider.name;
      final message = await coreController.sideLoadExternalProvider(
        providerName: providerName,
        data: utf8.decode(bytes),
      );
      if (message.isNotEmpty) throw message;
      ref
          .read(providersProvider.notifier)
          .setProvider(await coreController.getExternalProvider(provider.name));
      if (message.isNotEmpty) throw message;
    });
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
  }

  Future<void> _handlePreview(BuildContext context) async {
    if (provider.path == null) return;
    BaseNavigator.push<String>(context, ProviderEditorView(provider: provider));
  }

  Future<void> _handleEdit(BuildContext context) async {
    if (provider.path == null) return;
    BaseNavigator.push<String>(
      context,
      ProviderEditorView(provider: provider, editable: true),
    );
  }

  Future<void> _handleExportFile(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    final path = provider.path;
    if (path == null) return;
    final res = await globalState.safeRun<bool>(() async {
      final value = await picker.saveFile(
        provider.name,
        await File(path).readAsBytes(),
        type: FileType.custom,
        allowedExtensions: const ['yaml', 'yml'],
      );
      if (value == null) return false;
      return true;
    }, title: appLocalizations.tip);
    if (res == true && context.mounted) {
      context.showNotifier(appLocalizations.exportSuccess);
    }
  }

  String _buildProviderDesc(BuildContext context) {
    final baseInfo = provider.updateAt.getLastUpdateTimeDesc(context);
    final count = provider.count;
    return switch (count == 0) {
      true => baseInfo,
      false => '$baseInfo  ·  ${context.appLocalizations.entriesCount(count)}',
    };
  }

  Widget _buildPopupMenu(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final hasFile = provider.path != null;
    return CommonPopupMenu(
      items: [
        if (provider.vehicleType == 'HTTP')
          PopupMenuItemData(
            icon: Icons.sync,
            label: appLocalizations.sync,
            onPressed: _handleUpdateProvider,
          ),
        PopupMenuItemData(
          icon: Icons.visibility_outlined,
          label: appLocalizations.preview,
          onPressed: hasFile
              ? () {
                  _handlePreview(context);
                }
              : null,
        ),
        PopupMenuItemData(
          icon: Icons.edit_outlined,
          label: appLocalizations.edit,
          onPressed: hasFile
              ? () {
                  _handleEdit(context);
                }
              : null,
        ),
        PopupMenuItemData(
          icon: Icons.upload,
          label: appLocalizations.upload,
          onPressed: _handleSideLoadProvider,
        ),
        PopupMenuItemData(
          icon: Icons.file_copy_outlined,
          label: appLocalizations.exportFile,
          onPressed: hasFile
              ? () {
                  _handleExportFile(context);
                }
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonPopupBox(
      popup: _buildPopupMenu(context),
      targetBuilder: (open) {
        BuildContext? popupButtonContext;

        void openMenu() {
          open(targetContext: popupButtonContext);
        }

        return GestureDetector(
          onSecondaryTapDown: (_) => openMenu(),
          child: ListItem(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tileTitleAlignment: ListTileTitleAlignment.top,
            trailing: SizedBox(
              height: 40,
              width: 40,
              child: Consumer(
                builder: (context, ref, _) {
                  popupButtonContext = context;
                  final isUpdating = ref.watch(
                    isUpdatingProvider(provider.updatingKey),
                  );
                  return FadeThroughBox(
                    child: isUpdating
                        ? const Padding(
                            key: ValueKey('loading'),
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(),
                          )
                        : IconButton(
                            onPressed: openMenu,
                            icon: const Icon(Icons.more_vert),
                          ),
                  );
                },
              ),
            ),
            title: Text(provider.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (provider.updateAt.microsecondsSinceEpoch > 0)
                  Text(_buildProviderDesc(context)),
                const SizedBox(height: 4),
                if (provider.subscriptionInfo != null)
                  SubscriptionInfoView(
                    subscriptionInfo: provider.subscriptionInfo,
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

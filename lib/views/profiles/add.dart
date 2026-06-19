import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/views/profiles/age_key_generator.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddProfileView extends ConsumerWidget {
  final BuildContext context;

  const AddProfileView({super.key, required this.context});

  Future<void> _handleAddProfileFormFile(WidgetRef ref) async {
    unawaited(ref.read(profilesActionProvider.notifier).addProfileFormFile());
  }

  Future<void> _toScan(WidgetRef ref) async {
    final profilesAction = ref.read(profilesActionProvider.notifier);
    if (system.isDesktop) {
      unawaited(profilesAction.addProfileFormQrCode());
      return;
    }
    final url = await BaseNavigator.push(context, const ScanPage());
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(profilesAction.addProfileFormURL(url));
      });
    }
  }

  Future<void> _toAdd(WidgetRef ref) async {
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final result = await dialogs
        .showCommonDialog<({String url, String? ageSecretKey})>(
          child: const URLFormDialog(),
        );
    if (result != null) {
      unawaited(
        profilesAction.addProfileFormURL(
          result.url,
          ageSecretKey: result.ageSecretKey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    return ListView(
      children: [
        ListItem(
          leading: const Icon(Icons.qr_code_sharp),
          title: Text(appLocalizations.qrcode),
          subtitle: Text(appLocalizations.qrcodeDesc),
          onTap: () => _toScan(ref),
        ),
        ListItem(
          leading: const Icon(Icons.upload_file_sharp),
          title: Text(appLocalizations.file),
          subtitle: Text(appLocalizations.fileDesc),
          onTap: () => _handleAddProfileFormFile(ref),
        ),
        ListItem(
          leading: const Icon(Icons.cloud_download_sharp),
          title: Text(appLocalizations.url),
          subtitle: Text(appLocalizations.urlDesc),
          onTap: () => _toAdd(ref),
        ),
      ],
    );
  }
}

class URLFormDialog extends StatefulWidget {
  const URLFormDialog({super.key});

  @override
  State<URLFormDialog> createState() => _URLFormDialogState();
}

class _URLFormDialogState extends State<URLFormDialog> {
  final _urlController = TextEditingController();
  final _ageSecretKeyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureAgeSecretKey = true;

  void _handleAddProfileFormURL() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final ageSecretKey = _ageSecretKeyController.text.trim();
    Navigator.of(context).pop<({String url, String? ageSecretKey})>((
      url: _urlController.text.trim(),
      ageSecretKey: ageSecretKey.isEmpty ? null : ageSecretKey,
    ));
  }

  Future<void> _showAgeKeyGenerator() async {
    await dialogs.showCommonDialog<void>(child: const AgeKeyGeneratorDialog());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _ageSecretKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.importFromURL,
      actions: [
        IconButton(
          tooltip: appLocalizations.ageKeyGenerateTitle,
          onPressed: _showAgeKeyGenerator,
          icon: const Icon(Icons.key),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _handleAddProfileFormURL,
          child: Text(appLocalizations.submit),
        ),
      ],
      child: SizedBox(
        width: 300,
        child: Form(
          key: _formKey,
          child: Wrap(
            runSpacing: 16,
            children: [
              TextFormField(
                keyboardType: TextInputType.url,
                minLines: 1,
                maxLines: 5,
                inputFormatters: TextInputLimits.limit(TextInputLimits.url),
                controller: _urlController,
                decoration: InputDecoration(labelText: appLocalizations.url),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return appLocalizations.emptyTip('').trim();
                  }
                  if (!value.isUrl) {
                    return appLocalizations.urlTip('').trim();
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _ageSecretKeyController,
                obscureText: _obscureAgeSecretKey,
                decoration: InputDecoration(
                  labelText: appLocalizations.ageSecretKeyOptional,
                  suffixIcon: IconButton(
                    tooltip: _obscureAgeSecretKey
                        ? appLocalizations.showPassword
                        : appLocalizations.hidePassword,
                    onPressed: () {
                      setState(() {
                        _obscureAgeSecretKey = !_obscureAgeSecretKey;
                      });
                    },
                    icon: Icon(
                      _obscureAgeSecretKey
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value?.isNotEmpty == true &&
                      !value!.startsWith('AGE-SECRET-KEY-')) {
                    return appLocalizations.ageSecretKeyInvalidValidationDesc;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

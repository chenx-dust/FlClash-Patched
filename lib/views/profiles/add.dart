import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/age_key_generator.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AddProfileView extends StatelessWidget {
  final BuildContext context;

  const AddProfileView({super.key, required this.context});

  Future<void> _handleAddProfileFormFile() async {
    globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormFile();
  }

  Future<void> _handleAddProfileFormURL(
    String url, {
    String? ageSecretKey,
  }) async {
    globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormURL(url, ageSecretKey: ageSecretKey);
  }

  Future<void> _toScan() async {
    if (system.isDesktop) {
      globalState.container
          .read(profilesActionProvider.notifier)
          .addProfileFormQrCode();
      return;
    }
    final url = await BaseNavigator.push(context, const ScanPage());
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAddProfileFormURL(url);
      });
    }
  }

  Future<void> _toAdd() async {
    final result = await globalState.showCommonDialog<Map<String, String>>(
      child: const URLFormDialog(),
    );
    final url = result?['url'];
    if (url != null) {
      _handleAddProfileFormURL(url, ageSecretKey: result?['ageSecretKey']);
    }
  }

  @override
  Widget build(context) {
    final appLocalizations = context.appLocalizations;
    return ListView(
      children: [
        ListItem(
          leading: const Icon(Icons.qr_code_sharp),
          title: Text(appLocalizations.qrcode),
          subtitle: Text(appLocalizations.qrcodeDesc),
          onTap: _toScan,
        ),
        ListItem(
          leading: const Icon(Icons.upload_file_sharp),
          title: Text(appLocalizations.file),
          subtitle: Text(appLocalizations.fileDesc),
          onTap: _handleAddProfileFormFile,
        ),
        ListItem(
          leading: const Icon(Icons.cloud_download_sharp),
          title: Text(appLocalizations.url),
          subtitle: Text(appLocalizations.urlDesc),
          onTap: _toAdd,
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
  bool _obscureAgeSecretKey = true;

  Future<void> _handleAddProfileFormURL() async {
    final appLocalizations = context.appLocalizations;
    final url = _urlController.value.text.trim();
    if (url.isEmpty) {
      context.showSnackBar(appLocalizations.emptyTip('').trim());
      return;
    }
    if (!url.isUrl) {
      context.showSnackBar(appLocalizations.urlTip('').trim());
      return;
    }
    final ageSecretKey = _ageSecretKeyController.text.trim();
    if (ageSecretKey.isNotEmpty &&
        !ageSecretKey.startsWith('AGE-SECRET-KEY-')) {
      context.showSnackBar(appLocalizations.ageSecretKeyInvalidValidationDesc);
      return;
    }
    Navigator.of(context).pop<Map<String, String>>({
      'url': url,
      if (ageSecretKey.isNotEmpty) 'ageSecretKey': ageSecretKey,
    });
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              tooltip: appLocalizations.generateSecret,
              onPressed: () {
                globalState.showCommonDialog(
                  child: const AgeKeyGeneratorDialog(),
                );
              },
              icon: const Icon(Icons.key),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(appLocalizations.cancel),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _handleAddProfileFormURL,
                  child: Text(appLocalizations.submit),
                ),
              ],
            ),
          ],
        ),
      ],
      child: SizedBox(
        width: 300,
        child: Wrap(
          runSpacing: 16,
          children: [
            TextField(
              keyboardType: TextInputType.url,
              minLines: 1,
              maxLines: 5,
              inputFormatters: TextInputLimits.limit(TextInputLimits.url),
              onSubmitted: (_) {
                _handleAddProfileFormURL();
              },
              onEditingComplete: _handleAddProfileFormURL,
              controller: _urlController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: appLocalizations.url,
              ),
            ),
            TextField(
              textInputAction: TextInputAction.next,
              controller: _ageSecretKeyController,
              obscureText: _obscureAgeSecretKey,
              maxLines: 1,
              minLines: 1,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: appLocalizations.ageSecretKeyOptional,
                hintText: 'AGE-SECRET-KEY-...',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureAgeSecretKey
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureAgeSecretKey = !_obscureAgeSecretKey;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

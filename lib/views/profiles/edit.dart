import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditProfileView extends StatefulWidget {
  final Profile profile;
  final BuildContext context;

  const EditProfileView({
    super.key,
    required this.context,
    required this.profile,
  });

  @override
  State<EditProfileView> createState() => EditProfileViewState();
}

class EditProfileViewState extends State<EditProfileView> {
  late final TextEditingController _labelController;
  late final TextEditingController _urlController;
  late final TextEditingController _autoUpdateDurationController;
  late final TextEditingController _ageSecretKeyController;
  late bool _autoUpdate;
  bool _obscureAgeSecretKey = true;
  String? _rawText;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _fileInfoNotifier = ValueNotifier<FileInfo?>(null);
  Uint8List? _fileData;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.profile.label);
    _urlController = TextEditingController(text: widget.profile.url);
    _autoUpdate = widget.profile.autoUpdate;
    _autoUpdateDurationController = TextEditingController(
      text: widget.profile.autoUpdateDuration.inMinutes.toString(),
    );
    _ageSecretKeyController = TextEditingController(
      text: widget.profile.ageSecretKey,
    );
    _updateFileInfo();
  }

  String? get _ageSecretKey {
    final value = _ageSecretKeyController.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _updateFileInfo() async {
    final file = await widget.profile.file;
    if (!await file.exists()) {
      return;
    }
    final lastModified = await file.lastModified();
    final size = await file.length();
    if (!mounted) {
      return;
    }
    _fileInfoNotifier.value = FileInfo(size: size, lastModified: lastModified);
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    var profile = widget.profile.copyWith(
      url: _urlController.text,
      label: _labelController.text,
      autoUpdate: _autoUpdate,
      ageSecretKey: _ageSecretKey,
      autoUpdateDuration: Duration(
        minutes: int.parse(_autoUpdateDurationController.text),
      ),
    );
    final profilesAction = globalState.container.read(
      profilesActionProvider.notifier,
    );
    final hasUpdate = widget.profile.url != profile.url;
    if (_fileData != null) {
      if (profile.type == ProfileType.url && _autoUpdate) {
        final appLocalizations = context.appLocalizations;
        final res = await globalState.showMessage(
          title: appLocalizations.tip,
          message: TextSpan(text: appLocalizations.profileHasUpdate),
        );
        if (res == true) {
          profile = profile.copyWith(autoUpdate: false);
        }
      }
      profilesAction.putProfile(await profile.saveFile(_fileData!));
    } else if (!hasUpdate) {
      profilesAction.putProfile(profile);
    } else {
      globalState.safeRun(() async {
        await Future.delayed(commonDuration);
        if (hasUpdate) {
          await profilesAction.updateProfile(profile);
        }
      });
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _setAutoUpdate(bool value) {
    if (_autoUpdate == value) return;
    setState(() {
      _autoUpdate = value;
    });
  }

  Future<void> _handleSaveEdit(BuildContext context, String data) async {
    final message = await globalState.safeRun<String>(() async {
      final message = await coreController.validateConfigWithData(
        data,
        ageSecretKey: _ageSecretKey,
      );
      return message;
    }, silence: false);
    if (message?.isNotEmpty == true) {
      globalState.showMessage(
        title: currentAppLocalizations.tip,
        message: TextSpan(text: message),
      );
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pop(data);
    }
  }

  Future<void> _editProfileFile() async {
    if (_rawText == null) {
      final profilePath = await appPath.getProfilePath(
        widget.profile.id.toString(),
      );
      final file = File(profilePath);
      if (await file.exists()) {
        _rawText = await file.readAsString();
      }
    }
    if (!mounted) return;
    final title = widget.profile.label.takeFirstValid([
      widget.profile.id.toString(),
    ]);
    final editorPage = EditorPage(
      title: title,
      content: _rawText!,
      onSave: (context, _, content) {
        _handleSaveEdit(context, content);
      },
      onPop: (context, _, content) async {
        if (content == _rawText) {
          return true;
        }
        final res = await globalState.showMessage(
          title: title,
          message: TextSpan(text: context.appLocalizations.hasCacheChange),
        );
        if (res == true && context.mounted) {
          _handleSaveEdit(context, content);
        } else {
          return true;
        }
        return false;
      },
    );
    final data = await BaseNavigator.push<String>(context, editorPage);
    if (data == null) {
      return;
    }
    _rawText = data;
    _fileData = Uint8List.fromList(utf8.encode(data));
    _fileInfoNotifier.value = _fileInfoNotifier.value?.copyWith(
      size: _fileData?.length ?? 0,
      lastModified: DateTime.now(),
    );
  }

  Future<void> _uploadProfileFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile?.bytes == null) return;
    _fileData = platformFile?.bytes;
    if (!mounted) {
      return;
    }
    _fileInfoNotifier.value = _fileInfoNotifier.value?.copyWith(
      size: _fileData?.length ?? 0,
      lastModified: DateTime.now(),
    );
  }

  Future<void> _handleBack() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.fileIsUpdate),
    );
    if (res == true) {
      _handleConfirm();
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void showAgeKeyGenerator() {
    globalState.showCommonDialog(child: const _AgeKeyGeneratorDialog());
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    _fileInfoNotifier.dispose();
    _autoUpdateDurationController.dispose();
    _ageSecretKeyController.dispose();
    super.dispose();
    globalState.container.read(setupActionProvider.notifier).autoApplyProfile();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final items = [
      ListItem(
        title: TextFormField(
          textInputAction: TextInputAction.next,
          controller: _labelController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: appLocalizations.name,
          ),
          validator: (String? value) {
            if (value == null || value.isEmpty) {
              return appLocalizations.profileNameNullValidationDesc;
            }
            return null;
          },
        ),
      ),
      if (widget.profile.type == ProfileType.url) ...[
        ListItem(
          title: TextFormField(
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
            controller: _urlController,
            maxLines: 5,
            minLines: 1,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: appLocalizations.url,
            ),
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return appLocalizations.profileUrlNullValidationDesc;
              }
              if (!value.isUrl) {
                return appLocalizations.profileUrlInvalidValidationDesc;
              }
              return null;
            },
          ),
        ),
        ListItem(
          title: TextFormField(
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
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return null;
              }
              if (!value.startsWith('AGE-SECRET-KEY-')) {
                return appLocalizations.ageSecretKeyInvalidValidationDesc;
              }
              return null;
            },
          ),
        ),
        ListItem.switchItem(
          title: Text(appLocalizations.autoUpdate),
          delegate: SwitchDelegate<bool>(
            value: _autoUpdate,
            onChanged: _setAutoUpdate,
          ),
        ),
        if (_autoUpdate)
          ListItem(
            title: TextFormField(
              textInputAction: TextInputAction.next,
              controller: _autoUpdateDurationController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: appLocalizations.autoUpdateInterval,
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return appLocalizations
                      .profileAutoUpdateIntervalNullValidationDesc;
                }
                try {
                  int.parse(value);
                } catch (_) {
                  return appLocalizations
                      .profileAutoUpdateIntervalInvalidValidationDesc;
                }
                return null;
              },
            ),
          ),
      ],
      ValueListenableBuilder<FileInfo?>(
        valueListenable: _fileInfoNotifier,
        builder: (_, fileInfo, _) {
          return FadeThroughBox(
            alignment: Alignment.centerLeft,
            child: fileInfo == null
                ? Container()
                : ListItem(
                    title: Text(appLocalizations.profile),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(fileInfo.getDesc(context)),
                        const SizedBox(height: 8),
                        Wrap(
                          runSpacing: 6,
                          spacing: 12,
                          children: [
                            CommonChip(
                              avatar: const Icon(Icons.edit),
                              label: appLocalizations.edit,
                              onPressed: _editProfileFile,
                            ),
                            CommonChip(
                              avatar: const Icon(Icons.upload),
                              label: appLocalizations.upload,
                              onPressed: _uploadProfileFile,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    ];
    return CommonPopScope(
      onPop: (context) {
        if (_fileData == null) {
          return true;
        }
        _handleBack();
        return false;
      },
      child: FloatLayout(
        floatingWidget: FloatWrapper(
          child: FloatingActionButton.extended(
            heroTag: null,
            onPressed: _handleConfirm,
            label: Text(appLocalizations.save),
            icon: const Icon(Icons.save),
          ),
        ),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ListView.separated(
              padding: kMaterialListPadding.copyWith(bottom: 72),
              itemBuilder: (_, index) {
                return items[index];
              },
              separatorBuilder: (_, _) {
                return const SizedBox(height: 24);
              },
              itemCount: items.length,
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeKeyGeneratorDialog extends StatefulWidget {
  const _AgeKeyGeneratorDialog();

  @override
  State<_AgeKeyGeneratorDialog> createState() => _AgeKeyGeneratorDialogState();
}

class _AgeKeyGeneratorDialogState extends State<_AgeKeyGeneratorDialog> {
  late final TextEditingController _privateKeyController;
  late final TextEditingController _publicKeyController;
  bool _generateFromPrivateKey = false;
  String? _helperText;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _privateKeyController = TextEditingController();
    _publicKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _privateKeyController.dispose();
    _publicKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    final appLocalizations = context.appLocalizations;
    setState(() {
      _helperText = null;
      _isGenerating = true;
    });

    try {
      final privateKey = _privateKeyController.text.trim();
      if (_generateFromPrivateKey) {
        if (privateKey.isEmpty || !privateKey.startsWith('AGE-SECRET-KEY-')) {
          setState(() {
            _helperText = appLocalizations.agePrivateKeyRequired;
          });
          return;
        }
        final result = await coreController.convertAgeSecretKeyToPublicKey(
          privateKey,
        );
        if (result.isSuccess && result.data?.isNotEmpty == true) {
          setState(() {
            _publicKeyController.text = result.data!;
          });
        } else {
          setState(() {
            _helperText = result.message.takeFirstValid([
              appLocalizations.agePrivateKeyRequired,
            ]);
          });
        }
        return;
      }

      final keyPair = await coreController.generateAgeKeyPair();
      final secretKey = keyPair['secret-key'] ?? '';
      final publicKey = keyPair['public-key'] ?? '';
      if (secretKey.isNotEmpty && publicKey.isNotEmpty) {
        setState(() {
          _privateKeyController.text = secretKey;
          _publicKeyController.text = publicKey;
          _helperText = appLocalizations.ageKeyPairGeneratedSuccess;
        });
      }
    } catch (e) {
      setState(() {
        _helperText = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      context.showNotifier(context.appLocalizations.copySuccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isError = _helperText == appLocalizations.agePrivateKeyRequired;
    final isSuccess =
        _helperText == appLocalizations.ageKeyPairGeneratedSuccess;
    return CommonDialog(
      title: appLocalizations.ageKeyGenerateTitle,
      maxWidth: 420,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _isGenerating ? null : _handleGenerate,
          child: Text(appLocalizations.generateSecret),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _privateKeyController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelText: appLocalizations.agePrivateKeyLabel,
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyToClipboard(_privateKeyController.text),
              ),
            ),
            onChanged: (_) {
              if (_helperText != null) {
                setState(() {
                  _helperText = null;
                });
              }
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _publicKeyController,
            readOnly: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelText: appLocalizations.agePublicKeyLabel,
              helperText: _helperText,
              helperMaxLines: 2,
              helperStyle: isError
                  ? TextStyle(color: context.colorScheme.error)
                  : isSuccess
                  ? TextStyle(color: context.colorScheme.primary)
                  : null,
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyToClipboard(_publicKeyController.text),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(appLocalizations.generateFromPrivateKey),
            value: _generateFromPrivateKey,
            onChanged: (value) {
              setState(() {
                _generateFromPrivateKey = value;
                _helperText = null;
              });
            },
          ),
        ],
      ),
    );
  }
}

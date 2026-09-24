import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class AgeKeyGeneratorDialog extends ConsumerStatefulWidget {
  const AgeKeyGeneratorDialog({super.key});

  @override
  ConsumerState<AgeKeyGeneratorDialog> createState() =>
      _AgeKeyGeneratorDialogState();
}

class _AgeKeyGeneratorDialogState extends ConsumerState<AgeKeyGeneratorDialog> {
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

  Future<void> _pastePrivateKeyFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    setState(() {
      _privateKeyController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _helperText = null;
    });
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
        final publicKey = await ref
            .read(coreHandlerProvider)
            .convertAgeSecretKeyToPublicKey(privateKey);
        if (!mounted) {
          return;
        }
        if (publicKey.isNotEmpty) {
          setState(() {
            _publicKeyController.text = publicKey;
          });
        } else {
          setState(() {
            _helperText = appLocalizations.agePrivateKeyRequired;
          });
        }
        return;
      }

      final keyPair = await ref.read(coreHandlerProvider).generateAgeKeyPair();
      if (!mounted) {
        return;
      }
      final secretKey = keyPair['secret-key'] ?? '';
      final publicKey = keyPair['public-key'] ?? '';
      if (secretKey.isNotEmpty && publicKey.isNotEmpty) {
        setState(() {
          _privateKeyController.text = secretKey;
          _publicKeyController.text = publicKey;
          _helperText = appLocalizations.ageKeyPairGeneratedSuccess;
        });
      }
    } on CoreMethodException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _helperText = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
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

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isError = _helperText == appLocalizations.agePrivateKeyRequired;
    final isSuccess =
        _helperText == appLocalizations.ageKeyPairGeneratedSuccess;
    return CommonDialog(
      title: appLocalizations.ageKeyGenerateTitle,
      maxWidth: 320,
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
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _privateKeyController,
            decoration: InputDecoration(
              labelText: appLocalizations.agePrivateKeyLabel,
              suffixIcon: IconButton(
                tooltip: _generateFromPrivateKey
                    ? appLocalizations.paste
                    : appLocalizations.copy,
                icon: Icon(_generateFromPrivateKey ? Icons.paste : Icons.copy),
                onPressed: _generateFromPrivateKey
                    ? _pastePrivateKeyFromClipboard
                    : () => copyText(context, _privateKeyController.text),
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
          const SizedBox(height: 16),
          TextField(
            controller: _publicKeyController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: appLocalizations.agePublicKeyLabel,
              helperText: _helperText,
              helperMaxLines: 2,
              helperStyle: isError
                  ? TextStyle(color: context.colorScheme.error)
                  : isSuccess
                  ? TextStyle(color: context.colorScheme.primary)
                  : null,
              suffixIcon: IconButton(
                tooltip: appLocalizations.copy,
                icon: const Icon(Icons.copy),
                onPressed: () => copyText(context, _publicKeyController.text),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListItem.checkbox(
            title: Text(appLocalizations.generateFromPrivateKey),
            value: _generateFromPrivateKey,
            onChanged: (value) {
              setState(() {
                _generateFromPrivateKey = value ?? false;
                _helperText = null;
              });
            },
          ),
        ],
      ),
    );
  }
}

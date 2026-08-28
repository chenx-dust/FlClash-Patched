part of '../general.dart';

class _ExternalControllerDialog extends ConsumerStatefulWidget {
  const _ExternalControllerDialog();

  @override
  ConsumerState<_ExternalControllerDialog> createState() =>
      _ExternalControllerDialogState();
}

class _ExternalControllerDialogState
    extends ConsumerState<_ExternalControllerDialog> {
  static const _secretCharacters =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _portController;
  late final TextEditingController _secretController;
  late bool _enabled;
  late bool _allowLan;

  @override
  void initState() {
    super.initState();
    final config = ref.read(patchClashConfigProvider);
    final externalController = config.externalController;
    _enabled = externalController.isNotEmpty;
    _allowLan = _enabled && !externalController.startsWith('$localhost:');
    final port = int.tryParse(externalController.split(':').last);
    _portController = TextEditingController(
      text: (port ?? defaultExternalControllerPort).toString(),
    );
    _secretController = TextEditingController(text: config.secret);
  }

  void _handleRandomSecret() {
    final random = Random.secure();
    _secretController.text = List.generate(
      16,
      (_) => _secretCharacters[random.nextInt(_secretCharacters.length)],
    ).join();
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() == false) {
      return;
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            externalController: _enabled
                ? '${_allowLan ? '0.0.0.0' : localhost}:${_portController.text}'
                : '',
            secret: _secretController.text,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _portController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.externalController,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _handleSubmit,
          child: Text(appLocalizations.submit),
        ),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(appLocalizations.enableExternalController),
              value: _enabled,
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(appLocalizations.allowLanAccess),
              subtitle: Text(appLocalizations.allowLanAccessDesc),
              value: _allowLan,
              onChanged: !_enabled
                  ? null
                  : (value) {
                      setState(() {
                        _allowLan = value;
                      });
                    },
            ),
            TextFormField(
              enabled: _enabled,
              keyboardType: TextInputType.number,
              maxLines: 1,
              minLines: 1,
              inputFormatters: TextInputLimits.digitsOnly(TextInputLimits.port),
              controller: _portController,
              onFieldSubmitted: (_) {
                _handleSubmit();
              },
              decoration: InputDecoration(
                labelText: appLocalizations.listeningPort,
              ),
              validator: (value) {
                if (!_enabled) {
                  return null;
                }
                if (value == null || value.isEmpty) {
                  return appLocalizations.emptyTip(
                    appLocalizations.listeningPort,
                  );
                }
                final port = int.tryParse(value);
                if (port == null) {
                  return appLocalizations.numberTip(
                    appLocalizations.listeningPort,
                  );
                }
                if (port < _minPort || port > _maxPort) {
                  return appLocalizations.portTip(
                    appLocalizations.listeningPort,
                  );
                }
                return null;
              },
            ),
            TextFormField(
              enabled: _enabled,
              maxLines: 1,
              minLines: 1,
              inputFormatters: TextInputLimits.limit(TextInputLimits.password),
              controller: _secretController,
              decoration: InputDecoration(
                labelText: appLocalizations.password,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: appLocalizations.random,
                      onPressed: _handleRandomSecret,
                      icon: const Icon(Icons.casino_outlined),
                    ),
                    IconButton(
                      tooltip: appLocalizations.copy,
                      onPressed: () {
                        copyText(context, _secretController.text);
                      },
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

part of 'application_setting.dart';

class ForegroundTickerIntervalItem extends ConsumerWidget {
  const ForegroundTickerIntervalItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final setting = ref.watch(
      appSettingProvider.select(
        (state) => (
          interval: state.foregroundTickerInterval,
          idleWhenUnfocused: state.foregroundTickerIdleWhenUnfocused,
          idleInterval: state.foregroundTickerIdleInterval,
        ),
      ),
    );
    final interval = '${setting.interval} ${appLocalizations.seconds}';
    final idleInterval = '${setting.idleInterval} ${appLocalizations.seconds}';
    final subtitle = setting.idleWhenUnfocused
        ? appLocalizations.uiUpdateIntervalDesc(interval, idleInterval)
        : appLocalizations.uiUpdateIntervalIdleDisabledDesc(interval);
    return ListItem(
      title: Text(appLocalizations.uiUpdateInterval),
      subtitle: Text(subtitle),
      onTap: () {
        dialogs.showCommonDialog<void>(
          child: const _ForegroundTickerIntervalDialog(),
        );
      },
    );
  }
}

class _ForegroundTickerIntervalDialog extends ConsumerStatefulWidget {
  const _ForegroundTickerIntervalDialog();

  @override
  ConsumerState<_ForegroundTickerIntervalDialog> createState() {
    return _ForegroundTickerIntervalDialogState();
  }
}

class _ForegroundTickerIntervalDialogState
    extends ConsumerState<_ForegroundTickerIntervalDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _intervalController;
  late final TextEditingController _idleIntervalController;
  late bool _idleWhenUnfocused;

  @override
  void initState() {
    super.initState();
    final appSetting = ref.read(appSettingProvider);
    _intervalController = TextEditingController(
      text: appSetting.foregroundTickerInterval.toString(),
    );
    _idleIntervalController = TextEditingController(
      text: appSetting.foregroundTickerIdleInterval.toString(),
    );
    _idleWhenUnfocused = appSetting.foregroundTickerIdleWhenUnfocused;
  }

  String? _validateSeconds(String? value) {
    final appLocalizations = context.appLocalizations;
    if (value == null || value.isEmpty) {
      return appLocalizations.emptyTip(appLocalizations.interval);
    }
    final intValue = int.tryParse(value);
    if (intValue == null) {
      return appLocalizations.numberTip(appLocalizations.interval);
    }
    if (intValue <= 0) {
      return appLocalizations.positiveIntegerTip;
    }
    return null;
  }

  void _handleReset() {
    setState(() {
      _intervalController.text = defaultForegroundTickerInterval.toString();
      _idleIntervalController.text = defaultForegroundTickerIdleInterval
          .toString();
      _idleWhenUnfocused = true;
    });
  }

  void _handleUpdate() {
    if (_formKey.currentState?.validate() == false) {
      return;
    }
    ref
        .read(appSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            foregroundTickerInterval: int.parse(_intervalController.text),
            foregroundTickerIdleWhenUnfocused: _idleWhenUnfocused,
            foregroundTickerIdleInterval: int.parse(
              _idleIntervalController.text,
            ),
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _idleIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.uiUpdateInterval,
      actions: [
        TextButton(
          onPressed: _handleReset,
          child: Text(appLocalizations.reset),
        ),
        TextButton(
          onPressed: _handleUpdate,
          child: Text(appLocalizations.submit),
        ),
      ],
      child: Form(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            TextFormField(
              keyboardType: TextInputType.number,
              maxLines: 1,
              minLines: 1,
              inputFormatters: TextInputLimits.digitsOnly(
                TextInputLimits.interval,
              ),
              controller: _intervalController,
              onFieldSubmitted: (_) {
                _handleUpdate();
              },
              decoration: InputDecoration(
                labelText: appLocalizations.uiUpdateInterval,
                suffixText: appLocalizations.seconds,
              ),
              validator: _validateSeconds,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(appLocalizations.uiUpdateIdleWhenUnfocused),
              subtitle: Text(appLocalizations.uiUpdateIdleWhenUnfocusedDesc),
              value: _idleWhenUnfocused,
              onChanged: (value) {
                setState(() {
                  _idleWhenUnfocused = value;
                });
              },
            ),
            AnimatedSize(
              duration: midDuration,
              curve: Curves.easeOutQuad,
              alignment: Alignment.topCenter,
              child: _idleWhenUnfocused
                  ? TextFormField(
                      keyboardType: TextInputType.number,
                      maxLines: 1,
                      minLines: 1,
                      inputFormatters: TextInputLimits.digitsOnly(
                        TextInputLimits.interval,
                      ),
                      controller: _idleIntervalController,
                      onFieldSubmitted: (_) {
                        _handleUpdate();
                      },
                      decoration: InputDecoration(
                        labelText: appLocalizations.uiUpdateIdleInterval,
                        suffixText: appLocalizations.seconds,
                      ),
                      validator: _validateSeconds,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

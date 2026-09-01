import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

ConfigToggleItem _appSettingToggle({
  required ConfigLabel title,
  required ConfigLabel subtitle,
  required bool Function(AppSettingProps state) select,
  required AppSettingProps Function(AppSettingProps state, bool value) update,
}) {
  return ConfigToggleItem(
    title: title,
    subtitle: subtitle,
    selector: appSettingProvider.select(select),
    onChanged: (ref, value) => ref
        .read(appSettingProvider.notifier)
        .update((state) => update(state, value)),
  );
}

class ApplicationSettingView extends ConsumerWidget {
  const ApplicationSettingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closeConnections = ref.watch(
      appSettingProvider.select((state) => state.closeConnections),
    );
    final items = <Widget>[
      _appSettingToggle(
        title: (l) => l.minimizeOnExit,
        subtitle: (l) => l.minimizeOnExitDesc,
        select: (state) => state.minimizeOnExit,
        update: (state, value) => state.copyWith(minimizeOnExit: value),
      ),
      if (system.isDesktop) ...[
        _appSettingToggle(
          title: (l) => l.autoLaunch,
          subtitle: (l) => l.autoLaunchDesc,
          select: (state) => state.autoLaunch,
          update: (state, value) => state.copyWith(
            autoLaunch: value,
            highPriorityAutoLaunch: value
                ? state.highPriorityAutoLaunch
                : false,
          ),
        ),
        if (system.isWindows &&
            ref.watch(appSettingProvider.select((state) => state.autoLaunch)))
          _appSettingToggle(
            title: (l) => l.highPriorityAutoLaunch,
            subtitle: (l) => l.highPriorityAutoLaunchDesc,
            select: (state) => state.highPriorityAutoLaunch,
            update: (state, value) =>
                state.copyWith(autoLaunch: true, highPriorityAutoLaunch: value),
          ),
        _appSettingToggle(
          title: (l) => l.silentLaunch,
          subtitle: (l) => l.silentLaunchDesc,
          select: (state) => state.silentLaunch,
          update: (state, value) => state.copyWith(silentLaunch: value),
        ),
      ],
      _appSettingToggle(
        title: (l) => l.autoRun,
        subtitle: (l) => l.autoRunDesc,
        select: (state) => state.autoRun,
        update: (state, value) => state.copyWith(autoRun: value),
      ),
      if (system.isAndroid)
        _appSettingToggle(
          title: (l) => l.exclude,
          subtitle: (l) => l.excludeDesc,
          select: (state) => state.hidden,
          update: (state, value) => state.copyWith(hidden: value),
        ),
      _appSettingToggle(
        title: (l) => l.tabAnimation,
        subtitle: (l) => l.tabAnimationDesc,
        select: (state) => state.isAnimateToPage,
        update: (state, value) => state.copyWith(isAnimateToPage: value),
      ),
      _appSettingToggle(
        title: (l) => l.swipeToSwitchPage,
        subtitle: (l) => l.tabAnimationDesc,
        select: (state) => state.isSwipeToPage,
        update: (state, value) => state.copyWith(isSwipeToPage: value),
      ),
      _appSettingToggle(
        title: (l) => l.logcat,
        subtitle: (l) => l.logcatDesc,
        select: (state) => state.openLogs,
        update: (state, value) => state.copyWith(openLogs: value),
      ),
      _appSettingToggle(
        title: (l) => l.autoCloseConnections,
        subtitle: (l) => l.autoCloseConnectionsDesc,
        select: (state) => state.closeConnections,
        update: (state, value) => state.copyWith(closeConnections: value),
      ),
      if (!closeConnections)
        _appSettingToggle(
          title: (l) => l.promptCloseConnections,
          subtitle: (l) => l.promptCloseConnectionsDesc,
          select: (state) => state.promptCloseConnections,
          update: (state, value) =>
              state.copyWith(promptCloseConnections: value),
        ),
      _appSettingToggle(
        title: (l) => l.onlyStatisticsProxy,
        subtitle: (l) => l.onlyStatisticsProxyDesc,
        select: (state) => state.onlyStatisticsProxy,
        update: (state, value) => state.copyWith(onlyStatisticsProxy: value),
      ),
      if (system.isAndroid || system.isMacOS)
        ConfigToggleItem(
          title: (l) => l.networkSpeedNotification,
          subtitle: (l) => l.networkSpeedNotificationDesc,
          selector: vpnSettingProvider.select(
            (state) => state.networkSpeedNotification,
          ),
          onChanged: (ref, value) => ref
              .read(vpnSettingProvider.notifier)
              .update(
                (state) => state.copyWith(networkSpeedNotification: value),
              ),
        ),
      _appSettingToggle(
        title: (l) => l.autoCheckUpdate,
        subtitle: (l) => l.autoCheckUpdateDesc,
        select: (state) => state.autoCheckUpdate,
        update: (state, value) => state.copyWith(autoCheckUpdate: value),
      ),
      _appSettingToggle(
        title: (l) => l.checkCertificate,
        subtitle: (l) => l.checkCertificateDesc,
        select: (state) => state.checkCertificate,
        update: (state, value) => state.copyWith(checkCertificate: value),
      ),
      const _ForegroundTickerIntervalItem(),
    ];
    return BaseScaffold(
      title: context.appLocalizations.application,
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: 20),
        itemBuilder: (_, index) => items[index],
        separatorBuilder: (_, _) => const Divider(height: 0),
        itemCount: items.length,
      ),
    );
  }
}

class _ForegroundTickerIntervalItem extends ConsumerWidget {
  const _ForegroundTickerIntervalItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(
      appSettingProvider.select(
        (state) => (
          state.foregroundTickerInterval,
          state.foregroundTickerIdleWhenUnfocused,
          state.foregroundTickerIdleInterval,
        ),
      ),
    );
    final l = context.appLocalizations;
    final interval = '${setting.$1} ${l.seconds}';
    final idleInterval = '${setting.$3} ${l.seconds}';
    return ListItem(
      title: Text(l.uiUpdateInterval),
      subtitle: Text(
        setting.$2
            ? l.uiUpdateIntervalDesc(interval, idleInterval)
            : l.uiUpdateIntervalIdleDisabledDesc(interval),
      ),
      onTap: () => dialogs.showCommonDialog<void>(
        child: const _ForegroundTickerIntervalDialog(),
      ),
    );
  }
}

class _ForegroundTickerIntervalDialog extends ConsumerStatefulWidget {
  const _ForegroundTickerIntervalDialog();

  @override
  ConsumerState<_ForegroundTickerIntervalDialog> createState() =>
      _ForegroundTickerIntervalDialogState();
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
    final setting = ref.read(appSettingProvider);
    _intervalController = TextEditingController(
      text: setting.foregroundTickerInterval.toString(),
    );
    _idleIntervalController = TextEditingController(
      text: setting.foregroundTickerIdleInterval.toString(),
    );
    _idleWhenUnfocused = setting.foregroundTickerIdleWhenUnfocused;
  }

  String? _validateSeconds(String? value) {
    final l = context.appLocalizations;
    if (value == null || value.isEmpty) return l.emptyTip(l.interval);
    if (int.tryParse(value) == null) return l.numberTip(l.interval);
    return int.parse(value) > 0 ? null : l.positiveIntegerTip;
  }

  void _reset() {
    setState(() {
      _intervalController.text = defaultForegroundTickerInterval.toString();
      _idleIntervalController.text = defaultForegroundTickerIdleInterval
          .toString();
      _idleWhenUnfocused = true;
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() == false) return;
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
    final l = context.appLocalizations;
    return CommonDialog(
      title: l.uiUpdateInterval,
      actions: [
        TextButton(onPressed: _reset, child: Text(l.reset)),
        TextButton(onPressed: _submit, child: Text(l.submit)),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            TextFormField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l.uiUpdateInterval,
                suffixText: l.seconds,
              ),
              validator: _validateSeconds,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.uiUpdateIdleWhenUnfocused),
              subtitle: Text(l.uiUpdateIdleWhenUnfocusedDesc),
              value: _idleWhenUnfocused,
              onChanged: (value) => setState(() => _idleWhenUnfocused = value),
            ),
            AnimatedSize(
              duration: midDuration,
              curve: Curves.easeOutQuad,
              alignment: Alignment.topCenter,
              child: _idleWhenUnfocused
                  ? TextFormField(
                      controller: _idleIntervalController,
                      keyboardType: TextInputType.number,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l.uiUpdateIdleInterval,
                        suffixText: l.seconds,
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

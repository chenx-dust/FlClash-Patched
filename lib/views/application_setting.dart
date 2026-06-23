import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CloseConnectionsItem extends ConsumerWidget {
  const CloseConnectionsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final closeConnections = ref.watch(
      appSettingProvider.select((state) => state.closeConnections),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCloseConnections),
      subtitle: Text(appLocalizations.autoCloseConnectionsDesc),
      delegate: SwitchDelegate(
        value: closeConnections,
        onChanged: (value) async {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(closeConnections: value));
        },
      ),
    );
  }
}

class UsageItem extends ConsumerWidget {
  const UsageItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final onlyStatisticsProxy = ref.watch(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.onlyStatisticsProxy),
      subtitle: Text(appLocalizations.onlyStatisticsProxyDesc),
      delegate: SwitchDelegate(
        value: onlyStatisticsProxy,
        onChanged: (bool value) async {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(onlyStatisticsProxy: value));
        },
      ),
    );
  }
}

class NetworkSpeedNotificationItem extends ConsumerWidget {
  const NetworkSpeedNotificationItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final networkSpeedNotification = ref.watch(
      vpnSettingProvider.select((state) => state.networkSpeedNotification),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.networkSpeedNotification),
      subtitle: Text(appLocalizations.networkSpeedNotificationDesc),
      delegate: SwitchDelegate(
        value: networkSpeedNotification,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update(
                (state) => state.copyWith(networkSpeedNotification: value),
              );
        },
      ),
    );
  }
}

class MinimizeItem extends ConsumerWidget {
  const MinimizeItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final minimizeOnExit = ref.watch(
      appSettingProvider.select((state) => state.minimizeOnExit),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.minimizeOnExit),
      subtitle: Text(appLocalizations.minimizeOnExitDesc),
      delegate: SwitchDelegate(
        value: minimizeOnExit,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(minimizeOnExit: value));
        },
      ),
    );
  }
}

class AutoLaunchItem extends ConsumerWidget {
  const AutoLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final autoLaunch = ref.watch(
      appSettingProvider.select((state) => state.autoLaunch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoLaunch),
      subtitle: Text(appLocalizations.autoLaunchDesc),
      delegate: SwitchDelegate(
        value: autoLaunch,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update(
                (state) => state.copyWith(
                  autoLaunch: value,
                  highPriorityAutoLaunch: false,
                ),
              );
        },
      ),
    );
  }
}

class HighPriorityAutoLaunchItem extends ConsumerWidget {
  const HighPriorityAutoLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final highPriorityAutoLaunch = ref.watch(
      appSettingProvider.select((state) => state.highPriorityAutoLaunch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.highPriorityAutoLaunch),
      subtitle: Text(appLocalizations.highPriorityAutoLaunchDesc),
      delegate: SwitchDelegate(
        value: highPriorityAutoLaunch,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update(
                (state) => state.copyWith(
                  autoLaunch: true,
                  highPriorityAutoLaunch: value,
                ),
              );
        },
      ),
    );
  }
}

class SilentLaunchItem extends ConsumerWidget {
  const SilentLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final silentLaunch = ref.watch(
      appSettingProvider.select((state) => state.silentLaunch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.silentLaunch),
      subtitle: Text(appLocalizations.silentLaunchDesc),
      delegate: SwitchDelegate(
        value: silentLaunch,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(silentLaunch: value));
        },
      ),
    );
  }
}

class AutoRunItem extends ConsumerWidget {
  const AutoRunItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final autoRun = ref.watch(
      appSettingProvider.select((state) => state.autoRun),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoRun),
      subtitle: Text(appLocalizations.autoRunDesc),
      delegate: SwitchDelegate(
        value: autoRun,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(autoRun: value));
        },
      ),
    );
  }
}

class HiddenItem extends ConsumerWidget {
  const HiddenItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hidden),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.exclude),
      subtitle: Text(appLocalizations.excludeDesc),
      delegate: SwitchDelegate(
        value: hidden,
        onChanged: (value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(hidden: value));
        },
      ),
    );
  }
}

class AnimateTabItem extends ConsumerWidget {
  const AnimateTabItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isAnimateToPage = ref.watch(
      appSettingProvider.select((state) => state.isAnimateToPage),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.tabAnimation),
      subtitle: Text(appLocalizations.tabAnimationDesc),
      delegate: SwitchDelegate(
        value: isAnimateToPage,
        onChanged: (value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(isAnimateToPage: value));
        },
      ),
    );
  }
}

class OpenLogsItem extends ConsumerWidget {
  const OpenLogsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final openLogs = ref.watch(
      appSettingProvider.select((state) => state.openLogs),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.logcat),
      subtitle: Text(appLocalizations.logcatDesc),
      delegate: SwitchDelegate(
        value: openLogs,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(openLogs: value));
        },
      ),
    );
  }
}

class AutoCheckUpdateItem extends ConsumerWidget {
  const AutoCheckUpdateItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final autoCheckUpdate = ref.watch(
      appSettingProvider.select((state) => state.autoCheckUpdate),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCheckUpdate),
      subtitle: Text(appLocalizations.autoCheckUpdateDesc),
      delegate: SwitchDelegate(
        value: autoCheckUpdate,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(autoCheckUpdate: value));
        },
      ),
    );
  }
}

class ForegroundTickerIntervalItem extends ConsumerWidget {
  const ForegroundTickerIntervalItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final setting = ref.watch(
      appSettingProvider.select(
        (state) => (
          state.foregroundTickerInterval,
          state.foregroundTickerIdleWhenUnfocused,
          state.foregroundTickerIdleInterval,
        ),
      ),
    );
    final interval = '${setting.$1} ${appLocalizations.seconds}';
    final idleInterval = '${setting.$3} ${appLocalizations.seconds}';
    final subtitle = setting.$2
        ? appLocalizations.uiUpdateIntervalDesc(interval, idleInterval)
        : appLocalizations.uiUpdateIntervalIdleDisabledDesc(interval);
    return ListItem(
      title: Text(appLocalizations.uiUpdateInterval),
      subtitle: Text(subtitle),
      onTap: () {
        globalState.showCommonDialog(
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
      _idleIntervalController.text =
          defaultForegroundTickerIdleInterval.toString();
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
              controller: _intervalController,
              onFieldSubmitted: (_) {
                _handleUpdate();
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: appLocalizations.uiUpdateInterval,
                suffixText: appLocalizations.seconds,
              ),
              validator: _validateSeconds,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(appLocalizations.uiUpdateIdleWhenUnfocused),
              subtitle: Text(
                appLocalizations.uiUpdateIdleWhenUnfocusedDesc,
              ),
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
                      controller: _idleIntervalController,
                      onFieldSubmitted: (_) {
                        _handleUpdate();
                      },
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
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

class ApplicationSettingView extends ConsumerWidget {
  const ApplicationSettingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showHighPriorityAutoLaunch =
        system.isWindows &&
        ref.watch(appSettingProvider.select((state) => state.autoLaunch));
    final List<Widget> items = [
      const MinimizeItem(),
      if (system.isDesktop) ...[
        const AutoLaunchItem(),
        if (showHighPriorityAutoLaunch) const HighPriorityAutoLaunchItem(),
        const SilentLaunchItem(),
      ],
      const AutoRunItem(),
      if (system.isAndroid) ...[const HiddenItem()],
      const AnimateTabItem(),
      const OpenLogsItem(),
      const ForegroundTickerIntervalItem(),
      const CloseConnectionsItem(),
      const UsageItem(),
      if (system.isAndroid) const NetworkSpeedNotificationItem(),
      const AutoCheckUpdateItem(),
    ];
    return BaseScaffold(
      title: context.appLocalizations.application,
      body: ListView.separated(
        itemBuilder: (_, index) {
          final item = items[index];
          return item;
        },
        separatorBuilder: (_, _) {
          return const Divider(height: 0);
        },
        itemCount: items.length,
      ),
    );
  }
}

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'foreground_ticker_dialog.dart';

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

ConfigToggleItem _vpnSettingToggle({
  required ConfigLabel title,
  required ConfigLabel subtitle,
  required bool Function(VpnProps state) select,
  required VpnProps Function(VpnProps state, bool value) update,
}) {
  return ConfigToggleItem(
    title: title,
    subtitle: subtitle,
    selector: vpnSettingProvider.select(select),
    onChanged: (ref, value) => ref
        .read(vpnSettingProvider.notifier)
        .update((state) => update(state, value)),
  );
}

class ApplicationSettingView extends ConsumerWidget {
  const ApplicationSettingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showHighPriorityAutoLaunch =
        system.isWindows &&
        ref.watch(appSettingProvider.select((state) => state.autoLaunch));
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
          update: (state, value) =>
              state.copyWith(autoLaunch: value, highPriorityAutoLaunch: false),
        ),
        if (showHighPriorityAutoLaunch)
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
      const ForegroundTickerIntervalItem(),
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
      if (system.isAndroid)
        _vpnSettingToggle(
          title: (l) => l.networkSpeedNotification,
          subtitle: (l) => l.networkSpeedNotificationDesc,
          select: (state) => state.networkSpeedNotification,
          update: (state, value) =>
              state.copyWith(networkSpeedNotification: value),
        ),
      _appSettingToggle(
        title: (l) => l.autoCheckUpdate,
        subtitle: (l) => l.autoCheckUpdateDesc,
        select: (state) => state.autoCheckUpdate,
        update: (state, value) => state.copyWith(autoCheckUpdate: value),
      ),
      _appSettingToggle(
        title: (l) => l.ignoreCertificateErrors,
        subtitle: (l) => l.ignoreCertificateErrorsDesc,
        select: (state) => state.ignoreCertificateErrors,
        update: (state, value) =>
            state.copyWith(ignoreCertificateErrors: value),
      ),
    ];
    return BaseScaffold(
      title: context.appLocalizations.application,
      body: ListView.separated(
        itemBuilder: (_, index) => items[index],
        separatorBuilder: (_, _) => const Divider(height: 0),
        itemCount: items.length,
      ),
    );
  }
}

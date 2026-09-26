import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/config/on_demand.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'general/port_dialog.dart';
part 'general/ua_dialog.dart';

List<String> _parseHostsValue(String value) {
  return value.splitByMultipleSeparatorsList;
}

String _serializeHostsValue(List<String> values) {
  return values.join(',');
}

Widget _buildHostsSubtitle(MapEntry<String, String> item) {
  return Text(_parseHostsValue(item.value).join('\n'));
}

class LogLevelItem extends ConsumerWidget {
  const LogLevelItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigOptionsItem<LogLevel>(
      title: (l) => l.logLevel,
      options: LogLevel.values,
      textBuilder: (logLevel) => logLevel.name.toUpperCase(),
      selector: patchClashConfigProvider.select((state) => state.logLevel),
      onChanged: (ref, value) => ref
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(logLevel: value)),
    );
  }
}

class UaItem extends ConsumerWidget {
  const UaItem({super.key});

  Future<void> _handleShowUaDialog(WidgetRef ref) async {
    final result = await dialogs.showCommonDialog<_UaDialogResult>(
      child: _UaDialog(
        value: ref.read(patchClashConfigProvider).globalUa,
        customValue: ref.read(appSettingProvider).customUserAgent,
      ),
    );
    if (result == null) {
      return;
    }
    final userAgent = result.value.trim();
    if (result.isCustom) {
      ref
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(customUserAgent: userAgent));
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) =>
              state.copyWith(globalUa: userAgent.isEmpty ? null : userAgent),
        );
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final globalUa = ref.watch(
      patchClashConfigProvider.select((state) => state.globalUa),
    );
    return ListItem(
      title: Text(appLocalizations.userAgent),
      subtitle: Text(globalUa ?? appLocalizations.defaultText),
      onTap: () => _handleShowUaDialog(ref),
    );
  }
}

class KeepAliveIntervalItem extends ConsumerWidget {
  const KeepAliveIntervalItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final keepAliveInterval = ref.watch(
      patchClashConfigProvider.select((state) => state.keepAliveInterval),
    );
    return ListItem.input(
      title: Text(appLocalizations.keepAliveIntervalDesc),
      subtitle: Text(appLocalizations.secondsCount(keepAliveInterval)),
      dialogTitle: appLocalizations.keepAliveIntervalDesc,
      suffixText: appLocalizations.seconds,
      resetValue: '$defaultKeepAliveInterval',
      value: '$keepAliveInterval',
      maxLength: TextInputLimits.interval,
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return appLocalizations.emptyTip(appLocalizations.interval);
        }
        final intValue = int.tryParse(value);
        if (intValue == null) {
          return appLocalizations.numberTip(appLocalizations.interval);
        }
        return null;
      },
      onChanged: (String? value) {
        if (value == null) {
          return;
        }
        final intValue = int.parse(value);
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(keepAliveInterval: intValue));
      },
    );
  }
}

class TestUrlItem extends ConsumerWidget {
  const TestUrlItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final testUrl = ref.watch(
      appSettingProvider.select((state) => state.testUrl),
    );
    return ListItem.input(
      title: Text(appLocalizations.testUrl),
      subtitle: Text(testUrl),
      resetValue: defaultTestUrl,
      dialogTitle: appLocalizations.testUrl,
      value: testUrl,
      maxLength: TextInputLimits.url,
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return appLocalizations.emptyTip(appLocalizations.testUrl);
        }
        if (!value.isUrl) {
          return appLocalizations.urlTip(appLocalizations.testUrl);
        }
        return null;
      },
      onChanged: (String? value) {
        if (value == null) {
          return;
        }
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(testUrl: value));
      },
    );
  }
}

class PortItem extends ConsumerWidget {
  const PortItem({super.key});

  Future<void> handleShowPortDialog() async {
    await dialogs.showCommonDialog(child: const _PortDialog());
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final mixedPort = ref.watch(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    return ListItem(
      title: Text(appLocalizations.port),
      subtitle: Text('$mixedPort'),
      onTap: () {
        handleShowPortDialog();
      },
    );
  }
}

class HostsItem extends ConsumerWidget {
  const HostsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final hosts = ref.watch(
      patchClashConfigProvider.select((state) => state.hosts),
    );
    return ListItem.open(
      title: const Text('Hosts'),
      subtitle: Text(appLocalizations.hostsDesc),
      blur: false,
      widget: MapInputPage(
        title: 'Hosts',
        map: hosts,
        keyLabel: appLocalizations.domain,
        keyMaxLength: TextInputLimits.domain,
        valueMaxLength: TextInputLimits.hostValue,
        valueParser: _parseHostsValue,
        valueSerializer: _serializeHostsValue,
        titleBuilder: (item) => Text(item.key),
        subtitleBuilder: _buildHostsSubtitle,
      ),
      onChanged: (value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(hosts: value));
      },
    );
  }
}

class AuthenticationItem extends ConsumerWidget {
  const AuthenticationItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigToggleItem(
      title: (l) => l.authentication,
      subtitle: (l) => l.authenticationDesc,
      selector: networkSettingProvider.select(
        (state) => state.authentication.enable,
      ),
      onChanged: (ref, value) =>
          ref.read(networkSettingProvider.notifier).update((state) {
            var authentication = state.authentication.copyWith(enable: value);
            if (value && authentication.username.isEmpty) {
              authentication = authentication.copyWith(
                username: generateRandomSecret(8),
                password: generateRandomSecret(16),
              );
            }
            return state.copyWith(authentication: authentication);
          }),
    );
  }
}

class AuthenticationAccountItem extends ConsumerWidget {
  const AuthenticationAccountItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigTextItem(
      title: (l) => l.account,
      maxLength: TextInputLimits.userName,
      selector: networkSettingProvider.select(
        (state) => state.authentication.username,
      ),
      // mihomo and the Dart proxy string both split user:pass on the first
      // colon, so a colon in the username breaks authentication.
      normalize: (value) => value.trim().replaceAll(':', ''),
      onChanged: (ref, value) => ref
          .read(networkSettingProvider.notifier)
          .update((state) => state.copyWith.authentication(username: value)),
    );
  }
}

class AuthenticationPasswordItem extends ConsumerWidget {
  const AuthenticationPasswordItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigTextItem(
      title: (l) => l.password,
      maxLength: TextInputLimits.password,
      selector: networkSettingProvider.select(
        (state) => state.authentication.password,
      ),
      normalize: (value) => value.trim(),
      onChanged: (ref, value) => ref
          .read(networkSettingProvider.notifier)
          .update((state) => state.copyWith.authentication(password: value)),
    );
  }
}

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

ConfigToggleItem _clashToggle({
  required ConfigLabel title,
  required ConfigLabel subtitle,
  required bool Function(PatchClashConfig state) select,
  required PatchClashConfig Function(PatchClashConfig state, bool value) update,
}) {
  return ConfigToggleItem(
    title: title,
    subtitle: subtitle,
    selector: patchClashConfigProvider.select(select),
    onChanged: (ref, value) => ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => update(state, value)),
  );
}

class GeneralView extends ConsumerWidget {
  const GeneralView({super.key});

  List<Widget> _startupItems(
    AppLocalizations appLocalizations, {
    required bool autoLaunch,
  }) {
    return [
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
        if (system.isWindows && autoLaunch)
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
      ListItem.open(
        title: Text(appLocalizations.onDemand),
        subtitle: Text(appLocalizations.onDemandDesc),
        blur: false,
        widget: const OnDemandView(),
      ),
      _appSettingToggle(
        title: (l) => l.minimizeOnExit,
        subtitle: (l) => l.minimizeOnExitDesc,
        select: (state) => state.minimizeOnExit,
        update: (state, value) => state.copyWith(minimizeOnExit: value),
      ),
      if (system.isAndroid) ...[
        _appSettingToggle(
          title: (l) => l.exclude,
          subtitle: (l) => l.excludeDesc,
          select: (state) => state.hidden,
          update: (state, value) => state.copyWith(hidden: value),
        ),
        _appSettingToggle(
          title: (l) => l.collapseQuickSettingsPanel,
          subtitle: (l) => l.collapseQuickSettingsPanelDesc,
          select: (state) => state.collapseQuickSettingsPanel,
          update: (state, value) =>
              state.copyWith(collapseQuickSettingsPanel: value),
        ),
        _appSettingToggle(
          title: (l) => l.showNotificationStopAction,
          subtitle: (l) => l.showNotificationStopActionDesc,
          select: (state) => state.showNotificationStopAction,
          update: (state, value) =>
              state.copyWith(showNotificationStopAction: value),
        ),
      ],
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
    ];
  }

  List<Widget> _requestItems() {
    return [
      const UaItem(),
      _appSettingToggle(
        title: (l) => l.checkCertificate,
        subtitle: (l) => l.checkCertificateDesc,
        select: (state) => state.checkCertificate,
        update: (state, value) => state.copyWith(checkCertificate: value),
      ),
    ];
  }

  List<Widget> _inboundItems(bool authentication) {
    return [
      const PortItem(),
      _clashToggle(
        title: (l) => l.allowLan,
        subtitle: (l) => l.allowLanDesc,
        select: (state) => state.allowLan,
        update: (state, value) => state.copyWith(allowLan: value),
      ),
      const AuthenticationItem(),
      if (authentication) ...const [
        AuthenticationAccountItem(),
        AuthenticationPasswordItem(),
      ],
      const ExternalControllerItem(),
    ];
  }

  List<Widget> _connectionItems({required bool closeConnections}) {
    return [
      const TestUrlItem(),
      _clashToggle(
        title: (l) => l.unifiedDelay,
        subtitle: (l) => l.unifiedDelayDesc,
        select: (state) => state.unifiedDelay,
        update: (state, value) => state.copyWith(unifiedDelay: value),
      ),
      _clashToggle(
        title: (l) => l.tcpConcurrent,
        subtitle: (l) => l.tcpConcurrentDesc,
        select: (state) => state.tcpConcurrent,
        update: (state, value) => state.copyWith(tcpConcurrent: value),
      ),
      if (system.isDesktop) const KeepAliveIntervalItem(),
      _clashToggle(
        title: (l) => l.findProcessMode,
        subtitle: (l) => l.findProcessModeDesc,
        select: (state) => state.findProcessMode == FindProcessMode.always,
        update: (state, value) => state.copyWith(
          findProcessMode: value ? FindProcessMode.always : FindProcessMode.off,
        ),
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
    ];
  }

  List<Widget> _coreItems() {
    return [
      _clashToggle(
        title: (l) => 'IPv6',
        subtitle: (l) => l.ipv6Desc,
        select: (state) => state.ipv6,
        update: (state, value) => state.copyWith(ipv6: value),
      ),
      const HostsItem(),
      ConfigToggleItem(
        title: (l) => l.appendSystemDns,
        subtitle: (l) => l.appendSystemDnsTip,
        selector: networkSettingProvider.select(
          (state) => state.appendSystemDns,
        ),
        onChanged: (ref, value) => ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(appendSystemDns: value)),
      ),
      _clashToggle(
        title: (l) => l.geodataLoader,
        subtitle: (l) => l.geodataLoaderDesc,
        select: (state) => state.geodataLoader == GeodataLoader.memconservative,
        update: (state, value) => state.copyWith(
          geodataLoader: value
              ? GeodataLoader.memconservative
              : GeodataLoader.standard,
        ),
      ),
      if (!system.isIOS) const GeositeMatcherItem(),
    ];
  }

  List<Widget> _logItems() {
    return [
      const LogLevelItem(),
      _appSettingToggle(
        title: (l) => l.logcat,
        subtitle: (l) => l.logcatDesc,
        select: (state) => state.openLogs,
        update: (state, value) => state.copyWith(openLogs: value),
      ),
    ];
  }

  List<Widget> _appItems() {
    return [
      _appSettingToggle(
        title: (l) => l.backToDashboard,
        subtitle: (l) => l.backToDashboardDesc,
        select: (state) => state.backToDashboard,
        update: (state, value) => state.copyWith(backToDashboard: value),
      ),
      if (system.isDesktop)
        _appSettingToggle(
          title: (l) => l.showTrayProxySelection,
          subtitle: (l) => l.showTrayProxySelectionDesc,
          select: (state) => state.showTrayProxySelection,
          update: (state, value) =>
              state.copyWith(showTrayProxySelection: value),
        ),
      const _ForegroundTickerIntervalItem(),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final authentication = ref.watch(
      networkSettingProvider.select((state) => state.authentication.enable),
    );
    final autoLaunch = ref.watch(
      appSettingProvider.select((state) => state.autoLaunch),
    );
    final closeConnections = ref.watch(
      appSettingProvider.select((state) => state.closeConnections),
    );
    return BaseScaffold(
      title: appLocalizations.general,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(bottom: 16),
        children: [
          generateSectionV3(
            title: appLocalizations.startupAndBackground,
            isFirst: true,
            items: _startupItems(appLocalizations, autoLaunch: autoLaunch),
          ),
          generateSectionV3(
            title: appLocalizations.requestsAndUpdates,
            items: _requestItems(),
          ),
          generateSectionV3(
            title: appLocalizations.inbound,
            items: _inboundItems(authentication),
          ),
          generateSectionV3(
            title: appLocalizations.connection,
            items: _connectionItems(closeConnections: closeConnections),
          ),
          generateSectionV3(title: appLocalizations.core, items: _coreItems()),
          generateSectionV3(
            title: appLocalizations.logsAndDiagnostics,
            items: _logItems(),
          ),
          generateSectionV3(title: appLocalizations.app, items: _appItems()),
        ],
      ),
    );
  }
}

class GeositeMatcherItem extends ConsumerWidget {
  const GeositeMatcherItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConfigToggleItem(
      title: (l) => l.geositeMatcher,
      subtitle: (l) => l.geositeMatcherDesc,
      selector: patchClashConfigProvider.select(
        (state) => state.geositeMatcher == GeositeMatcher.mph,
      ),
      onChanged: (ref, value) => ref
          .read(patchClashConfigProvider.notifier)
          .update(
            (state) => state.copyWith(
              geositeMatcher: value
                  ? GeositeMatcher.mph
                  : GeositeMatcher.succinct,
            ),
          ),
    );
  }
}

class ExternalControllerItem extends ConsumerWidget {
  const ExternalControllerItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final externalController = ref.watch(
      patchClashConfigProvider.select((state) => state.externalController),
    );
    return ListItem(
      title: Text(appLocalizations.externalController),
      subtitle: Text(
        externalController.isEmpty
            ? appLocalizations.externalControllerDesc
            : externalController,
      ),
      onTap: () {
        dialogs.showCommonDialog<void>(
          child: const _ExternalControllerDialog(),
        );
      },
    );
  }
}

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
          onPressed: Navigator.of(context).pop,
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
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(appLocalizations.enableExternalController),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(appLocalizations.allowLanAccess),
              subtitle: Text(appLocalizations.allowLanAccessDesc),
              value: _allowLan,
              onChanged: !_enabled
                  ? null
                  : (value) => setState(() => _allowLan = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: _enabled,
              keyboardType: TextInputType.number,
              maxLines: 1,
              minLines: 1,
              inputFormatters: TextInputLimits.digitsOnly(TextInputLimits.port),
              controller: _portController,
              onFieldSubmitted: (_) => _handleSubmit(),
              decoration: InputDecoration(
                labelText: appLocalizations.listeningPort,
              ),
              validator: (value) {
                if (!_enabled) {
                  return null;
                }
                final port = int.tryParse(value ?? '');
                if (port == null) {
                  return appLocalizations.numberTip(
                    appLocalizations.listeningPort,
                  );
                }
                if (port < 1024 || port > 49151) {
                  return appLocalizations.portTip(
                    appLocalizations.listeningPort,
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: _enabled,
              maxLines: 1,
              minLines: 1,
              inputFormatters: TextInputLimits.limit(TextInputLimits.password),
              controller: _secretController,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleSubmit(),
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

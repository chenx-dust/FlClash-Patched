import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
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
      leading: const Icon(Icons.info_outline),
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
      leading: const Icon(Icons.computer_outlined),
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
      leading: const Icon(Icons.timer_outlined),
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
      leading: const Icon(Icons.timeline),
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
      leading: const Icon(Icons.adjust_outlined),
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
      leading: const Icon(Icons.view_list_outlined),
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

ConfigToggleItem _clashToggle({
  required IconData icon,
  required ConfigLabel title,
  required ConfigLabel subtitle,
  required bool Function(PatchClashConfig state) select,
  required PatchClashConfig Function(PatchClashConfig state, bool value) update,
}) {
  return ConfigToggleItem(
    leading: Icon(icon),
    title: title,
    subtitle: subtitle,
    selector: patchClashConfigProvider.select(select),
    onChanged: (ref, value) => ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => update(state, value)),
  );
}

final generalItems = <Widget>[
  const LogLevelItem(),
  const UaItem(),
  if (system.isDesktop) const KeepAliveIntervalItem(),
  const TestUrlItem(),
  const PortItem(),
  const HostsItem(),
  const ExternalControllerItem(),
  _clashToggle(
    icon: Icons.water_outlined,
    title: (l) => 'IPv6',
    subtitle: (l) => l.ipv6Desc,
    select: (state) => state.ipv6,
    update: (state, value) => state.copyWith(ipv6: value),
  ),
  _clashToggle(
    icon: Icons.device_hub,
    title: (l) => l.allowLan,
    subtitle: (l) => l.allowLanDesc,
    select: (state) => state.allowLan,
    update: (state, value) => state.copyWith(allowLan: value),
  ),
  _clashToggle(
    icon: Icons.compress_outlined,
    title: (l) => l.unifiedDelay,
    subtitle: (l) => l.unifiedDelayDesc,
    select: (state) => state.unifiedDelay,
    update: (state, value) => state.copyWith(unifiedDelay: value),
  ),
  ConfigToggleItem(
    leading: const Icon(Icons.dns_outlined),
    title: (l) => l.appendSystemDns,
    subtitle: (l) => l.appendSystemDnsTip,
    selector: networkSettingProvider.select((state) => state.appendSystemDns),
    onChanged: (ref, value) => ref
        .read(networkSettingProvider.notifier)
        .update((state) => state.copyWith(appendSystemDns: value)),
  ),
  _clashToggle(
    icon: Icons.polymer_outlined,
    title: (l) => l.findProcessMode,
    subtitle: (l) => l.findProcessModeDesc,
    select: (state) => state.findProcessMode == FindProcessMode.always,
    update: (state, value) => state.copyWith(
      findProcessMode: value ? FindProcessMode.always : FindProcessMode.off,
    ),
  ),
  _clashToggle(
    icon: Icons.double_arrow_outlined,
    title: (l) => l.tcpConcurrent,
    subtitle: (l) => l.tcpConcurrentDesc,
    select: (state) => state.tcpConcurrent,
    update: (state, value) => state.copyWith(tcpConcurrent: value),
  ),
  _clashToggle(
    icon: Icons.memory,
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
].separated(const Divider(height: 0)).toList();

class GeositeMatcherItem extends ConsumerWidget {
  const GeositeMatcherItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConfigToggleItem(
      leading: const Icon(Icons.travel_explore),
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
      leading: const Icon(Icons.api_outlined),
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
          spacing: 16,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(appLocalizations.enableExternalController),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(appLocalizations.allowLanAccess),
              subtitle: Text(appLocalizations.allowLanAccessDesc),
              value: _allowLan,
              onChanged: !_enabled
                  ? null
                  : (value) => setState(() => _allowLan = value),
            ),
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

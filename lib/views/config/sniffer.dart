import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef _SnifferUpdate<T> = Sniffer Function(Sniffer sniffer, T value);

ProviderListenable<T> _snifferSelector<T>(T Function(Sniffer sniffer) select) {
  return patchClashConfigProvider.select((state) => select(state.sniffer));
}

ConfigWriter<T> _snifferWriter<T>(_SnifferUpdate<T> update) {
  return (ref, value) => ref
      .read(patchClashConfigProvider.notifier)
      .update((state) => state.copyWith(sniffer: update(state.sniffer, value)));
}

ConfigToggleItem _snifferToggle({
  required ConfigLabel title,
  required ConfigLabel subtitle,
  required bool Function(Sniffer sniffer) select,
  required _SnifferUpdate<bool> update,
}) {
  return ConfigToggleItem(
    title: title,
    subtitle: subtitle,
    selector: _snifferSelector(select),
    onChanged: _snifferWriter(update),
  );
}

ConfigListInputItem _snifferList({
  required ConfigLabel title,
  required ConfigLabel subtitle,
  required List<String> Function(Sniffer sniffer) select,
  required _SnifferUpdate<List<String>> update,
  required int itemMaxLength,
}) {
  return ConfigListInputItem(
    title: title,
    subtitle: subtitle,
    selector: _snifferSelector(select),
    onChanged: _snifferWriter(update),
    itemMaxLength: itemMaxLength,
  );
}

Sniffer _updateProtocol(
  Sniffer sniffer,
  String protocol,
  SnifferConfig? Function(SnifferConfig? config) update,
) {
  final sniff = Map<String, SnifferConfig>.from(sniffer.sniff);
  final config = update(sniff[protocol]);
  if (config == null) {
    sniff.remove(protocol);
  } else {
    sniff[protocol] = config;
  }
  return sniffer.copyWith(sniff: sniff);
}

class OverrideSnifferItem extends ConsumerWidget {
  const OverrideSnifferItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConfigToggleItem(
      title: (l) => l.overrideSniffer,
      subtitle: (l) => l.overrideSnifferDesc,
      selector: overrideSnifferProvider,
      onChanged: (ref, value) =>
          ref.read(overrideSnifferProvider.notifier).value = value,
    );
  }
}

class _SniffProtocolItem extends ConsumerWidget {
  const _SniffProtocolItem(this.protocol);

  final String protocol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final config = ref.watch(_snifferSelector((s) => s.sniff[protocol]));
    final String subtitle;
    if (config == null) {
      subtitle = l.disabledText;
    } else if (config.ports.isEmpty) {
      subtitle = l.allPorts;
    } else {
      subtitle = config.ports.join(', ');
    }
    return ListItem.open(
      title: Text(protocol),
      subtitle: Text(subtitle),
      blur: false,
      widget: BaseScaffold(title: protocol, body: _SniffProtocolView(protocol)),
    );
  }
}

class _SniffProtocolView extends ConsumerWidget {
  const _SniffProtocolView(this.protocol);

  final String protocol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      _snifferSelector((s) => s.sniff.containsKey(protocol)),
    );
    return ListView(
      padding: sectionPagePadding,
      children: [
        generateSectionV3(
          isFirst: true,
          items: [
            ConfigToggleItem(
              title: (l) => l.status,
              selector: _snifferSelector((s) => s.sniff.containsKey(protocol)),
              onChanged: _snifferWriter(
                (sniffer, value) => _updateProtocol(
                  sniffer,
                  protocol,
                  (_) => value
                      ? defaultSnifferSniff[protocol] ?? const SnifferConfig()
                      : null,
                ),
              ),
            ),
            if (enabled) ...[
              ConfigListInputItem(
                title: (l) => l.sniffPorts,
                subtitle: (l) => l.sniffPortsDesc,
                selector: _snifferSelector(
                  (s) => s.sniff[protocol]?.ports ?? const [],
                ),
                onChanged: _snifferWriter(
                  (sniffer, value) => _updateProtocol(
                    sniffer,
                    protocol,
                    (config) => config?.copyWith(ports: value),
                  ),
                ),
                itemMaxLength: TextInputLimits.number,
              ),
              ConfigOptionsItem<bool?>(
                title: (l) => l.overrideDestination,
                options: const [null, true, false],
                textBuilder: (value) {
                  final l = context.appLocalizations;
                  return switch (value) {
                    null => l.followGlobal,
                    true => l.enabledText,
                    false => l.disabledText,
                  };
                },
                selector: _snifferSelector(
                  (s) => s.sniff[protocol]?.overrideDest,
                ),
                onChanged: _snifferWriter(
                  (sniffer, value) => _updateProtocol(
                    sniffer,
                    protocol,
                    (config) => config?.copyWith(overrideDest: value),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class SnifferListView extends StatelessWidget {
  const SnifferListView({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return ListView(
      padding: sectionPagePadding,
      children: [
        generateSectionV3(isFirst: true, items: const [OverrideSnifferItem()]),
        generateSectionV3(
          title: l.options,
          items: [
            _snifferToggle(
              title: (l) => l.status,
              subtitle: (l) => l.snifferStatusDesc,
              select: (s) => s.enable,
              update: (s, value) => s.copyWith(enable: value),
            ),
            _snifferToggle(
              title: (l) => l.overrideDestination,
              subtitle: (l) => l.overrideDestinationDesc,
              select: (s) => s.overrideDest,
              update: (s, value) => s.copyWith(overrideDest: value),
            ),
            _snifferToggle(
              title: (l) => l.forceDnsMapping,
              subtitle: (l) => l.forceDnsMappingDesc,
              select: (s) => s.forceDnsMapping,
              update: (s, value) => s.copyWith(forceDnsMapping: value),
            ),
            _snifferToggle(
              title: (l) => l.parsePureIp,
              subtitle: (l) => l.parsePureIpDesc,
              select: (s) => s.parsePureIp,
              update: (s, value) => s.copyWith(parsePureIp: value),
            ),
          ],
        ),
        generateSectionV3(
          title: l.sniffProtocols,
          items: [
            for (final protocol in defaultSnifferSniff.keys)
              _SniffProtocolItem(protocol),
          ],
        ),
        generateSectionV3(
          title: l.sniffExceptions,
          items: [
            _snifferList(
              title: (l) => l.forceDomain,
              subtitle: (l) => l.forceDomainDesc,
              select: (s) => s.forceDomain,
              update: (s, value) => s.copyWith(forceDomain: value),
              itemMaxLength: TextInputLimits.domain,
            ),
            _snifferList(
              title: (l) => l.skipDomain,
              subtitle: (l) => l.skipDomainDesc,
              select: (s) => s.skipDomain,
              update: (s, value) => s.copyWith(skipDomain: value),
              itemMaxLength: TextInputLimits.domain,
            ),
            _snifferList(
              title: (l) => l.skipSrcAddress,
              subtitle: (l) => l.skipSrcAddressDesc,
              select: (s) => s.skipSrcAddress,
              update: (s, value) => s.copyWith(skipSrcAddress: value),
              itemMaxLength: TextInputLimits.cidr,
            ),
            _snifferList(
              title: (l) => l.skipDstAddress,
              subtitle: (l) => l.skipDstAddressDesc,
              select: (s) => s.skipDstAddress,
              update: (s, value) => s.copyWith(skipDstAddress: value),
              itemMaxLength: TextInputLimits.cidr,
            ),
          ],
        ),
      ],
    );
  }
}

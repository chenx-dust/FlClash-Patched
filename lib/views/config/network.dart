import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/config/tun_advanced.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef _VpnUpdate<T> = VpnProps Function(VpnProps state, T value);

typedef _NetworkUpdate<T> = NetworkProps Function(NetworkProps state, T value);

typedef _TunUpdate<T> =
    PatchClashConfig Function(PatchClashConfig state, T value);

ConfigWriter<T> _vpnWriter<T>(_VpnUpdate<T> update) {
  return (ref, value) => ref
      .read(vpnSettingProvider.notifier)
      .update((state) => update(state, value));
}

ConfigWriter<T> _networkWriter<T>(_NetworkUpdate<T> update) {
  return (ref, value) => ref
      .read(networkSettingProvider.notifier)
      .update((state) => update(state, value));
}

ConfigWriter<T> _tunWriter<T>(_TunUpdate<T> update) {
  return (ref, value) => ref
      .read(patchClashConfigProvider.notifier)
      .update((state) => update(state, value));
}

class NetworkResetButton extends ConsumerWidget {
  const NetworkResetButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    return IconButton(
      tooltip: l.reset,
      onPressed: () async {
        final confirmed = await dialogs.showMessage(
          title: l.reset,
          message: TextSpan(text: l.resetTip),
        );
        if (confirmed != true || !context.mounted) return;
        ref
            .read(networkSettingProvider.notifier)
            .update(
              (state) => defaultNetworkProps.copyWith(
                appendSystemDns: state.appendSystemDns,
              ),
            );
        ref
            .read(vpnSettingProvider.notifier)
            .update(
              (state) => defaultVpnProps.copyWith(
                networkSpeedNotification: state.networkSpeedNotification,
                accessControlProps: state.accessControlProps,
              ),
            );
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(tun: defaultTun));
      },
      icon: const Icon(Symbols.replay),
    );
  }
}

ConfigToggleItem _vpnToggle({
  required ConfigLabel title,
  required bool Function(VpnProps state) select,
  required _VpnUpdate<bool> update,
  ConfigLabel? subtitle,
}) {
  return ConfigToggleItem(
    title: title,
    subtitle: subtitle,
    selector: vpnSettingProvider.select(select),
    onChanged: _vpnWriter(update),
  );
}

ConfigToggleItem _networkToggle({
  required ConfigLabel title,
  required bool Function(NetworkProps state) select,
  required _NetworkUpdate<bool> update,
  ConfigLabel? subtitle,
}) {
  return ConfigToggleItem(
    title: title,
    subtitle: subtitle,
    selector: networkSettingProvider.select(select),
    onChanged: _networkWriter(update),
  );
}

class VPNItem extends ConsumerWidget {
  const VPNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _vpnToggle(
      title: (l) => 'VPN',
      subtitle: (l) => l.vpnEnableDesc,
      select: (state) => state.enable,
      update: (state, value) => state.copyWith(enable: value),
    );
  }
}

class TUNItem extends ConsumerWidget {
  const TUNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigToggleItem(
      title: (l) => l.tun,
      subtitle: (l) => l.tunDesc,
      selector: patchClashConfigProvider.select((state) => state.tun.enable),
      onChanged: _tunWriter(
        (state, value) => state.copyWith.tun(enable: value),
      ),
    );
  }
}

class AllowBypassItem extends ConsumerWidget {
  const AllowBypassItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _vpnToggle(
      title: (l) => l.allowBypass,
      subtitle: (l) => l.allowBypassDesc,
      select: (state) => state.allowBypass,
      update: (state, value) => state.copyWith(allowBypass: value),
    );
  }
}

class VpnSystemProxyItem extends ConsumerWidget {
  const VpnSystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final authenticationEnable = ref.watch(
      networkSettingProvider.select((state) => state.authentication.enable),
    );
    return _vpnToggle(
      title: (l) => l.systemProxy,
      subtitle: (l) => authenticationEnable
          ? l.authenticationSystemProxyDesc
          : l.systemProxyDesc,
      select: (state) => state.systemProxy,
      update: (state, value) => state.copyWith(systemProxy: value),
    );
  }
}

class SystemProxyItem extends ConsumerWidget {
  const SystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _networkToggle(
      title: (l) => l.systemProxy,
      subtitle: (l) => l.systemProxyDesc,
      select: (state) => state.systemProxy,
      update: (state, value) => state.copyWith(systemProxy: value),
    );
  }
}

class Ipv6Item extends ConsumerWidget {
  const Ipv6Item({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _vpnToggle(
      title: (l) => 'IPv6',
      subtitle: (l) => l.ipv6InboundDesc,
      select: (state) => state.ipv6,
      update: (state, value) => state.copyWith(ipv6: value),
    );
  }
}

class DNSHijackingItem extends ConsumerWidget {
  const DNSHijackingItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _vpnToggle(
      title: (l) => l.captureDns,
      subtitle: (l) => l.captureDnsDesc,
      select: (state) => state.dnsHijacking,
      update: (state, value) => state.copyWith(dnsHijacking: value),
    );
  }
}

class StrictRouteItem extends ConsumerWidget {
  const StrictRouteItem({super.key});

  @override
  Widget build(BuildContext context, ref) => ConfigToggleItem(
    title: (l) => l.strictRoute,
    subtitle: (l) => l.strictRouteDesc,
    selector: patchClashConfigProvider.select((state) => state.tun.strictRoute),
    onChanged: _tunWriter(
      (state, value) => state.copyWith.tun(strictRoute: value),
    ),
  );
}

class IcmpForwardingItem extends ConsumerWidget {
  const IcmpForwardingItem({super.key});

  @override
  Widget build(BuildContext context, ref) => ConfigToggleItem(
    title: (l) => l.icmpForwarding,
    subtitle: (l) => l.icmpForwardingDesc,
    selector: patchClashConfigProvider.select(
      (state) => !state.tun.disableIcmpForwarding,
    ),
    onChanged: _tunWriter(
      (state, value) => state.copyWith.tun(disableIcmpForwarding: !value),
    ),
  );
}

/// Accepts what mihomo's `dns-hijack` parser does; `any` means 0.0.0.0.
bool isValidDnsHijack(String value) {
  final schemeEnd = value.indexOf('://');
  final address = (schemeEnd == -1 ? value : value.substring(schemeEnd + 3))
      .replaceFirst('any', '0.0.0.0');
  final portStart = address.lastIndexOf(':');
  if (portStart <= 0) return false;
  final port = int.tryParse(address.substring(portStart + 1));
  if (port == null || port < 0 || port > 65535) return false;
  var host = address.substring(0, portStart);
  if (host.startsWith('[') && host.endsWith(']')) {
    host = host.substring(1, host.length - 1);
  } else if (host.contains(':')) {
    return false;
  }
  return InternetAddress.tryParse(host) != null;
}

class TunDnsHijackItem extends ConsumerWidget {
  const TunDnsHijackItem({super.key});

  @override
  Widget build(BuildContext context, ref) => ConfigListInputItem(
    title: (l) => l.dnsHijack,
    subtitle: (l) => l.dnsHijackDesc,
    itemMaxLength: TextInputLimits.cidr,
    itemValidator: (item, l) =>
        isValidDnsHijack(item) ? null : l.tunDnsHijackFormatTip,
    selector: patchClashConfigProvider.select((state) => state.tun.dnsHijack),
    onChanged: _tunWriter(
      (state, value) => state.copyWith.tun(dnsHijack: value),
    ),
  );
}

class TunDnsModeItem extends ConsumerWidget {
  const TunDnsModeItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    return ConfigOptionsItem<TunDnsMode>(
      title: (l) => l.tunDnsMode,
      options: TunDnsMode.values,
      textBuilder: (mode) => switch (mode) {
        TunDnsMode.disabled => appLocalizations.tunDnsModeDisabled,
        TunDnsMode.native => appLocalizations.tunDnsModeNative,
        TunDnsMode.hijack => appLocalizations.tunDnsModeHijack,
      },
      selector: patchClashConfigProvider.select((state) => state.tun.dnsMode),
      onChanged: _tunWriter(
        (state, value) => state.copyWith.tun(dnsMode: value),
      ),
    );
  }
}

class EndpointIndependentNatItem extends ConsumerWidget {
  const EndpointIndependentNatItem({super.key});

  @override
  Widget build(BuildContext context, ref) => ConfigToggleItem(
    title: (l) => l.endpointIndependentNat,
    subtitle: (l) => l.endpointIndependentNatDesc,
    selector: patchClashConfigProvider.select(
      (state) => state.tun.endpointIndependentNat,
    ),
    onChanged: _tunWriter(
      (state, value) => state.copyWith.tun(endpointIndependentNat: value),
    ),
  );
}

class RecvMsgXItem extends ConsumerWidget {
  const RecvMsgXItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConfigToggleItem(
    title: (l) => l.recvMsgX,
    subtitle: (l) => l.recvMsgXDesc,
    selector: patchClashConfigProvider.select((state) => state.tun.recvMsgX),
    onChanged: _tunWriter(
      (state, value) => state.copyWith.tun(recvMsgX: value),
    ),
  );
}

class SendMsgXItem extends ConsumerWidget {
  const SendMsgXItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConfigToggleItem(
    title: (l) => l.sendMsgX,
    subtitle: (l) => l.sendMsgXDesc,
    selector: patchClashConfigProvider.select((state) => state.tun.sendMsgX),
    onChanged: _tunWriter(
      (state, value) => state.copyWith.tun(sendMsgX: value),
    ),
  );
}

class TunCongestionControllerItem extends ConsumerWidget {
  const TunCongestionControllerItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.stack),
    );
    if (stack != TunStack.mips) {
      return Container();
    }
    return ConfigOptionsItem<TunCongestionController>(
      title: (l) => l.congestionController,
      options: TunCongestionController.values,
      textBuilder: (controller) => controller.name,
      selector: patchClashConfigProvider.select(
        (state) => state.tun.congestionController,
      ),
      onChanged: _tunWriter(
        (state, value) => state.copyWith.tun(congestionController: value),
      ),
    );
  }
}

class TunStackItem extends ConsumerWidget {
  const TunStackItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigOptionsItem<TunStack>(
      title: (l) => l.stackMode,
      options: TunStack.values,
      textBuilder: (stack) => stack.name,
      selector: patchClashConfigProvider.select((state) => state.tun.stack),
      onChanged: _tunWriter((state, value) => state.copyWith.tun(stack: value)),
    );
  }
}

class TunMtuItem extends ConsumerWidget {
  const TunMtuItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mtu = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.mtu),
    );
    final l = context.appLocalizations;
    return ListItem.input(
      title: Text(l.mtu),
      subtitle: Text('$mtu'),
      dialogTitle: l.mtu,
      value: '$mtu',
      resetValue: '$defaultTunMtu',
      maxLength: TextInputLimits.number,
      keyboardType: TextInputType.number,
      validator: (value) {
        final parsed = int.tryParse(value ?? '');
        return parsed == null || parsed <= 0 || parsed > 65535
            ? l.mtuRangeTip
            : null;
      },
      onChanged: (value) {
        final parsed = int.tryParse(value ?? '');
        if (parsed == null) return;
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(mtu: parsed));
      },
    );
  }
}

class TunDeviceItem extends ConsumerWidget {
  const TunDeviceItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.device),
    );
    final l = context.appLocalizations;
    return ListItem.input(
      title: Text(l.tunDevice),
      subtitle: Text(device),
      dialogTitle: l.tunDevice,
      value: device,
      resetValue: appName,
      maxLength: TextInputLimits.name,
      validator: (value) =>
          value?.trim().isNotEmpty == true ? null : l.emptyTip(l.tunDevice),
      onChanged: (value) {
        final trimmed = value?.trim();
        if (trimmed == null || trimmed.isEmpty) return;
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(device: trimmed));
      },
    );
  }
}

class TunAutoRouteItem extends ConsumerWidget {
  const TunAutoRouteItem({super.key});

  @override
  Widget build(BuildContext context, ref) => _networkToggle(
    title: (l) => l.tunAutoRoute,
    subtitle: (l) => l.tunAutoRouteDesc,
    select: (state) => state.desktopAutoRoute,
    update: (state, value) => state.copyWith(desktopAutoRoute: value),
  );
}

ConfigToggleItem _iosVpnToggle({
  required ConfigLabel title,
  required ConfigLabel subtitle,
  required bool Function(VpnProps state) select,
  required _VpnUpdate<bool> update,
}) => _vpnToggle(
  title: title,
  subtitle: subtitle,
  select: select,
  update: update,
);

class IncludeAllNetworksItem extends ConsumerWidget {
  const IncludeAllNetworksItem({super.key});

  @override
  Widget build(BuildContext context, ref) => _iosVpnToggle(
    title: (l) => l.includeAllNetworks,
    subtitle: (l) => l.includeAllNetworksDesc,
    select: (state) => state.includeAllNetworks,
    update: (state, value) => state.copyWith(includeAllNetworks: value),
  );
}

class ExcludeLocalNetworksItem extends ConsumerWidget {
  const ExcludeLocalNetworksItem({super.key});

  @override
  Widget build(BuildContext context, ref) => _iosVpnToggle(
    title: (l) => l.excludeLocalNetworks,
    subtitle: (l) => l.excludeLocalNetworksDesc,
    select: (state) => state.excludeLocalNetworks,
    update: (state, value) => state.copyWith(excludeLocalNetworks: value),
  );
}

class ExcludeAPNsItem extends ConsumerWidget {
  const ExcludeAPNsItem({super.key});

  @override
  Widget build(BuildContext context, ref) => _iosVpnToggle(
    title: (l) => l.excludeAPNs,
    subtitle: (l) => l.excludeAPNsDesc,
    select: (state) => state.excludeAPNs,
    update: (state, value) => state.copyWith(excludeAPNs: value),
  );
}

class ExcludeCellularServicesItem extends ConsumerWidget {
  const ExcludeCellularServicesItem({super.key});

  @override
  Widget build(BuildContext context, ref) => _iosVpnToggle(
    title: (l) => l.excludeCellularServices,
    subtitle: (l) => l.excludeCellularServicesDesc,
    select: (state) => state.excludeCellularServices,
    update: (state, value) => state.copyWith(excludeCellularServices: value),
  );
}

class EnforceRoutesItem extends ConsumerWidget {
  const EnforceRoutesItem({super.key});

  @override
  Widget build(BuildContext context, ref) => _iosVpnToggle(
    title: (l) => l.enforceRoutes,
    subtitle: (l) => l.enforceRoutesDesc,
    select: (state) => state.enforceRoutes,
    update: (state, value) => state.copyWith(enforceRoutes: value),
  );
}

class ExcludeDeviceCommunicationItem extends ConsumerWidget {
  const ExcludeDeviceCommunicationItem({super.key});

  @override
  Widget build(BuildContext context, ref) => _iosVpnToggle(
    title: (l) => l.excludeDeviceCommunication,
    subtitle: (l) => l.excludeDeviceCommunicationDesc,
    select: (state) => state.excludeDeviceCommunication,
    update: (state, value) => state.copyWith(excludeDeviceCommunication: value),
  );
}

class InterfaceNameItem extends ConsumerWidget {
  const InterfaceNameItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final l = context.appLocalizations;
    final (:mode, :name) = ref.watch(
      patchClashConfigProvider.select(
        (state) => (mode: state.interfaceNameMode, name: state.interfaceName),
      ),
    );
    final value = mode == InterfaceNameMode.custom ? name : '';
    return ListItem.input(
      title: Text(l.interfaceNameMode),
      subtitle: Text(switch (mode) {
        InterfaceNameMode.follow => l.followProfile,
        _ when value.isEmpty => l.interfaceNameDesc,
        _ => value,
      }),
      dialogTitle: l.interfaceNameMode,
      value: value,
      resetValue: '',
      maxLength: TextInputLimits.name,
      onChanged: (input) {
        if (input == null) return;
        final trimmed = input.trim();
        ref
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith(
                interfaceNameMode: trimmed.isEmpty
                    ? InterfaceNameMode.clear
                    : InterfaceNameMode.custom,
                interfaceName: trimmed,
              ),
            );
      },
    );
  }
}

class RouteModeItem extends ConsumerWidget {
  const RouteModeItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigOptionsItem<RouteMode>(
      title: (l) => l.routeMode,
      options: RouteMode.values,
      textBuilder: (mode) => mode.label,
      selector: networkSettingProvider.select((state) => state.routeMode),
      onChanged: _networkWriter(
        (state, value) => state.copyWith(routeMode: value),
      ),
    );
  }
}

class BypassDomainItem extends ConsumerWidget {
  const BypassDomainItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigListInputItem(
      title: (l) => l.bypassDomain,
      subtitle: (l) => l.bypassDomainDesc,
      itemMaxLength: TextInputLimits.domain,
      selector: networkSettingProvider.select((state) => state.bypassDomain),
      onChanged: _networkWriter(
        (state, value) => state.copyWith(bypassDomain: value),
      ),
    );
  }
}

class RouteAddressItem extends ConsumerWidget {
  const RouteAddressItem({super.key, this.followsRouteMode = true});

  final bool followsRouteMode;

  @override
  Widget build(BuildContext context, ref) {
    final bypassPrivate = ref.watch(
      networkSettingProvider.select(
        (state) => state.routeMode == RouteMode.bypassPrivate,
      ),
    );
    if (followsRouteMode && bypassPrivate) {
      return Container();
    }
    return ConfigListInputItem(
      title: (l) => l.routeAddress,
      subtitle: (l) => l.routeAddressDesc,
      itemMaxLength: TextInputLimits.cidr,
      maxWidth: 360,
      selector: patchClashConfigProvider.select(
        (state) => state.tun.routeAddress,
      ),
      onChanged: _tunWriter(
        (state, value) => state.copyWith.tun(routeAddress: value),
      ),
    );
  }
}

List<Widget> networkOptionsItems({
  required bool isDesktop,
  required bool isMacOS,
  bool isIOS = false,
}) {
  return [
    if (isDesktop) ...[
      const TUNItem(),
      const TunAutoRouteItem(),
      const StrictRouteItem(),
      const RouteAddressItem(followsRouteMode: false),
    ],
    const IcmpForwardingItem(),
    const EndpointIndependentNatItem(),
    if (isDesktop) ...[const TunDnsModeItem(), const TunDnsHijackItem()],
    if (isMacOS || isIOS) ...[const RecvMsgXItem(), const SendMsgXItem()],
    const TunStackItem(),
    const TunCongestionControllerItem(),
    const TunMtuItem(),
    if (isDesktop && !isMacOS) const TunDeviceItem(),
    // mihomo's DefaultSocketHook ignores interface-name on Android
    // (core/lib.go installHooks, vendored dialer.go), so this row only
    // applies on desktop.
    if (isDesktop) const InterfaceNameItem(),
    if (!isDesktop) ...[const RouteModeItem(), const RouteAddressItem()],
    if (isDesktop) const TunAdvancedItem(),
  ];
}

class NetworkListView extends ConsumerWidget {
  const NetworkListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final version = ref.watch(versionProvider);
    final leadingVpn = system.isAndroid;
    return ListView(
      padding: sectionPagePadding,
      children: [
        if (leadingVpn)
          generateSectionV3(isFirst: true, items: const [VPNItem()]),
        if (system.isMobile)
          generateSectionV3(
            title: 'VPN',
            isFirst: !leadingVpn,
            items: [
              const VpnSystemProxyItem(),
              const BypassDomainItem(),
              const AllowBypassItem(),
              const Ipv6Item(),
              const DNSHijackingItem(),
            ],
          ),
        if (system.isDesktop)
          generateSectionV3(
            title: appLocalizations.system,
            isFirst: true,
            items: const [SystemProxyItem(), BypassDomainItem()],
          ),
        generateSectionV3(
          title: appLocalizations.options,
          isFirst: !system.isMobile && !system.isDesktop,
          items: networkOptionsItems(
            isDesktop: system.isDesktop,
            isMacOS: system.isMacOS,
            isIOS: system.isIOS,
          ),
        ),
        if (system.isIOS)
          generateSectionV3(
            title: appLocalizations.networkExtension,
            items: [
              const IncludeAllNetworksItem(),
              const EnforceRoutesItem(),
              const ExcludeLocalNetworksItem(),
              if (version >= 16) ...[
                const ExcludeAPNsItem(),
                const ExcludeCellularServicesItem(),
              ],
              if (version >= 17) const ExcludeDeviceCommunicationItem(),
            ],
          ),
      ],
    );
  }
}

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
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
      icon: const Icon(Icons.replay),
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
    return _vpnToggle(
      title: (l) => l.systemProxy,
      subtitle: (l) => l.systemProxyDesc,
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

class AutoSetSystemDnsItem extends ConsumerWidget {
  const AutoSetSystemDnsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _networkToggle(
      title: (l) => l.autoSetSystemDns,
      select: (state) => state.autoSetSystemDns,
      update: (state, value) => state.copyWith(autoSetSystemDns: value),
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

class SuspendSupportItem extends ConsumerWidget {
  const SuspendSupportItem({super.key});

  @override
  Widget build(BuildContext context, ref) => _vpnToggle(
    title: (l) => l.suspendSupport,
    subtitle: (l) => l.suspendSupportDesc,
    select: (state) => state.suspendSupport,
    update: (state, value) => state.copyWith(suspendSupport: value),
  );
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

class TunDnsHijackItem extends ConsumerWidget {
  const TunDnsHijackItem({super.key});

  @override
  Widget build(BuildContext context, ref) => ConfigToggleItem(
    title: (l) => l.dnsHijack,
    subtitle: (l) => l.dnsHijackDesc,
    selector: patchClashConfigProvider.select(
      (state) => state.tun.dnsHijack.isNotEmpty,
    ),
    onChanged: _tunWriter(
      (state, value) => state.copyWith.tun(
        dnsHijack: value ? ['any:53', 'tcp://any:53'] : [],
      ),
    ),
  );
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

class InterfaceNameModeItem extends ConsumerWidget {
  const InterfaceNameModeItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    return ConfigOptionsItem<InterfaceNameMode>(
      title: (l) => l.interfaceNameMode,
      options: InterfaceNameMode.values,
      textBuilder: (mode) => switch (mode) {
        InterfaceNameMode.clear => appLocalizations.interfaceNameModeClear,
        InterfaceNameMode.follow => appLocalizations.interfaceNameModeFollow,
        InterfaceNameMode.custom => appLocalizations.interfaceNameModeCustom,
      },
      selector: patchClashConfigProvider.select(
        (state) => state.interfaceNameMode,
      ),
      onChanged: _tunWriter(
        (state, value) => state.copyWith(interfaceNameMode: value),
      ),
    );
  }
}

class InterfaceNameItem extends ConsumerWidget {
  const InterfaceNameItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final isCustom = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.interfaceNameMode == InterfaceNameMode.custom,
      ),
    );
    if (!isCustom) {
      return Container();
    }
    return ConfigTextItem(
      title: (l) => l.interfaceName,
      subtitle: (l) => l.interfaceNameDesc,
      maxLength: TextInputLimits.name,
      selector: patchClashConfigProvider.select((state) => state.interfaceName),
      onChanged: _tunWriter(
        (state, value) => state.copyWith(interfaceName: value.trim()),
      ),
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
  const RouteAddressItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final bypassPrivate = ref.watch(
      networkSettingProvider.select(
        (state) => state.routeMode == RouteMode.bypassPrivate,
      ),
    );
    if (bypassPrivate) {
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
}) {
  return [
    if (isDesktop) const TUNItem(),
    if (isMacOS) const AutoSetSystemDnsItem(),
    if (isDesktop) const StrictRouteItem(),
    const IcmpForwardingItem(),
    if (isDesktop) const TunDnsHijackItem(),
    const EndpointIndependentNatItem(),
    if (!system.isIOS) const TunStackItem(),
    const TunMtuItem(),
    // mihomo's DefaultSocketHook ignores interface-name on Android
    // (core/lib.go installHooks, vendored dialer.go), so these rows only
    // apply on desktop.
    if (isDesktop) ...[
      const InterfaceNameModeItem(),
      const InterfaceNameItem(),
    ],
    if (!isDesktop) ...[const RouteModeItem(), const RouteAddressItem()],
  ];
}

class NetworkListView extends ConsumerWidget {
  const NetworkListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final version = ref.watch(versionProvider);
    return generateListView([
      if (system.isAndroid) const VPNItem(),
      if (system.isMobile)
        ...generateSection(
          title: 'VPN',
          items: [
            const VpnSystemProxyItem(),
            const BypassDomainItem(),
            const AllowBypassItem(),
            const Ipv6Item(),
            const DNSHijackingItem(),
            if (system.isAndroid) const SuspendSupportItem(),
          ],
        ),
      if (system.isDesktop)
        ...generateSection(
          title: appLocalizations.system,
          items: [const SystemProxyItem(), const BypassDomainItem()],
        ),
      ...generateSection(
        title: appLocalizations.options,
        items: networkOptionsItems(
          isDesktop: system.isDesktop,
          isMacOS: system.isMacOS,
        ),
      ),
      if (system.isIOS)
        ...generateSection(
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
    ]);
  }
}

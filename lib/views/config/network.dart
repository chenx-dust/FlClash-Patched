import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

ConfigToggleItem _tunToggle({
  required ConfigLabel title,
  required bool Function(Tun state) select,
  required Tun Function(Tun state, bool value) update,
  ConfigLabel? subtitle,
}) {
  return ConfigToggleItem(
    title: title,
    subtitle: subtitle,
    selector: patchClashConfigProvider.select((state) => select(state.tun)),
    onChanged: _tunWriter(
      (state, value) => state.copyWith(tun: update(state.tun, value)),
    ),
  );
}

class NetworkResetButton extends ConsumerWidget {
  const NetworkResetButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    return IconButton(
      onPressed: () async {
        final confirmed = await dialogs.showMessage(
          context: context,
          title: appLocalizations.reset,
          message: TextSpan(text: appLocalizations.resetTip),
        );
        if (confirmed != true || !context.mounted) {
          return;
        }
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
      tooltip: appLocalizations.reset,
      icon: const Icon(Icons.replay),
    );
  }
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

class CaptureDnsItem extends ConsumerWidget {
  const CaptureDnsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _vpnToggle(
      title: (l) => l.captureDns,
      subtitle: (l) => l.captureDnsDesc,
      select: (state) => state.captureDns,
      update: (state, value) => state.copyWith(captureDns: value),
    );
  }
}

class StrictRouteItem extends ConsumerWidget {
  const StrictRouteItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _tunToggle(
      title: (l) => l.strictRoute,
      subtitle: (l) => l.strictRouteDesc,
      select: (state) => state.strictRoute,
      update: (state, value) => state.copyWith(strictRoute: value),
    );
  }
}

class IcmpForwardingItem extends ConsumerWidget {
  const IcmpForwardingItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _tunToggle(
      title: (l) => l.icmpForwarding,
      subtitle: (l) => l.icmpForwardingDesc,
      select: (state) => !state.disableIcmpForwarding,
      update: (state, value) => state.copyWith(disableIcmpForwarding: !value),
    );
  }
}

class DnsHijackItem extends ConsumerWidget {
  const DnsHijackItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _tunToggle(
      title: (l) => l.dnsHijack,
      subtitle: (l) => l.dnsHijackDesc,
      select: (state) => state.dnsHijack.isNotEmpty,
      update: (state, value) =>
          state.copyWith(dnsHijack: value ? ['any:53', 'tcp://any:53'] : []),
    );
  }
}

class EndpointIndependentNatItem extends ConsumerWidget {
  const EndpointIndependentNatItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _tunToggle(
      title: (l) => l.endpointIndependentNat,
      subtitle: (l) => l.endpointIndependentNatDesc,
      select: (state) => state.endpointIndependentNat,
      update: (state, value) => state.copyWith(endpointIndependentNat: value),
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
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final mtu = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.mtu),
    );
    return ListItem.input(
      title: Text(appLocalizations.mtu),
      subtitle: Text('$mtu'),
      dialogTitle: appLocalizations.mtu,
      value: '$mtu',
      resetValue: '$defaultTunMtu',
      maxLength: TextInputLimits.number,
      keyboardType: TextInputType.number,
      validator: (value) {
        final parsed = int.tryParse(value ?? '');
        if (parsed == null || parsed < 1 || parsed > 65535) {
          return appLocalizations.mtuRangeTip;
        }
        return null;
      },
      onChanged: (value) {
        final parsed = int.tryParse(value ?? '');
        if (parsed == null) {
          return;
        }
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(mtu: parsed));
      },
    );
  }
}

class SuspendSupportItem extends ConsumerWidget {
  const SuspendSupportItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final suspendSupport = ref.watch(
      vpnSettingProvider.select((state) => state.suspendSupport),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.suspendSupport),
      subtitle: Text(appLocalizations.suspendSupportDesc),
      value: suspendSupport,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(suspendSupport: value));
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
      textBuilder: (mode) => Intl.message('routeMode_${mode.name}'),
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

class IncludeAllNetworksItem extends ConsumerWidget {
  const IncludeAllNetworksItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final includeAllNetworks = ref.watch(
      vpnSettingProvider.select((state) => state.includeAllNetworks),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.includeAllNetworks),
      subtitle: Text(appLocalizations.includeAllNetworksDesc),
      value: includeAllNetworks,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(includeAllNetworks: value));
      },
    );
  }
}

class ExcludeLocalNetworksItem extends ConsumerWidget {
  const ExcludeLocalNetworksItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final excludeLocalNetworks = ref.watch(
      vpnSettingProvider.select((state) => state.excludeLocalNetworks),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.excludeLocalNetworks),
      subtitle: Text(appLocalizations.excludeLocalNetworksDesc),
      value: excludeLocalNetworks,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(excludeLocalNetworks: value));
      },
    );
  }
}

class ExcludeAPNsItem extends ConsumerWidget {
  const ExcludeAPNsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final excludeAPNs = ref.watch(
      vpnSettingProvider.select((state) => state.excludeAPNs),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.excludeAPNs),
      subtitle: Text(appLocalizations.excludeAPNsDesc),
      value: excludeAPNs,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(excludeAPNs: value));
      },
    );
  }
}

class ExcludeCellularServicesItem extends ConsumerWidget {
  const ExcludeCellularServicesItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final excludeCellularServices = ref.watch(
      vpnSettingProvider.select((state) => state.excludeCellularServices),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.excludeCellularServices),
      subtitle: Text(appLocalizations.excludeCellularServicesDesc),
      value: excludeCellularServices,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(excludeCellularServices: value));
      },
    );
  }
}

class EnforceRoutesItem extends ConsumerWidget {
  const EnforceRoutesItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enforceRoutes = ref.watch(
      vpnSettingProvider.select((state) => state.enforceRoutes),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.enforceRoutes),
      subtitle: Text(appLocalizations.enforceRoutesDesc),
      value: enforceRoutes,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(enforceRoutes: value));
      },
    );
  }
}

class ExcludeDeviceCommunicationItem extends ConsumerWidget {
  const ExcludeDeviceCommunicationItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final excludeDeviceCommunication = ref.watch(
      vpnSettingProvider.select((state) => state.excludeDeviceCommunication),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.excludeDeviceCommunication),
      subtitle: Text(appLocalizations.excludeDeviceCommunicationDesc),
      value: excludeDeviceCommunication,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update(
              (state) => state.copyWith(excludeDeviceCommunication: value),
            );
      },
    );
  }
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
            const CaptureDnsItem(),
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
        items: [
          if (system.isDesktop) const TUNItem(),
          if (system.isMacOS) const AutoSetSystemDnsItem(),
          if (system.isDesktop) const StrictRouteItem(),
          const IcmpForwardingItem(),
          if (system.isDesktop) const DnsHijackItem(),
          const EndpointIndependentNatItem(),
          if (!system.isIOS) const TunStackItem(),
          const TunMtuItem(),
          if (system.isAndroid || system.isIOS) ...[
            const RouteModeItem(),
            const RouteAddressItem(),
          ],
        ],
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

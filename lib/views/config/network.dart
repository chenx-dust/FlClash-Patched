import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class VPNItem extends ConsumerWidget {
  const VPNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      vpnSettingProvider.select((state) => state.enable),
    );
    return ListItem.toggle(
      title: const Text('VPN'),
      subtitle: Text(appLocalizations.vpnEnableDesc),
      value: enable,
      onChanged: (value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(enable: value));
      },
    );
  }
}

class TUNItem extends ConsumerWidget {
  const TUNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );

    return ListItem.toggle(
      title: Text(appLocalizations.tun),
      subtitle: Text(appLocalizations.tunDesc),
      value: enable,
      onChanged: (value) async {
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(enable: value));
      },
    );
  }
}

class AllowBypassItem extends ConsumerWidget {
  const AllowBypassItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final allowBypass = ref.watch(
      vpnSettingProvider.select((state) => state.allowBypass),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.allowBypass),
      subtitle: Text(appLocalizations.allowBypassDesc),
      value: allowBypass,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(allowBypass: value));
      },
    );
  }
}

class VpnSystemProxyItem extends ConsumerWidget {
  const VpnSystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final systemProxy = ref.watch(
      vpnSettingProvider.select((state) => state.systemProxy),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.systemProxyDesc),
      value: systemProxy,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(systemProxy: value));
      },
    );
  }
}

class SystemProxyItem extends ConsumerWidget {
  const SystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final systemProxy = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );

    return ListItem.toggle(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.systemProxyDesc),
      value: systemProxy,
      onChanged: (bool value) async {
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(systemProxy: value));
      },
    );
  }
}

class Ipv6Item extends ConsumerWidget {
  const Ipv6Item({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final ipv6 = ref.watch(vpnSettingProvider.select((state) => state.ipv6));
    return ListItem.toggle(
      title: const Text('IPv6'),
      subtitle: Text(appLocalizations.ipv6InboundDesc),
      value: ipv6,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(ipv6: value));
      },
    );
  }
}

class AutoSetSystemDnsItem extends ConsumerWidget {
  const AutoSetSystemDnsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final autoSetSystemDns = ref.watch(
      networkSettingProvider.select((state) => state.autoSetSystemDns),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.autoSetSystemDns),
      value: autoSetSystemDns,
      onChanged: (bool value) async {
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(autoSetSystemDns: value));
      },
    );
  }
}

class TunStackItem extends ConsumerWidget {
  const TunStackItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final stack = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.stack),
    );

    return ListItem.options(
      title: Text(appLocalizations.stackMode),
      subtitle: Text(stack.name),
      value: stack,
      options: TunStack.values,
      textBuilder: (value) => value.name,
      onChanged: (value) {
        if (value == null) {
          return;
        }
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(stack: value));
      },
      dialogTitle: appLocalizations.stackMode,
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
      validator: (String? value) {
        final intValue = int.tryParse(value ?? '');
        if (intValue == null || intValue <= 0 || intValue > 65535) {
          return appLocalizations.mtuRangeTip;
        }
        return null;
      },
      onChanged: (String? value) {
        final mtu = int.tryParse(value ?? '');
        if (mtu == null) {
          return;
        }
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(mtu: mtu));
      },
    );
  }
}

class BypassDomainItem extends ConsumerWidget {
  const BypassDomainItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final bypassDomain = ref.watch(
      networkSettingProvider.select((state) => state.bypassDomain),
    );
    return ListItem.open(
      title: Text(appLocalizations.bypassDomain),
      subtitle: Text(appLocalizations.bypassDomainDesc),
      blur: false,
      widget: ListInputPage(
        title: appLocalizations.bypassDomain,
        items: bypassDomain,
        itemMaxLength: TextInputLimits.domain,
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (items) {
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(bypassDomain: List.from(items)));
      },
    );
  }
}

class DNSHijackingItem extends ConsumerWidget {
  const DNSHijackingItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final dnsHijacking = ref.watch(
      vpnSettingProvider.select((state) => state.dnsHijacking),
    );
    return ListItem<RouteMode>.toggle(
      title: Text(appLocalizations.dnsHijacking),
      value: dnsHijacking,
      onChanged: (value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(dnsHijacking: value));
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
    final appLocalizations = context.appLocalizations;
    final routeMode = ref.watch(
      networkSettingProvider.select((state) => state.routeMode),
    );
    return ListItem<RouteMode>.options(
      title: Text(appLocalizations.routeMode),
      subtitle: Text(Intl.message('routeMode_${routeMode.name}')),
      dialogTitle: appLocalizations.routeMode,
      options: RouteMode.values,
      onChanged: (RouteMode? value) {
        if (value == null) {
          return;
        }
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(routeMode: value));
      },
      textBuilder: (routeMode) => Intl.message('routeMode_${routeMode.name}'),
      value: routeMode,
    );
  }
}

class RouteAddressItem extends ConsumerWidget {
  const RouteAddressItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final bypassPrivate = ref.watch(
      networkSettingProvider.select(
        (state) => state.routeMode == RouteMode.bypassPrivate,
      ),
    );
    if (bypassPrivate) {
      return Container();
    }
    final routeAddress = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.routeAddress),
    );
    return ListItem.open(
      title: Text(appLocalizations.routeAddress),
      subtitle: Text(appLocalizations.routeAddressDesc),
      blur: false,
      maxWidth: 360,
      widget: ListInputPage(
        title: appLocalizations.routeAddress,
        items: routeAddress,
        itemMaxLength: TextInputLimits.cidr,
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (items) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith.tun(routeAddress: List.from(items)),
            );
      },
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
            .update(
              (state) => state.copyWith(excludeCellularServices: value),
            );
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
        ref.read(vpnSettingProvider.notifier).update(
              (state) =>
                  state.copyWith(excludeDeviceCommunication: value),
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
        items: [
          if (system.isDesktop) const TUNItem(),
          if (system.isMacOS) const AutoSetSystemDnsItem(),
          if (!system.isIOS) const TunStackItem(),
          const TunMtuItem(),
          if (system.isMobile) ...[
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

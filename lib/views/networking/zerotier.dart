import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/networking/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

List<Widget> buildZeroTierChildren({
  required BuildContext context,
  required OverlayNetworkStatus status,
  required ZeroTierNetworkDetails details,
  required Widget? statusErrorItem,
  required Widget? activationItem,
}) {
  final appLocalizations = context.appLocalizations;
  final networkTitle = status.networkName.isNotEmpty
      ? status.networkName
      : details.networkId.isNotEmpty
      ? details.networkId
      : appLocalizations.network;
  final networkItems = <OverlayNetworkDetailItem>[
    if (details.networkId.isNotEmpty)
      (
        name: appLocalizations.networkId,
        value: details.networkId,
        copyable: true,
      ),
    if (details.routes.isNotEmpty)
      (
        name: appLocalizations.routes,
        value: details.routes.join(' · '),
        copyable: true,
      ),
    if (details.dns.isNotEmpty)
      (name: 'DNS', value: details.dns.join(' · '), copyable: true),
    if (details.mtu > 0)
      (
        name: appLocalizations.mtu,
        value: details.mtu.toString(),
        copyable: false,
      ),
  ];
  return [
    ...generateSection(
      isFirst: true,
      items: [
        ?statusErrorItem,
        ?activationItem,
        if (status.authUrl.isNotEmpty)
          OverlayNetworkLoginItem(url: status.authUrl),
        ListItem(
          leading: const Icon(Icons.hub_outlined),
          title: Text(networkTitle),
          subtitle: status.networkName.isEmpty || details.networkId.isEmpty
              ? null
              : Text(details.networkId),
          onTap: networkItems.isEmpty
              ? null
              : () {
                  dialogs.showCommonDialog(
                    child: OverlayNetworkDetailsDialog(
                      title: appLocalizations.details(networkTitle),
                      items: networkItems,
                    ),
                  );
                },
        ),
      ],
    ),
    ...generateSection(
      isFirst: true,
      title: appLocalizations.local,
      items: [_ZeroTierLocalNodeItem(details: details)],
    ),
    ...generateSection(
      isFirst: true,
      title: appLocalizations.nodes,
      items: [for (final peer in details.peers) _ZeroTierPeerItem(peer: peer)],
    ),
  ];
}

class _ZeroTierLocalNodeItem extends StatelessWidget {
  final ZeroTierNetworkDetails details;

  const _ZeroTierLocalNodeItem({required this.details});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final color = details.online
        ? context.colorScheme.primary
        : context.colorScheme.outline;
    final status = details.online
        ? appLocalizations.online
        : appLocalizations.offline;
    final items = <OverlayNetworkDetailItem>[
      if (details.node.isNotEmpty)
        (name: 'ID', value: details.node, copyable: true),
      (name: appLocalizations.status, value: status, copyable: false),
      for (var index = 0; index < details.addresses.length; index++)
        (
          name: index == 0 ? appLocalizations.address : '',
          value: details.addresses[index],
          copyable: true,
        ),
    ];
    return ListItem(
      leading: Icon(Icons.devices_outlined, color: color),
      title: Text(
        details.node.isNotEmpty ? details.node : appLocalizations.local,
      ),
      subtitle: details.addresses.isEmpty
          ? null
          : Text(details.addresses.join('\n')),
      trailing: Text(
        status,
        style: context.textTheme.bodyMedium?.copyWith(color: color),
      ),
      onTap: items.isEmpty
          ? null
          : () {
              dialogs.showCommonDialog(
                child: OverlayNetworkDetailsDialog(
                  title: appLocalizations.details(appLocalizations.local),
                  items: items,
                ),
              );
            },
    );
  }
}

IconData _peerIcon(String role) {
  return switch (role.toLowerCase()) {
    'planet' => Icons.public,
    'leaf' => Icons.device_hub,
    _ => Icons.hub_outlined,
  };
}

class _ZeroTierPeerItem extends StatelessWidget {
  final ZeroTierPeer peer;

  const _ZeroTierPeerItem({required this.peer});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final summary = [
      peer.role,
      peer.version,
      if (peer.direct) appLocalizations.direct,
    ].where((value) => value.isNotEmpty).toList();
    final color = peer.direct
        ? context.colorScheme.primary
        : context.colorScheme.outline;
    final items = <OverlayNetworkDetailItem>[
      if (peer.address.isNotEmpty)
        (name: 'ID', value: peer.address, copyable: true),
      if (peer.direct)
        (
          name: appLocalizations.status,
          value: appLocalizations.direct,
          copyable: false,
        ),
      if (peer.role.isNotEmpty)
        (name: appLocalizations.role, value: peer.role, copyable: false),
      if (peer.version.isNotEmpty)
        (name: appLocalizations.version, value: peer.version, copyable: false),
      if (peer.latencyMs > 0)
        (
          name: appLocalizations.delay,
          value: '${peer.latencyMs} ms',
          copyable: false,
        ),
      for (var index = 0; index < peer.endpoints.length; index++)
        (
          name: index == 0 ? appLocalizations.endpoints : '',
          value: peer.endpoints[index],
          copyable: true,
        ),
    ];
    return ListItem(
      leading: Icon(_peerIcon(peer.role), color: color),
      title: Text(peer.address),
      subtitle: summary.isEmpty ? null : Text(summary.join(' · ')),
      trailing: peer.latencyMs > 0
          ? Text(
              '${peer.latencyMs} ms',
              style: context.textTheme.bodyMedium?.copyWith(
                color: getDelayColor(peer.latencyMs),
              ),
            )
          : null,
      onTap: () {
        dialogs.showCommonDialog(
          child: OverlayNetworkDetailsDialog(
            title: appLocalizations.details(peer.address),
            items: items,
          ),
        );
      },
    );
  }
}

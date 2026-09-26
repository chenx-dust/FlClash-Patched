import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/networking/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

List<Widget> buildEasyTierChildren({
  required BuildContext context,
  required OverlayNetworkStatus status,
  required EasyTierNetworkDetails details,
  required Widget? statusErrorItem,
  required Widget? activationItem,
}) {
  final l10n = context.appLocalizations;
  final networkTitle = status.networkName.isEmpty
      ? l10n.network
      : status.networkName;
  final instanceId = details.instanceId.isNotEmpty
      ? details.instanceId
      : details.local.instanceId;
  final networkItems = <OverlayNetworkDetailItem>[
    if (instanceId.isNotEmpty)
      (name: l10n.easyTierInstanceId, value: instanceId, copyable: true),
    if (details.local.version.isNotEmpty)
      (name: l10n.version, value: details.local.version, copyable: false),
    if (details.dnsZone.isNotEmpty)
      (name: l10n.easyTierDnsZone, value: details.dnsZone, copyable: true),
    if (details.local.proxyCidrs.isNotEmpty)
      (
        name: l10n.routes,
        value: details.local.proxyCidrs.join(' · '),
        copyable: true,
      ),
    for (var index = 0; index < details.local.listeners.length; index++)
      (
        name: index == 0 ? l10n.easyTierListeners : '',
        value: details.local.listeners[index],
        copyable: true,
      ),
  ];
  final peers = [...details.peers]
    ..sort((a, b) {
      final name = a.hostname.compareTo(b.hostname);
      return name != 0 ? name : a.ipv4.compareTo(b.ipv4);
    });
  return [
    generateSectionV3(
      isFirst: true,
      items: [
        ?statusErrorItem,
        ?activationItem,
        DecorationListItem(
          leading: const Icon(Icons.hub_outlined),
          title: Text(networkTitle),
          onPressed: networkItems.isEmpty
              ? null
              : () {
                  dialogs.showCommonDialog(
                    child: OverlayNetworkDetailsDialog(
                      title: l10n.details(networkTitle),
                      items: networkItems,
                    ),
                  );
                },
        ),
      ],
    ),
    generateSectionV3(
      title: l10n.nodes,
      items: [
        _EasyTierNodeItem(node: details.local, local: true),
        for (final peer in peers) _EasyTierNodeItem(node: peer),
      ],
    ),
  ];
}

class _EasyTierNodeItem extends StatelessWidget {
  final EasyTierNode node;
  final bool local;

  const _EasyTierNodeItem({required this.node, this.local = false});

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final title = node.hostname.isNotEmpty
        ? node.hostname
        : node.ipv4.isNotEmpty
        ? node.ipv4
        : node.peerId != 0
        ? node.peerId.toString()
        : l10n.local;
    final latencyMs = local ? 0 : node.latencyMs;
    final connectionType = switch (node.connectionType) {
      'direct' => l10n.direct,
      'relayed' => l10n.relayed,
      _ => '',
    };
    final featureFlags =
        node.featureFlags.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList()
          ..sort();
    final items = <OverlayNetworkDetailItem>[
      if (node.peerId != 0)
        (
          name: l10n.easyTierPeerId,
          value: node.peerId.toString(),
          copyable: true,
        ),
      if (!local && node.instanceId.isNotEmpty)
        (name: l10n.easyTierInstanceId, value: node.instanceId, copyable: true),
      if (!local && node.version.isNotEmpty)
        (name: l10n.version, value: node.version, copyable: false),
      for (var index = 0; index < featureFlags.length; index++)
        (
          name: index == 0 ? l10n.easyTierFeatureFlags : '',
          value: featureFlags[index],
          copyable: false,
        ),
      if (!local && connectionType.isNotEmpty)
        (name: l10n.status, value: connectionType, copyable: false),
      if (!local && node.nextHop != 0)
        (
          name: l10n.easyTierNextHop,
          value: node.nextHop.toString(),
          copyable: true,
        ),
      if (!local && node.cost > 0)
        (
          name: l10n.easyTierRouteCost,
          value: node.cost.toString(),
          copyable: false,
        ),
      if (!local && node.proxyCidrs.isNotEmpty)
        (name: l10n.routes, value: node.proxyCidrs.join('\n'), copyable: true),
      if (!local)
        for (var index = 0; index < node.listeners.length; index++)
          (
            name: index == 0 ? l10n.easyTierListeners : '',
            value: node.listeners[index],
            copyable: true,
          ),
      if (!local && node.pathLatencyMs != null)
        (
          name: l10n.easyTierPathLatency,
          value: '${node.pathLatencyMs} ms',
          copyable: false,
        ),
      if (!local && node.latencyFirstPathLatencyMs != null)
        (
          name: l10n.easyTierLatencyFirstPathLatency,
          value: '${node.latencyFirstPathLatencyMs} ms',
          copyable: false,
        ),
      if (latencyMs > 0)
        (
          name: l10n.easyTierMinDirectLatency,
          value: '$latencyMs ms',
          copyable: false,
        ),
      if (node.hostname.isNotEmpty)
        (name: l10n.host, value: node.hostname, copyable: true),
      if (node.ipv4.isNotEmpty)
        (name: 'IPv4', value: node.ipv4, copyable: true),
    ];
    for (final (index, conn) in node.connections.indexed) {
      items.addAll([
        (
          name: '${l10n.connections} ${index + 1}',
          value: conn.id,
          copyable: conn.id.isNotEmpty,
        ),
        if (conn.protocol.isNotEmpty)
          (name: l10n.easyTierProtocol, value: conn.protocol, copyable: false),
        if (conn.localEndpoint.isNotEmpty)
          (
            name: l10n.easyTierLocalEndpoint,
            value: conn.localEndpoint,
            copyable: true,
          ),
        if (conn.remoteEndpoint.isNotEmpty)
          (
            name: l10n.easyTierRemoteEndpoint,
            value: conn.remoteEndpoint,
            copyable: true,
          ),
        if (conn.latencyMs > 0)
          (
            name: l10n.easyTierConnectionLatency,
            value: '${conn.latencyMs} ms',
            copyable: false,
          ),
        if (conn.lossRate != null && conn.lossRate! >= 0 && conn.lossRate! <= 1)
          (
            name: l10n.easyTierLossRate,
            value: '${(conn.lossRate! * 100).toStringAsFixed(2)}%',
            copyable: false,
          ),
        if (conn.rxBytes != null)
          (
            name: l10n.downloadTraffic,
            value: conn.rxBytes!.traffic.show,
            copyable: false,
          ),
        if (conn.txBytes != null)
          (
            name: l10n.uploadTraffic,
            value: conn.txBytes!.traffic.show,
            copyable: false,
          ),
        if (conn.rxPackets != null)
          (
            name: l10n.easyTierRxPackets,
            value: '${conn.rxPackets}',
            copyable: false,
          ),
        if (conn.txPackets != null)
          (
            name: l10n.easyTierTxPackets,
            value: '${conn.txPackets}',
            copyable: false,
          ),
      ]);
    }
    final subtitle = [
      if (node.hostname.isNotEmpty && node.ipv4.isNotEmpty) node.ipv4,
      if (!local && connectionType.isNotEmpty) connectionType,
      if (node.isPublicServer) l10n.easyTierPublicServer,
    ].join(' · ');
    return DecorationListItem(
      leading: Icon(
        local
            ? Icons.devices_outlined
            : node.isPublicServer
            ? Icons.public
            : Icons.device_hub,
      ),
      title: Text(title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: local
          ? Text(
              l10n.local,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.secondary,
              ),
            )
          : node.connectionType == 'relayed'
          ? Text(
              l10n.relayed,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.outline,
              ),
            )
          : latencyMs > 0
          ? Text(
              '$latencyMs ms',
              style: context.textTheme.bodyMedium?.copyWith(
                color: getDelayColor(latencyMs),
              ),
            )
          : null,
      onPressed: items.isEmpty
          ? null
          : () {
              dialogs.showCommonDialog(
                child: OverlayNetworkDetailsDialog(
                  title: l10n.details(title),
                  items: items,
                ),
              );
            },
    );
  }
}

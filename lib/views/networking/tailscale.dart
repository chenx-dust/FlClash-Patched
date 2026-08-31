import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/networking/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

List<Widget> buildTailscaleChildren({
  required BuildContext context,
  required CoreController controller,
  required OverlayNetworkStatus status,
  required TailscaleNetworkDetails details,
  required bool loggingOut,
  required VoidCallback onLogout,
  required Widget? statusErrorItem,
  required Widget? activationItem,
}) {
  final appLocalizations = context.appLocalizations;
  return [
    ...generateSection(
      isFirst: true,
      items: [
        ?statusErrorItem,
        ?activationItem,
        if (status.authUrl.isNotEmpty)
          OverlayNetworkLoginItem(url: status.authUrl),
        if (const {
          OverlayNetworkState.connected,
          OverlayNetworkState.needsApproval,
        }.contains(status.state))
          _AccountItem(
            tailnetName: status.networkName,
            busy: loggingOut,
            onLogout: details.authKeyConfigured ? null : onLogout,
          ),
        if (details.health.isNotEmpty)
          ListItem(
            leading: Icon(
              Icons.health_and_safety_outlined,
              color: context.colorScheme.error,
            ),
            title: Text(appLocalizations.tailscaleHealthWarnings),
            subtitle: Text(details.health.join('\n')),
          ),
      ],
    ),
    ...generateSection(
      title: appLocalizations.nodes,
      isFirst: true,
      items: [
        for (final node in details.nodes)
          _TailscaleNodeItem(
            key: ValueKey('${status.name}\u0000${node.id}'),
            controller: controller,
            proxyName: status.name,
            node: node,
            displayName: _tailscaleNodeDisplayName(
              node,
              details.magicDnsSuffix,
            ),
          ),
      ],
    ),
  ];
}

String _tailscaleNodeDisplayName(TailscaleNode node, String magicDnsSuffix) {
  final dnsName = node.dnsName.endsWith('.')
      ? node.dnsName.substring(0, node.dnsName.length - 1)
      : node.dnsName;
  final suffix = magicDnsSuffix.endsWith('.')
      ? magicDnsSuffix.substring(0, magicDnsSuffix.length - 1)
      : magicDnsSuffix;
  final qualifiedSuffix = '.$suffix';
  if (suffix.isNotEmpty &&
      dnsName.length > qualifiedSuffix.length &&
      dnsName.toLowerCase().endsWith(qualifiedSuffix.toLowerCase())) {
    return dnsName.substring(0, dnsName.length - qualifiedSuffix.length);
  }
  if (node.hostName.isNotEmpty) {
    return node.hostName;
  }
  return node.id;
}

IconData _nodeIcon(String os) {
  return switch (os.toLowerCase()) {
    'android' => Icons.android,
    'chrome' => Icons.laptop_chromebook,
    'ios' || 'macos' || 'tvos' => Icons.apple,
    'linux' => Icons.terminal,
    'windows' => Icons.desktop_windows_outlined,
    _ => Icons.device_unknown,
  };
}

class _AccountItem extends StatelessWidget {
  final String tailnetName;
  final bool busy;
  final VoidCallback? onLogout;

  const _AccountItem({
    required this.tailnetName,
    required this.busy,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ListItem(
      leading: const Icon(Icons.account_circle_outlined),
      title: Text(appLocalizations.account),
      subtitle: Text(
        tailnetName.isNotEmpty ? tailnetName : appLocalizations.signedIn,
      ),
      trailing: onLogout == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: busy ? null : onLogout,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CommonCircleLoading(),
                    )
                  : const Icon(Icons.logout),
              label: Text(appLocalizations.signOut),
            ),
    );
  }
}

class _TailscaleNodeItem extends StatefulWidget {
  final CoreController controller;
  final String proxyName;
  final TailscaleNode node;
  final String displayName;

  const _TailscaleNodeItem({
    super.key,
    required this.controller,
    required this.proxyName,
    required this.node,
    required this.displayName,
  });

  @override
  State<_TailscaleNodeItem> createState() => _TailscaleNodeItemState();
}

class _TailscaleNodeItemState extends State<_TailscaleNodeItem> {
  bool _testing = false;
  int? _latencyMs;

  Widget _buildDelayText(BuildContext context) {
    final measure = globalState.measure;
    return SizedBox(
      width: measure.bodyMediumHeight * 4,
      height: measure.bodyMediumHeight,
      child: FadeThroughBox(
        alignment: Alignment.centerRight,
        child: _testing
            ? SizedBox.square(
                dimension: measure.bodyMediumHeight,
                child: const CommonCircleLoading(),
              )
            : GestureDetector(
                onTap: widget.node.self || widget.node.ips.isEmpty
                    ? null
                    : _ping,
                child: _latencyMs == null
                    ? Icon(Icons.bolt, size: measure.bodyMediumHeight)
                    : Text(
                        '$_latencyMs ms',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: getDelayColor(_latencyMs!),
                        ),
                      ),
              ),
      ),
    );
  }

  Future<void> _ping() async {
    if (_testing || widget.node.ips.isEmpty) {
      return;
    }
    setState(() {
      _testing = true;
    });
    try {
      final result = await widget.controller.pingTailscaleNode(
        widget.proxyName,
        widget.node.ips.first,
      );
      if (mounted) {
        setState(() {
          _latencyMs = result.latencyMs;
        });
      }
    } catch (error) {
      if (mounted) {
        context.showSnackBar(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final node = widget.node;
    final summary = [
      if (node.os.isNotEmpty) node.os,
      if (node.ips.isNotEmpty) node.ips.first,
    ];
    final color = node.online
        ? context.colorScheme.primary
        : context.colorScheme.outline;
    return ListItem(
      leading: Icon(_nodeIcon(node.os), color: color),
      title: Text(widget.displayName),
      subtitle: summary.isEmpty ? null : Text(summary.join(' · ')),
      trailing: !node.self && node.online
          ? _buildDelayText(context)
          : Text(
              node.self ? appLocalizations.local : appLocalizations.offline,
              style: context.textTheme.bodyMedium?.copyWith(color: color),
            ),
      onTap: () {
        dialogs.showCommonDialog(
          child: _TailscaleNodeDetailsDialog(
            node: node,
            displayName: widget.displayName,
          ),
        );
      },
    );
  }
}

class _TailscaleNodeDetailsDialog extends StatelessWidget {
  final TailscaleNode node;
  final String displayName;

  const _TailscaleNodeDetailsDialog({
    required this.node,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final labels = [
      node.online ? appLocalizations.online : appLocalizations.offline,
      if (node.active) appLocalizations.tailscaleActive,
      if (node.self) appLocalizations.local,
      if (node.exitNode) appLocalizations.tailscaleExitNode,
      if (node.exitNodeOption && !node.exitNode)
        appLocalizations.tailscaleExitNodeAvailable,
      if (node.expired) appLocalizations.tailscaleKeyExpired,
    ];
    final items = <OverlayNetworkDetailItem>[
      if (node.hostName.isNotEmpty)
        (name: appLocalizations.host, value: node.hostName, copyable: true),
      if (node.id.isNotEmpty) (name: 'ID', value: node.id, copyable: true),
      (
        name: appLocalizations.status,
        value: labels.join(' · '),
        copyable: false,
      ),
      if (node.os.isNotEmpty)
        (name: appLocalizations.system, value: node.os, copyable: false),
      if (node.tags.isNotEmpty)
        (
          name: appLocalizations.tailscaleTags,
          value: node.tags.join(' · '),
          copyable: true,
        ),
      if (node.dnsName.isNotEmpty)
        (
          name: appLocalizations.tailscaleDnsName,
          value: node.dnsName,
          copyable: true,
        ),
      for (var index = 0; index < node.ips.length; index++)
        (
          name: index == 0 ? appLocalizations.address : '',
          value: node.ips[index],
          copyable: true,
        ),
      if (node.publicKey.isNotEmpty)
        (
          name: appLocalizations.tailscaleNodeKey,
          value: node.publicKey,
          copyable: true,
        ),
      for (var index = 0; index < node.primaryRoutes.length; index++)
        (
          name: index == 0 ? appLocalizations.tailscaleSubnets : '',
          value: node.primaryRoutes[index],
          copyable: true,
        ),
      if (node.currentEndpoint.isNotEmpty)
        (
          name: appLocalizations.tailscaleCurrentEndpoint,
          value: node.currentEndpoint,
          copyable: true,
        ),
      if (node.relay.isNotEmpty)
        (
          name: appLocalizations.tailscaleRelay,
          value: node.relay,
          copyable: false,
        ),
      if (node.rxBytes > 0 || node.txBytes > 0)
        (
          name: 'RX / TX',
          value: '${node.rxBytes} B / ${node.txBytes} B',
          copyable: false,
        ),
      if (!node.online && node.lastSeen != null)
        (
          name: appLocalizations.tailscaleLastSeen,
          value: node.lastSeen!.getLastUpdateTimeDesc(context),
          copyable: false,
        ),
      if (node.lastHandshake != null)
        (
          name: appLocalizations.tailscaleLastHandshake,
          value: node.lastHandshake!.getLastUpdateTimeDesc(context),
          copyable: false,
        ),
      if (node.keyExpiry != null)
        (
          name: appLocalizations.tailscaleKeyExpiry,
          value: node.keyExpiry!.showFull,
          copyable: false,
        ),
      for (var index = 0; index < node.endpoints.length; index++)
        (
          name: index == 0 ? appLocalizations.tailscaleEndpoints : '',
          value: node.endpoints[index],
          copyable: true,
        ),
    ];
    return OverlayNetworkDetailsDialog(
      title: appLocalizations.details(displayName),
      items: items,
    );
  }
}

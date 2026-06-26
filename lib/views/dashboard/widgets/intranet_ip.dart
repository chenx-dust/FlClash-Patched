import 'dart:io';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IntranetIP extends ConsumerWidget {
  const IntranetIP({super.key});

  void _showInterfaceIpDialog() {
    globalState.showCommonDialog(child: const _IntranetIpDialog());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final localIp = ref.watch(localIpProvider);
    final titleTextStyle = context.colorScheme.onSurfaceVariant;
    final descTextStyle = context.textTheme.titleSmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onLongPress: _showInterfaceIpDialog,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              height: globalState.measure.titleMediumHeight + 16,
              padding: baseInfoEdgeInsets.copyWith(bottom: 0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(Icons.devices, color: titleTextStyle),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 1,
                    child: TooltipText(
                      text: Text(
                        appLocalizations.intranetIP,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: descTextStyle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AspectRatio(
                    aspectRatio: 1,
                    child: ExcludeFocus(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: _showInterfaceIpDialog,
                        icon: Icon(
                          size: 16.ap,
                          Icons.info_outline,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: baseInfoEdgeInsets.copyWith(top: 0),
              child: SizedBox(
                height: globalState.measure.bodyMediumHeight + 2,
                child: FadeThroughBox(
                  child: localIp != null
                      ? TooltipText(
                          text: Text(
                            localIp.isNotEmpty
                                ? localIp
                                : appLocalizations.noNetwork,
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(2),
                          child: const AspectRatio(
                            aspectRatio: 1,
                            child: CommonCircleLoading(),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntranetIpDialog extends StatefulWidget {
  const _IntranetIpDialog();

  @override
  State<_IntranetIpDialog> createState() => _IntranetIpDialogState();
}

class _IntranetIpDialogState extends State<_IntranetIpDialog> {
  late final Future<List<NetworkInterface>> _future = utils
      .getLocalNetworkInterfaces();

  Widget _buildItem(
    BuildContext context,
    String name,
    InternetAddress address,
    double nameWidth,
    TextStyle? nameStyle,
  ) {
    final ip = address.address;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          SizedBox(
            width: nameWidth,
            child: TooltipText(
              text: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: TooltipText(
              text: Text(
                ip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: context.textTheme.bodyMedium?.toLight,
              ),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: context.appLocalizations.copy,
        icon: const Icon(Icons.content_copy, size: 14),
        onPressed: ip.isNotEmpty ? () => copyText(context, ip) : null,
      ),
    );
  }

  double _getMaxNameWidth(
    List<NetworkInterface> items,
    TextStyle? nameStyle,
    BoxConstraints constraints,
  ) {
    double maxWidth = 0;
    for (final interface in items) {
      final width = globalState.measure
          .computeTextSize(Text(interface.name, style: nameStyle))
          .width;
      if (width > maxWidth) {
        maxWidth = width;
      }
    }
    return min(maxWidth + 18, constraints.maxWidth * 0.4);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final nameStyle = context.textTheme.bodyMedium;
    return CommonDialog(
      title: appLocalizations.intranetIP,
      maxWidth: 480,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: FutureBuilder<List<NetworkInterface>>(
        future: _future,
        builder: (context, snapshot) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final items = snapshot.data ?? [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CommonCircleLoading()),
                );
              }
              if (items.isEmpty) {
                return Text(appLocalizations.noNetwork);
              }
              final nameWidth = _getMaxNameWidth(items, nameStyle, constraints);
              final children = <Widget>[];
              for (final interface in items) {
                if (children.isNotEmpty) {
                  children.add(const Divider(height: 0));
                }
                bool isFirst = true;
                for (final address in interface.sortedAddresses) {
                  children.add(
                    _buildItem(
                      context,
                      isFirst ? interface.name : '',
                      address,
                      nameWidth,
                      nameStyle,
                    ),
                  );
                  isFirst = false;
                }
              }
              return Column(mainAxisSize: MainAxisSize.min, children: children);
            },
          );
        },
      ),
    );
  }
}

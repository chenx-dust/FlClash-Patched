import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tracker_info_filter.dart';

String _ruleText(TrackerInfo trackerInfo) {
  final rule = trackerInfo.rule;
  final rulePayload = trackerInfo.rulePayload;
  if (rulePayload.isNotEmpty) {
    return '$rule($rulePayload)';
  }
  return rule;
}

class TrackerInfoItem extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final Function(String)? onClickKeyword;
  final Widget? trailing;
  final String detailTitle;
  final TrackerInfoFilter filter;
  final void Function(TrackerInfoFilterType type, String value)? onClickFilter;
  final VoidCallback? onDetailClosed;

  const TrackerInfoItem({
    super.key,
    required this.trackerInfo,
    this.onClickKeyword,
    this.trailing,
    required this.detailTitle,
    this.filter = const TrackerInfoFilter(),
    this.onClickFilter,
    this.onDetailClosed,
  });

  Widget _buildMeta(BuildContext context) {
    final traffic = Traffic(up: trackerInfo.upload, down: trackerInfo.download);
    final chains = trackerInfo.chains;
    final rule = _ruleText(trackerInfo);
    final speed = trackerInfo.hasSpeed
        ? Traffic(
            up: trackerInfo.uploadSpeed ?? 0,
            down: trackerInfo.downloadSpeed ?? 0,
          ).speedDesc
        : '';
    final metaText = [
      trackerInfo.start.getLastUpdateTimeDesc(context),
      traffic.desc,
      if (speed.isNotEmpty) speed,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            metaText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (chains.isNotEmpty || rule.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _ProxyChain(
              chains: chains,
              rule: rule,
              chipBuilder: (chain) {
                final colorScheme = context.colorScheme;
                return TonalChip(
                  label: chain,
                  color: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                  onPressed: () {
                    final onClickFilter = this.onClickFilter;
                    if (onClickFilter != null) {
                      onClickFilter(TrackerInfoFilterType.chain, chain);
                      return;
                    }
                    onClickKeyword?.call(chain);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final showIcon = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always && system.isAndroid,
      ),
    );
    final process = trackerInfo.metadata.process;
    final icon = showIcon
        ? GestureDetector(
            onTap: () {
              if (process.isEmpty) return;
              final onClickFilter = this.onClickFilter;
              if (onClickFilter != null) {
                onClickFilter(TrackerInfoFilterType.process, process);
                return;
              }
              onClickKeyword?.call(process);
            },
            child: Padding(
              padding: const EdgeInsetsGeometry.only(top: 6),
              child: PackageIcon(packageName: process, size: 44),
            ),
          )
        : null;
    return ListItem(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ).copyWith(bottom: 12),
      minVerticalPadding: 0,
      horizontalTitleGap: 12,
      tileTitleAlignment: ListTileTitleAlignment.top,
      onTap: () async {
        await showExtend(
          context,
          builder: (_) {
            return AdaptiveSheetScaffold(
              sheetTransparentToolBar: true,
              body: TrackerInfoDetailView(
                trackerInfo: trackerInfo,
                filter: filter,
                onClickFilter: onClickFilter,
              ),
              title: detailTitle,
            );
          },
        );
        onDetailClosed?.call();
      },
      leading: icon,
      title: Text(
        trackerInfo.desc,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyLarge,
      ),
      subtitle: _buildMeta(context),
      trailing: trailing,
    );
  }
}

class TrackerInfoDetailView extends StatefulWidget {
  final TrackerInfo trackerInfo;
  final TrackerInfoFilter filter;
  final void Function(TrackerInfoFilterType type, String value)? onClickFilter;

  const TrackerInfoDetailView({
    super.key,
    required this.trackerInfo,
    this.filter = const TrackerInfoFilter(),
    this.onClickFilter,
  });

  @override
  State<TrackerInfoDetailView> createState() => _TrackerInfoDetailViewState();
}

class _TrackerInfoDetailViewState extends State<TrackerInfoDetailView> {
  late TrackerInfoFilter _filter;

  TrackerInfo get trackerInfo => widget.trackerInfo;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
  }

  void _applyFilter(TrackerInfoFilterType type, String value) {
    widget.onClickFilter?.call(type, value);
    setState(() {
      _filter = _filter.toggle(type, value);
    });
  }

  String _getProcessText() {
    final process = trackerInfo.metadata.process;
    final uid = trackerInfo.metadata.uid;
    if (uid != 0) {
      return '$process($uid)';
    }
    return process;
  }

  String _getEndpointText(String ip, String port) {
    if (ip.isEmpty) {
      return '';
    }
    if (port.isNotEmpty) {
      return '$ip:$port';
    }
    return ip;
  }

  Widget _buildChains(BuildContext context) {
    return DecorationListItem(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Text(context.appLocalizations.proxyChains),
          Flexible(
            child: _ProxyChain(
              chains: trackerInfo.chains,
              alignment: WrapAlignment.end,
              chipBuilder: (chain) {
                final chip = MetaChip(label: chain);
                if (widget.onClickFilter == null) {
                  return chip;
                }
                return GestureDetector(
                  onTap: () => _applyFilter(TrackerInfoFilterType.chain, chain),
                  child: chip,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRows(
    List<(String, String, TrackerInfoFilterType?, String?)> entries,
  ) {
    return [
      for (final (title, value, filterType, filterValue) in entries)
        if (value.isNotEmpty)
          _DetailRow(
            title: title,
            value: value,
            filtered:
                filterType != null &&
                filterValue != null &&
                _filter.contains(filterType, filterValue),
            onFilter:
                widget.onClickFilter != null &&
                    filterType != null &&
                    filterValue?.isNotEmpty == true
                ? () => _applyFilter(filterType, filterValue!)
                : null,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final metadata = trackerInfo.metadata;
    return ListView(
      padding: sectionPagePadding.copyWith(top: context.sheetTopPadding),
      children: [
        generateSectionV3(
          title: appLocalizations.basicInfo,
          isFirst: true,
          items: _buildRows([
            (
              appLocalizations.creationTime,
              trackerInfo.start.toLocal().showFull,
              null,
              null,
            ),
            (
              appLocalizations.networkType,
              metadata.network,
              TrackerInfoFilterType.network,
              metadata.network,
            ),
            (
              appLocalizations.process,
              _getProcessText(),
              TrackerInfoFilterType.process,
              metadata.process,
            ),
            (
              appLocalizations.rule,
              _ruleText(trackerInfo),
              TrackerInfoFilterType.rule,
              _ruleText(trackerInfo),
            ),
            (
              appLocalizations.upload,
              trackerInfo.upload.traffic.show,
              null,
              null,
            ),
            (
              appLocalizations.download,
              trackerInfo.download.traffic.show,
              null,
              null,
            ),
          ]),
        ),
        generateSectionV3(
          title: appLocalizations.address,
          items: _buildRows([
            (appLocalizations.host, metadata.host, null, null),
            (
              appLocalizations.source,
              _getEndpointText(metadata.sourceIP, metadata.sourcePort),
              null,
              null,
            ),
            (
              appLocalizations.destination,
              _getEndpointText(
                metadata.destinationIP,
                metadata.destinationPort,
              ),
              null,
              null,
            ),
            (
              appLocalizations.destinationGeoIP,
              metadata.destinationGeoIP.join(' '),
              null,
              null,
            ),
            (
              appLocalizations.destinationIPASN,
              metadata.destinationIPASN,
              null,
              null,
            ),
            (
              appLocalizations.remoteDestination,
              metadata.remoteDestination,
              null,
              null,
            ),
          ]),
        ),
        generateSectionV3(
          title: appLocalizations.proxies,
          items: [
            ..._buildRows([
              (
                appLocalizations.specialProxy,
                metadata.specialProxy,
                null,
                null,
              ),
              (
                appLocalizations.specialRules,
                metadata.specialRules,
                null,
                null,
              ),
              (
                appLocalizations.dnsMode,
                metadata.dnsMode?.name ?? '',
                null,
                null,
              ),
            ]),
            _buildChains(context),
          ],
        ),
      ],
    );
  }
}

class _ProxyChain extends StatelessWidget {
  final List<String> chains;
  final String rule;
  final WrapAlignment alignment;
  final Widget Function(String chain) chipBuilder;

  const _ProxyChain({
    required this.chains,
    required this.chipBuilder,
    this.rule = '',
    this.alignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final showRule = rule.isNotEmpty;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showRule)
          Text(
            rule,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        for (final (index, chain) in chains.reversed.indexed)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (index > 0 || showRule) const _ProxyChainArrow(),
              Flexible(child: chipBuilder(chain)),
            ],
          ),
      ],
    );
  }
}

class _ProxyChainArrow extends StatelessWidget {
  const _ProxyChainArrow();

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.outline,
    );
    return Text('→', style: style?.toJetBrainsMono);
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;
  final bool filtered;
  final VoidCallback? onFilter;

  const _DetailRow({
    required this.title,
    required this.value,
    this.filtered = false,
    this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      onPressed: onFilter ?? () => copyText(context, value),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Row(
            spacing: 4,
            children: [
              Text(title),
              if (onFilter != null)
                Icon(
                  filtered ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 18,
                ),
            ],
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

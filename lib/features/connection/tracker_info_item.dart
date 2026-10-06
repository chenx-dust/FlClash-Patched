import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'tracker_info_filter.dart';

String _ruleText(TrackerInfo trackerInfo) {
  final rule = trackerInfo.rule;
  final rulePayload = trackerInfo.rulePayload;
  if (rulePayload.isNotEmpty) {
    return '$rule($rulePayload)';
  }
  return rule;
}

String _endpointText(String ip, String port) {
  if (ip.isEmpty) {
    return '';
  }
  if (port.isNotEmpty) {
    return '$ip:$port';
  }
  return ip;
}

class TrackerInfoItem extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final bool isLive;
  final Function(String)? onClickKeyword;
  final Widget? trailing;
  final String detailTitle;
  final TrackerInfoFilter filter;
  final void Function(TrackerInfoFilterType type, String value)? onClickFilter;
  final VoidCallback? onDetailClosed;

  const TrackerInfoItem({
    super.key,
    required this.trackerInfo,
    this.isLive = false,
    this.onClickKeyword,
    this.trailing,
    required this.detailTitle,
    this.filter = const TrackerInfoFilter(),
    this.onClickFilter,
    this.onDetailClosed,
  });

  void _select(TrackerInfoFilterType type, String value) {
    final onClickFilter = this.onClickFilter;
    if (onClickFilter != null) {
      onClickFilter(type, value);
      return;
    }
    onClickKeyword?.call(value);
  }

  @override
  Widget build(BuildContext context, ref) {
    final showIcon = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always && system.isAndroid,
      ),
    );
    return RecordListItem(
      trailing: trailing,
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
      header: _buildHeader(context),
      body: _buildBody(showIcon: showIcon),
    );
  }

  Widget _buildBody({required bool showIcon}) {
    final process = trackerInfo.metadata.process;
    final body = _TrackerInfoBody(trackerInfo: trackerInfo, onSelect: _select);
    if (!showIcon || process.isEmpty) {
      return body;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        GestureDetector(
          onTap: () => _select(TrackerInfoFilterType.process, process),
          child: PackageIcon(packageName: process, size: 40),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final network = Text(
      trackerInfo.metadata.network.toUpperCase(),
      style: const TextStyle(fontWeight: FontWeight.w500),
    );
    if (!isLive) {
      return RecordHeader(
        children: [
          RecordTimestamp(trackerInfo.start.toLocal().showFull),
          network,
        ],
      );
    }
    final color = context.colorScheme.onSurfaceVariant;
    WidgetSpan arrow(IconData icon) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(icon, size: 12, color: color),
    );
    return RecordHeader(
      trailing: Text.rich(
        TextSpan(
          children: [
            arrow(Symbols.arrow_upward),
            TextSpan(
              text: ' ${(trackerInfo.uploadSpeed ?? 0).traffic.show}/s   ',
            ),
            arrow(Symbols.arrow_downward),
            TextSpan(
              text: ' ${(trackerInfo.downloadSpeed ?? 0).traffic.show}/s',
            ),
          ],
        ),
      ),
      children: [
        Text(trackerInfo.start.getLastUpdateTimeDesc(context)),
        network,
      ],
    );
  }
}

class _TrackerInfoBody extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final void Function(TrackerInfoFilterType type, String value) onSelect;

  const _TrackerInfoBody({required this.trackerInfo, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = RecordTextStyles.of(context);
    final metadata = trackerInfo.metadata;
    final rule = _ruleText(trackerInfo);
    final source = [
      trackerInfo.progressText,
      _endpointText(metadata.sourceIP, metadata.sourcePort),
    ].where((text) => text.isNotEmpty).join('  ·  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _endpointText(
                  trackerInfo.title,
                  metadata.destinationPort,
                ),
                style: styles.primary?.copyWith(fontWeight: FontWeight.w500),
              ),
              if (metadata.host.isNotEmpty && metadata.destinationIP.isNotEmpty)
                TextSpan(
                  text: '  ${metadata.destinationIP}',
                  style: styles.muted,
                ),
            ],
          ),
        ),
        ProxyChain(
          chain: trackerInfo.chains.reversed,
          hideTooMany: ref.watch(
            appSettingProvider.select((state) => state.collapseProxyChains),
          ),
          leading: rule.isNotEmpty ? Text(rule, style: styles.secondary) : null,
          onSelected: (chain) => onSelect(TrackerInfoFilterType.chain, chain),
        ),
        if (source.isNotEmpty) Text(source, style: styles.muted),
      ],
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

  Widget _buildChains(BuildContext context) {
    return DetailRow(
      title: context.appLocalizations.proxyChains,
      value: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (index, chain) in trackerInfo.chains.reversed.indexed)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (index > 0) const RecordArrow(),
                Flexible(
                  child: _ChainChip(
                    label: chain,
                    onTap: widget.onClickFilter == null
                        ? null
                        : () =>
                              _applyFilter(TrackerInfoFilterType.chain, chain),
                  ),
                ),
              ],
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
              trackerInfo.progressText,
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
              _endpointText(metadata.sourceIP, metadata.sourcePort),
              null,
              null,
            ),
            (
              appLocalizations.destination,
              _endpointText(metadata.destinationIP, metadata.destinationPort),
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

class _ChainChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ChainChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chip = MetaChip(label: label);
    final onTap = this.onTap;
    if (onTap == null) {
      return chip;
    }
    return GestureDetector(onTap: onTap, child: chip);
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
        spacing: 20,
        children: [
          Row(
            spacing: 4,
            children: [
              Text(title),
              if (onFilter != null)
                Icon(Symbols.filter_alt, size: 18, fill: filtered ? 1 : 0),
            ],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

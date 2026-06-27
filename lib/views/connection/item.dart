import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/connection/filter.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackerInfoItem extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final Function(String)? onClickKeyword;
  final void Function(TrackerInfoFilterType type, String value)? onClickFilter;
  final Future<void> Function()? onDetailClosed;
  final Widget? trailing;
  final String detailTitle;

  const TrackerInfoItem({
    super.key,
    required this.trackerInfo,
    this.onClickKeyword,
    this.onClickFilter,
    this.onDetailClosed,
    this.trailing,
    required this.detailTitle,
  });

  static double get subTitleHeight {
    return globalState.measure.bodySmallHeight + 20;
  }

  Future<ImageProvider?> _getPackageIcon(TrackerInfo connection) async {
    return await app?.getPackageIcon(connection.metadata.process);
  }

  String _getSourceText(BuildContext context, TrackerInfo trackerInfo) {
    final progress = trackerInfo.progressText.isNotEmpty
        ? '${trackerInfo.progressText} · '
        : '';
    final traffic = Traffic(up: trackerInfo.upload, down: trackerInfo.download);
    return '${trackerInfo.chains.last} · $progress${traffic.desc}';
  }

  @override
  Widget build(BuildContext context, ref) {
    final value = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always && system.isAndroid,
      ),
    );
    final title = Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 8,
      children: [
        Flexible(
          child: Text(trackerInfo.desc, style: context.textTheme.bodyMedium),
        ),
        Text(
          trackerInfo.start.getLastUpdateTimeDesc(context),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurface.opacity60,
          ),
        ),
      ],
    );
    final subTitle = Text(
      _getSourceText(context, trackerInfo),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.labelMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
    final icon = value
        ? GestureDetector(
            onTap: () {
              final process = trackerInfo.metadata.process;
              if (process.isEmpty) return;
              if (onClickFilter != null) {
                onClickFilter!(TrackerInfoFilterType.process, process);
                return;
              }
              onClickKeyword?.call(process);
            },
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              width: 42,
              height: 42,
              child: FutureBuilder<ImageProvider?>(
                future: _getPackageIcon(trackerInfo),
                builder: (_, snapshot) {
                  if (!snapshot.hasData && snapshot.data == null) {
                    return Container();
                  } else {
                    return Image(
                      image: snapshot.data!,
                      gaplessPlayback: true,
                      width: 42,
                      height: 42,
                    );
                  }
                },
              ),
            ),
          )
        : null;
    return ListItem(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () async {
        await showExtend(
          context,
          builder: (_) {
            return AdaptiveSheetScaffold(
              body: TrackerInfoDetailView(
                trackerInfo: trackerInfo,
                onClickFilter: onClickFilter,
              ),
              title: detailTitle,
            );
          },
        );
        await onDetailClosed?.call();
      },
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              ?icon,
              Flexible(child: title),
            ],
          ),
          const SizedBox(height: 8),
          subTitle,
        ],
      ),
    );
  }
}

class TrackerInfoDetailView extends StatelessWidget {
  final TrackerInfo trackerInfo;
  final void Function(TrackerInfoFilterType type, String value)? onClickFilter;

  const TrackerInfoDetailView({
    super.key,
    required this.trackerInfo,
    this.onClickFilter,
  });

  String _getRuleText() {
    final rule = trackerInfo.rule;
    final rulePayload = trackerInfo.rulePayload;
    if (rulePayload.isNotEmpty) {
      return '$rule($rulePayload)';
    }
    return rule;
  }

  String _getProcessText() {
    final process = trackerInfo.metadata.process;
    final uid = trackerInfo.metadata.uid;
    if (uid != 0) {
      return '$process($uid)';
    }
    return process;
  }

  String _getSourceText() {
    final sourceIP = trackerInfo.metadata.sourceIP;
    if (sourceIP.isEmpty) {
      return '';
    }
    final sourcePort = trackerInfo.metadata.sourcePort;
    if (sourcePort.isNotEmpty) {
      return '$sourceIP:$sourcePort';
    }
    return sourceIP;
  }

  String _getDestinationText() {
    final destinationIP = trackerInfo.metadata.destinationIP;
    if (destinationIP.isEmpty) {
      return '';
    }
    final destinationPort = trackerInfo.metadata.destinationPort;
    if (destinationPort.isNotEmpty) {
      return '$destinationIP:$destinationPort';
    }
    return destinationIP;
  }

  Widget _buildChains(BuildContext context) {
    final filterable = onClickFilter != null;
    final chains = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        for (final chain in trackerInfo.chains)
          CommonChip(
            label: chain,
            labelStyle: context.textTheme.labelMedium,
            onPressed: filterable
                ? () {
                    onClickFilter!(TrackerInfoFilterType.chain, chain);
                  }
                : null,
          ),
      ],
    );
    return ListItem(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Text(context.appLocalizations.proxyChains),
          Flexible(child: chains),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String title,
    required String desc,
    bool quickCopy = false,
    TrackerInfoFilterType? filterType,
    String? filterValue,
  }) {
    final canFilter =
        filterType != null &&
        filterValue?.isNotEmpty == true &&
        onClickFilter != null;
    return ListItem(
      onTap: canFilter
          ? () {
              onClickFilter!(filterType, filterValue!);
            }
          : null,
      title: Row(
        spacing: 16,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 4,
            children: [
              Text(title),
              if (canFilter) const Icon(Icons.filter_alt_outlined, size: 18),
              if (quickCopy)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.content_copy, size: 18),
                    onPressed: () {},
                  ),
                ),
            ],
          ),
          Flexible(child: Text(desc, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final items = [
      _buildItem(
        title: appLocalizations.creationTime,
        desc: trackerInfo.start.showFull,
      ),
      if (_getProcessText().isNotEmpty)
        _buildItem(
          title: appLocalizations.process,
          desc: _getProcessText(),
          filterType: TrackerInfoFilterType.process,
          filterValue: trackerInfo.metadata.process,
        ),
      _buildItem(
        title: appLocalizations.networkType,
        desc: trackerInfo.metadata.network,
        filterType: TrackerInfoFilterType.network,
        filterValue: trackerInfo.metadata.network,
      ),
      _buildItem(
        title: appLocalizations.rule,
        desc: _getRuleText(),
        filterType: TrackerInfoFilterType.rule,
        filterValue: getTrackerInfoRuleText(trackerInfo),
      ),
      if (trackerInfo.metadata.host.isNotEmpty)
        _buildItem(
          title: appLocalizations.host,
          desc: trackerInfo.metadata.host,
        ),
      if (_getSourceText().isNotEmpty)
        _buildItem(title: appLocalizations.source, desc: _getSourceText()),
      if (_getDestinationText().isNotEmpty)
        _buildItem(
          title: appLocalizations.destination,
          desc: _getDestinationText(),
        ),
      _buildItem(
        title: appLocalizations.upload,
        desc: trackerInfo.upload.traffic.show,
      ),
      _buildItem(
        title: appLocalizations.download,
        desc: trackerInfo.download.traffic.show,
      ),
      if (trackerInfo.metadata.destinationGeoIP.isNotEmpty)
        _buildItem(
          title: appLocalizations.destinationGeoIP,
          desc: trackerInfo.metadata.destinationGeoIP.join(' '),
        ),
      if (trackerInfo.metadata.destinationIPASN.isNotEmpty)
        _buildItem(
          title: appLocalizations.destinationIPASN,
          desc: trackerInfo.metadata.destinationIPASN,
        ),
      if (trackerInfo.metadata.dnsMode != null)
        _buildItem(
          title: appLocalizations.dnsMode,
          desc: trackerInfo.metadata.dnsMode!.name,
        ),
      if (trackerInfo.metadata.specialProxy.isNotEmpty)
        _buildItem(
          title: appLocalizations.specialProxy,
          desc: trackerInfo.metadata.specialProxy,
        ),
      if (trackerInfo.metadata.specialRules.isNotEmpty)
        _buildItem(
          title: appLocalizations.specialRules,
          desc: trackerInfo.metadata.specialRules,
        ),
      if (trackerInfo.metadata.remoteDestination.isNotEmpty)
        _buildItem(
          title: appLocalizations.remoteDestination,
          desc: trackerInfo.metadata.remoteDestination,
        ),
      _buildChains(context),
    ];
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: items.length,
        itemBuilder: (_, index) {
          return items[index];
        },
      ),
    );
  }
}

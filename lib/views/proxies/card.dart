import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/connection/connections.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyCard extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
  });

  Measure get measure => globalState.measure;

  void _handleTestCurrentDelay(WidgetRef ref) {
    ref.read(proxiesActionProvider.notifier).proxyDelayTest(proxy, testUrl);
  }

  Widget _buildDelayText() {
    return SizedBox(
      height: measure.labelSmallHeight,
      child: Consumer(
        builder: (context, ref, _) {
          final delay = ref.watch(
            delayProvider(proxyName: proxy.name, testUrl: testUrl),
          );
          final pending = ref.watch(
            delayTestPendingProvider(proxyName: proxy.name, testUrl: testUrl),
          );
          return FadeBox(
            alignment: type == ProxyCardType.standard
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: pending || delay == null
                ? SizedBox(
                    height: measure.labelSmallHeight,
                    width: measure.labelSmallHeight,
                    child: pending
                        ? const CommonCircleLoading()
                        : IconButton(
                            tooltip: context.appLocalizations.delayTest,
                            icon: const Icon(Symbols.bolt, fill: 1),
                            iconSize: globalState.measure.labelSmallHeight - 2,
                            padding: const EdgeInsets.all(1),
                            onPressed: () => _handleTestCurrentDelay(ref),
                          ),
                  )
                : GestureDetector(
                    onTap: () => _handleTestCurrentDelay(ref),
                    child: Text(
                      delay > 0 ? '$delay ms' : 'Timeout',
                      maxLines: 1,
                      style: context.textTheme.labelSmall?.copyWith(
                        overflow: TextOverflow.ellipsis,
                        color: getDelayColor(delay),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildProxyNameText(BuildContext context, int maxLines) {
    return SizedBox(
      height: measure.bodyMediumHeight * maxLines,
      child: EmojiText(
        proxy.name,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyMedium,
      ),
    );
  }

  Future<void> _changeProxy(WidgetRef ref) async {
    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final currentProxyName = ref.read(proxyNameProvider(groupName));
      final nextProxyName = switch (isComputedSelected) {
        true => currentProxyName == proxy.name ? '' : proxy.name,
        false => proxy.name,
      };
      ref
          .read(proxiesActionProvider.notifier)
          .changeProxyDebounce(groupName, nextProxyName);
      return;
    }
    dialogs.showNotifier(
      currentAppLocalizations.notSelectedTip,
      level: MessageLevel.warning,
    );
  }

  void _showDetails() {
    dialogs.showCommonDialog(
      child: _ProxyDetailsDialog(proxy: proxy, testUrl: testUrl),
    );
  }

  List<CommonPopupMenuItem> _menuItems(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final filter = TrackerInfoFilter(chains: {proxy.name});
    return [
      CommonPopupMenuItem(
        icon: Symbols.bolt,
        label: appLocalizations.delayTest,
        onPressed: () => _handleTestCurrentDelay(ref),
      ),
      CommonPopupMenuItem(
        icon: Symbols.view_timeline,
        label: appLocalizations.recentRequests,
        onPressed: () {
          BaseNavigator.push<void>(
            context,
            RequestsView(initialFilter: filter),
          );
        },
      ),
      CommonPopupMenuItem(
        icon: Symbols.ballot,
        label: appLocalizations.connections,
        onPressed: () {
          BaseNavigator.push<void>(
            context,
            ConnectionsView(initialFilter: filter),
          );
        },
      ),
      CommonPopupMenuItem(
        icon: Symbols.info,
        label: appLocalizations.details(appLocalizations.proxy),
        onPressed: _showDetails,
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measure = globalState.measure;
    final delayText = _buildDelayText();
    final nameMaxLines = type == ProxyCardType.min ? 1 : 2;
    final proxyNameText = _buildProxyNameText(context, nameMaxLines);
    return CommonPopupBox(
      popupBuilder: (_) => CommonPopupMenu(items: _menuItems(context, ref)),
      targetBuilder: (open) {
        void openMenu() => open(
          offset: Offset(0, measure.bodyMediumHeight * nameMaxLines + 24),
        );

        return GestureDetector(
          onSecondaryTap: openMenu,
          child: Stack(
            children: [
              Consumer(
                builder: (_, ref, child) {
                  final selectedProxyName = ref.watch(
                    selectedProxyNameProvider(groupName),
                  );
                  return CommonCard(
                    radius: AppCorner.lg,
                    key: key,
                    onPressed: () {
                      _changeProxy(ref);
                    },
                    onLongPress: openMenu,
                    isSelected: selectedProxyName == proxy.name,
                    child: child!,
                  );
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const padding = EdgeInsets.symmetric(horizontal: 12);
                    return OverflowHoverTooltip(
                      message: proxy.name,
                      maxWidth: constraints.maxWidth - padding.horizontal,
                      maxLines: nameMaxLines,
                      style: context.textTheme.bodyMedium,
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: padding,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            proxyNameText,
                            const SizedBox(height: 8),
                            if (type == ProxyCardType.standard) ...[
                              SizedBox(
                                height: measure.bodySmallHeight,
                                child: _ProxyDesc(proxy: proxy),
                              ),
                              const SizedBox(height: 6),
                              delayText,
                            ] else
                              SizedBox(
                                height: measure.bodySmallHeight,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      flex: 1,
                                      child: TooltipText(
                                        text: Text(
                                          proxy.type,
                                          maxLines: 1,
                                          style: context.textTheme.bodySmall
                                              ?.copyWith(
                                                overflow: TextOverflow.ellipsis,
                                                color: context
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color
                                                    ?.opacity80,
                                              ),
                                        ),
                                      ),
                                    ),
                                    delayText,
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (groupType.isComputedSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _ProxyComputedMark(groupName: groupName, proxy: proxy),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProxyDetailsDialog extends ConsumerWidget {
  final Proxy proxy;
  final String? testUrl;

  const _ProxyDetailsDialog({required this.proxy, required this.testUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final desc = ref.watch(proxyDescProvider(proxy));
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: testUrl),
    );
    final pending = ref.watch(
      delayTestPendingProvider(proxyName: proxy.name, testUrl: testUrl),
    );
    final features = [
      if (proxy.udp) 'UDP',
      if (proxy.uot) 'UoT',
      if (proxy.xudp) 'XUDP',
      if (proxy.tfo) 'TFO',
      if (proxy.mptcp) 'MPTCP',
      if (proxy.smux) 'SMUX',
    ];
    final items = <DetailItem>[
      (name: appLocalizations.name, value: proxy.name, copyable: true),
      (name: appLocalizations.proxyType, value: desc, copyable: false),
      if (!pending && delay != null)
        (
          name: appLocalizations.delay,
          value: delay > 0 ? '$delay ms' : appLocalizations.timeout,
          copyable: false,
        ),
      if (proxy.providerName.isNotEmpty)
        (
          name: appLocalizations.proxyProvider,
          value: proxy.providerName,
          copyable: false,
        ),
      if (proxy.dialerProxy.isNotEmpty)
        (
          name: appLocalizations.dialerProxy,
          value: proxy.dialerProxy,
          copyable: false,
        ),
      if (proxy.interface.isNotEmpty)
        (
          name: appLocalizations.interfaceName,
          value: proxy.interface,
          copyable: false,
        ),
      if (proxy.routingMark != 0)
        (
          name: appLocalizations.routingMark,
          value: '${proxy.routingMark}',
          copyable: false,
        ),
      for (var index = 0; index < features.length; index++)
        (
          name: index == 0 ? appLocalizations.features : '',
          value: features[index],
          copyable: false,
        ),
    ];
    return DetailsDialog(
      title: appLocalizations.details(appLocalizations.proxy),
      items: items,
    );
  }
}

class _ProxyDesc extends ConsumerWidget {
  final Proxy proxy;

  const _ProxyDesc({required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desc = ref.watch(proxyDescProvider(proxy));
    return EmojiText(
      desc,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.textTheme.bodySmall?.color?.opacity80,
      ),
    );
  }
}

class _ProxyComputedMark extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;

  const _ProxyComputedMark({required this.groupName, required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyName = ref.watch(proxyNameProvider(groupName));
    if (proxyName != proxy.name) {
      return const SizedBox();
    }
    return Container(
      alignment: Alignment.topRight,
      margin: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.secondaryContainer,
        ),
        child: const SelectIcon(),
      ),
    );
  }
}

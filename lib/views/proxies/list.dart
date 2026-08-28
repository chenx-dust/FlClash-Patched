import 'dart:async';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'card.dart';
import 'common.dart';

typedef GroupNameProxiesMap = Map<String, List<Proxy>>;

const _enterStaggerLimit = 8;
const _enterStaggerStep = Duration(milliseconds: 20);
const _enterSlideBase = 32.0;
const _enterSlideStep = 8.0;
final _enterWindow = commonDuration + _enterStaggerStep * _enterStaggerLimit;

class ProxiesListView extends ConsumerStatefulWidget {
  const ProxiesListView({super.key});

  @override
  ConsumerState<ProxiesListView> createState() => ProxiesListViewState();
}

class ProxiesListViewState extends ConsumerState<ProxiesListView> {
  final _controller = ScrollController();
  GroupOffsets _groupOffsets = GroupOffsets.empty;
  double containerHeight = 0;
  String? _enterGroupName;
  Timer? _enterTimer;

  @override
  void dispose() {
    _stopEnterAnimated();
    _controller.dispose();
    super.dispose();
  }

  void _startEnterAnimated(String groupName) {
    _enterTimer?.cancel();
    _enterGroupName = groupName;
    _enterTimer = Timer(_enterWindow, _stopEnterAnimated);
  }

  void _stopEnterAnimated() {
    _enterTimer?.cancel();
    _enterTimer = null;
    _enterGroupName = null;
  }

  void _handleChange(
    Set<String> currentUnfoldSet,
    String groupName,
    ProxiesListHeaderStyle listHeaderStyle,
  ) {
    _autoScrollToGroup(groupName, listHeaderStyle);
    final tempUnfoldSet = Set<String>.from(currentUnfoldSet);
    if (tempUnfoldSet.contains(groupName)) {
      tempUnfoldSet.remove(groupName);
      _stopEnterAnimated();
    } else {
      tempUnfoldSet.add(groupName);
      _startEnterAnimated(groupName);
    }
    ref
        .read(proxiesActionProvider.notifier)
        .updateCurrentUnfoldSet(tempUnfoldSet);
  }

  GroupOffsets _getGroupOffsets({
    required List<Group> groups,
    required int columns,
    required Set<String> currentUnfoldSet,
    required ProxyCardType cardType,
    required ProxiesListHeaderStyle listHeaderStyle,
  }) {
    final offsets = <double>[];
    final rowExtent = getItemHeight(cardType) + 8;
    var currentOffset = 0.0;
    for (final group in groups) {
      offsets.add(currentOffset);
      currentOffset += getListHeaderHeight(listHeaderStyle) + 8;
      if (currentUnfoldSet.contains(group.name)) {
        final rowCount = (group.all.length + columns - 1) ~/ columns;
        currentOffset += rowCount * rowExtent;
      }
    }
    return GroupOffsets(groups, offsets);
  }

  Widget _buildProxyRow({
    required Group group,
    required List<Proxy> proxies,
    required int rowIndex,
    required int columns,
    required ProxyCardType cardType,
  }) {
    final groupName = group.name;
    final enterAnimated = _enterGroupName == groupName;
    final children = proxies.indexed
        .map<Widget>((entry) {
          final (columnIndex, proxy) = entry;
          final card = SizedBox(
            height: getItemHeight(cardType),
            child: ProxyCard(
              testUrl: group.testUrl,
              type: cardType,
              groupType: group.type,
              key: ValueKey('$groupName.${proxy.name}'),
              proxy: proxy,
              groupName: groupName,
            ),
          );
          if (!enterAnimated) {
            return Flexible(child: card);
          }
          final stagger = min(
            rowIndex * columns + columnIndex,
            _enterStaggerLimit,
          );
          return Flexible(
            child: FadeSlideEnterBox(
              delay: _enterStaggerStep * stagger,
              distance: _enterSlideBase + _enterSlideStep * stagger,
              child: card,
            ),
          );
        })
        .fill(columns, filler: (_) => const Flexible(child: SizedBox()))
        .separated(const SizedBox(width: 8));
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Row(children: children.toList()),
    );
  }

  Widget _buildGroup(
    BuildContext context, {
    required Group group,
    required Set<String> currentUnfoldSet,
    required int columns,
    required ProxyCardType cardType,
    required ProxiesListHeaderStyle listHeaderStyle,
  }) {
    final groupName = group.name;
    final isExpand = currentUnfoldSet.contains(groupName);
    final rows = isExpand
        ? group.all.chunks(columns).toList()
        : const <List<Proxy>>[];
    return SliverMainAxisGroup(
      slivers: [
        PinnedHeaderSliver(
          child: ColoredBox(
            color: context.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: SizedBox(
                height: getListHeaderHeight(listHeaderStyle),
                child: ListHeader(
                  enterAnimated: false,
                  onScrollToSelected: (groupName) {
                    _scrollToGroupSelected(groupName, columns);
                  },
                  key: ValueKey(groupName),
                  listHeaderStyle: listHeaderStyle,
                  isExpand: isExpand,
                  group: group,
                  onChange: (groupName) {
                    _handleChange(currentUnfoldSet, groupName, listHeaderStyle);
                  },
                ),
              ),
            ),
          ),
        ),
        SliverAnimatedPaintExtent(
          duration: Duration(milliseconds: isExpand ? 120 : 250),
          curve: Curves.easeInOutCubic,
          child: SliverFixedExtentList(
            itemExtent: getItemHeight(cardType) + 8,
            delegate: SliverChildBuilderDelegate(
              (_, index) => _buildProxyRow(
                group: group,
                proxies: rows[index],
                rowIndex: index,
                columns: columns,
                cardType: cardType,
              ),
              childCount: rows.length,
            ),
          ),
        ),
      ],
    );
  }

  double _getGroupOffset(String groupName) {
    if (!_controller.hasClients ||
        _controller.position.maxScrollExtent == 0 ||
        _groupOffsets.isEmpty) {
      return 0;
    }
    return _groupOffsets.offsetOf(groupName);
  }

  void _scrollToMakeVisibleWithPadding({
    required double containerHeight,
    required double pixels,
    required double start,
    required double end,
    double padding = 24,
  }) {
    final visibleStart = pixels;
    final visibleEnd = pixels + containerHeight;

    final isElementVisible = start >= visibleStart && end <= visibleEnd;
    if (isElementVisible) {
      return;
    }

    double targetScrollOffset;

    if (end <= visibleStart) {
      targetScrollOffset = start;
    } else if (start >= visibleEnd) {
      targetScrollOffset = end - containerHeight + padding;
    } else {
      final visibleTopPart = end - visibleStart;
      final visibleBottomPart = visibleEnd - start;
      if (visibleTopPart.abs() >= visibleBottomPart.abs()) {
        targetScrollOffset = end - containerHeight + padding;
      } else {
        targetScrollOffset = start;
      }
    }

    targetScrollOffset = targetScrollOffset.clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );

    _controller.jumpTo(targetScrollOffset);
  }

  void _autoScrollToGroup(
    String groupName,
    ProxiesListHeaderStyle listHeaderStyle,
  ) {
    final pixels = _controller.position.pixels;
    final offset = _getGroupOffset(groupName);
    _scrollToMakeVisibleWithPadding(
      containerHeight: containerHeight,
      pixels: pixels,
      start: offset,
      end: offset + getListHeaderHeight(listHeaderStyle),
    );
  }

  void _scrollToGroupSelected(String groupName, int columns) {
    final currentInitOffset = _getGroupOffset(groupName);
    final proxies = _groupOffsets.groupOf(groupName)?.all;
    _jumpTo(
      currentInitOffset +
          8 +
          getScrollToSelectedOffset(
            ref: ref,
            groupName: groupName,
            proxies: proxies ?? [],
            columns: columns,
          ),
    );
  }

  void _jumpTo(double offset) {
    if (mounted && _controller.hasClients) {
      _controller.animateTo(
        offset.clamp(
          _controller.position.minScrollExtent,
          _controller.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  Future<void> delayTestUnfoldedGroups() async {
    final state = ref.read(proxiesListStateProvider);
    final expandedGroups = state.groups.where(
      (group) => state.currentUnfoldSet.contains(group.name),
    );
    await Future.wait(
      expandedGroups.map(
        (group) => ref
            .read(proxiesActionProvider.notifier)
            .delayTest(group.all, group.testUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Consumer(
      builder: (_, ref, _) {
        final state = ref.watch(proxiesListStateProvider);
        ref.watch(themeSettingProvider.select((state) => state.textScale));
        final headerStyle = ref.watch(
          proxiesStyleSettingProvider.select((state) => state.listHeaderStyle),
        );
        final proxiesLayout = ref.watch(
          proxiesStyleSettingProvider.select((state) => state.layout),
        );
        if (state.groups.isEmpty) {
          return NullStatus(
            illustration: const ProxyEmptyIllustration(),
            label: appLocalizations.nullTip(appLocalizations.proxies),
          );
        }
        return LayoutBuilder(
          builder: (_, constraints) {
            final columns = getProxiesColumns(
              max(constraints.maxWidth - 32, 0),
              proxiesLayout,
            );
            _groupOffsets = _getGroupOffsets(
              groups: state.groups,
              currentUnfoldSet: state.currentUnfoldSet,
              columns: columns,
              cardType: state.proxyCardType,
              listHeaderStyle: headerStyle,
            );
            containerHeight = max(constraints.maxHeight - 16, 0);
            return CommonScrollBar(
              controller: _controller,
              thumbVisibility: true,
              trackVisibility: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ScrollConfiguration(
                  behavior: HiddenBarScrollBehavior(),
                  child: CustomScrollView(
                    key: proxiesListStoreKey,
                    controller: _controller,
                    slivers: [
                      for (final group in state.groups)
                        _buildGroup(
                          context,
                          group: group,
                          currentUnfoldSet: state.currentUnfoldSet,
                          columns: columns,
                          cardType: state.proxyCardType,
                          listHeaderStyle: headerStyle,
                        ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 16 + BottomInsetScope.of(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ListHeader extends ConsumerStatefulWidget {
  final Group group;

  final Function(String groupName) onChange;
  final Function(String groupName) onScrollToSelected;
  final bool isExpand;

  final bool enterAnimated;

  final ProxiesListHeaderStyle listHeaderStyle;

  const ListHeader({
    super.key,
    this.enterAnimated = true,
    this.listHeaderStyle = ProxiesListHeaderStyle.loose,
    required this.group,
    required this.onChange,
    required this.onScrollToSelected,
    required this.isExpand,
  });

  @override
  ConsumerState<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends ConsumerState<ListHeader> {
  var isLock = false;

  String get icon => widget.group.icon;

  String get groupName => widget.group.name;

  String get groupType => widget.group.type.name;

  bool get isExpand => widget.isExpand;

  double get _cardRadius => switch (widget.listHeaderStyle) {
    ProxiesListHeaderStyle.loose => 18,
    ProxiesListHeaderStyle.standard => 16,
    ProxiesListHeaderStyle.tight => 22,
  };

  double get _iconSpacing => switch (widget.listHeaderStyle) {
    ProxiesListHeaderStyle.loose => 16,
    ProxiesListHeaderStyle.standard => 12,
    ProxiesListHeaderStyle.tight => 8,
  };

  double get _iconRadius => switch (widget.listHeaderStyle) {
    ProxiesListHeaderStyle.loose => 12,
    ProxiesListHeaderStyle.standard => 11,
    ProxiesListHeaderStyle.tight => 16,
  };

  EdgeInsets get _contentPadding => switch (widget.listHeaderStyle) {
    ProxiesListHeaderStyle.loose => const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    ProxiesListHeaderStyle.standard => const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 8,
    ),
    ProxiesListHeaderStyle.tight => const EdgeInsets.symmetric(
      horizontal: 6,
      vertical: 6,
    ),
  };

  Future<void> _delayTest() async {
    if (isLock) return;
    isLock = true;
    try {
      await ref
          .read(proxiesActionProvider.notifier)
          .delayTest(widget.group.all, widget.group.testUrl);
    } finally {
      isLock = false;
    }
  }

  void _handleChange(String groupName) {
    widget.onChange(groupName);
  }

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      enterActionsOnRight: true,
      enterAnimated: widget.enterAnimated,
      key: widget.key,
      radius: _cardRadius.ap,
      type: CommonCardType.filled,
      child: Padding(
        padding: _contentPadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  _GroupIcon(
                    src: icon,
                    groupName: groupName,
                    spacing: _iconSpacing,
                    radius: _iconRadius,
                  ),
                  Flexible(
                    child: _GroupSummary(
                      groupName: groupName,
                      groupType: groupType,
                      style: widget.listHeaderStyle,
                      configuredIcon: icon,
                    ),
                  ),
                ],
              ),
            ),
            _GroupActions(
              isExpand: isExpand,
              groupType: groupType,
              onScrollToSelected: () {
                widget.onScrollToSelected(groupName);
              },
              onDelayTest: _delayTest,
              onToggle: () {
                _handleChange(groupName);
              },
            ),
          ],
        ),
      ),
      onPressed: () {
        _handleChange(groupName);
      },
      onLongPress: () async {
        await resetProxySelection(ref, groupName);
      },
    );
  }
}

class _GroupIcon extends ConsumerWidget {
  const _GroupIcon({
    required this.src,
    required this.groupName,
    required this.spacing,
    required this.radius,
  });

  final String src;
  final String groupName;
  final double spacing;
  final double radius;

  bool _shouldUseEmoji(ProxiesIconSource source) {
    final emoji = getFirstEmoji(groupName);
    return switch (source) {
      ProxiesIconSource.standard => src.isEmpty && emoji.isNotEmpty,
      ProxiesIconSource.config => false,
      ProxiesIconSource.emoji => emoji.isNotEmpty,
    };
  }

  Widget _buildContent(double size, ProxiesIconSource source) {
    if (_shouldUseEmoji(source)) {
      return EmojiText(
        getFirstEmoji(groupName),
        style: TextStyle(fontSize: size * 0.75, height: 1.2),
      );
    }
    return IconTheme.merge(
      data: IconThemeData(size: size),
      child: CommonTargetIcon(
        src: source == ProxiesIconSource.emoji ? '' : src,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final props = ref.watch(
      proxiesStyleSettingProvider.select(
        (state) => (style: state.iconStyle, source: state.iconSource),
      ),
    );
    return switch (props.style) {
      ProxiesIconStyle.standard => LayoutBuilder(
        builder: (_, constraints) {
          return Container(
            margin: EdgeInsets.only(right: spacing),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                height: constraints.maxHeight,
                width: constraints.maxWidth,
                alignment: Alignment.center,
                padding: EdgeInsets.all(6.ap),
                decoration: BoxDecoration(
                  color: context.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(radius.ap),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildContent(
                  constraints.maxHeight - 12.ap,
                  props.source,
                ),
              ),
            ),
          );
        },
      ),
      ProxiesIconStyle.icon => Container(
        margin: EdgeInsets.only(right: spacing),
        child: LayoutBuilder(
          builder: (_, constraints) {
            return _buildContent(constraints.maxHeight - 8.ap, props.source);
          },
        ),
      ),
      ProxiesIconStyle.none => Container(),
    };
  }
}

class _GroupSummary extends ConsumerWidget {
  const _GroupSummary({
    required this.groupName,
    required this.groupType,
    required this.style,
    required this.configuredIcon,
  });

  final String groupName;
  final String groupType;
  final ProxiesListHeaderStyle style;
  final String configuredIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconProps = ref.watch(
      proxiesStyleSettingProvider.select(
        (state) => (style: state.iconStyle, source: state.iconSource),
      ),
    );
    final emoji = getFirstEmoji(groupName);
    final usesEmoji =
        iconProps.style != ProxiesIconStyle.none &&
        switch (iconProps.source) {
          ProxiesIconSource.standard =>
            configuredIcon.isEmpty && emoji.isNotEmpty,
          ProxiesIconSource.config => false,
          ProxiesIconSource.emoji => emoji.isNotEmpty,
        };
    final displayName = usesEmoji
        ? removeLeadingEmoji(groupName).takeFirstValid([groupName])
        : groupName;
    final titleStyle = switch (style) {
      ProxiesListHeaderStyle.loose => context.textTheme.titleMedium,
      ProxiesListHeaderStyle.standard => context.textTheme.titleSmall,
      ProxiesListHeaderStyle.tight => context.textTheme.titleSmall,
    };
    if (style == ProxiesListHeaderStyle.tight) {
      return Row(
        children: [
          Flexible(
            flex: 2,
            child: EmojiText(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              groupType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.toLight,
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmojiText(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        const SizedBox(height: 4),
        Flexible(flex: 1, child: _SelectedProxyName(groupName: groupName)),
      ],
    );
  }
}

class _SelectedProxyName extends ConsumerWidget {
  const _SelectedProxyName({required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyName = ref
        .watch(selectedProxyNameProvider(groupName))
        .takeFirstValid([]);
    if (proxyName.isEmpty) {
      return const SizedBox.shrink();
    }
    return EmojiText(
      proxyName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.labelSmall?.toLight,
    );
  }
}

class _GroupActions extends StatelessWidget {
  const _GroupActions({
    required this.isExpand,
    required this.groupType,
    required this.onScrollToSelected,
    required this.onDelayTest,
    required this.onToggle,
  });

  static const _shrinkWrap = ButtonStyle(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  final bool isExpand;
  final String groupType;
  final VoidCallback onScrollToSelected;
  final VoidCallback onDelayTest;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isExpand) ...[
          IconButton(
            tooltip: context.appLocalizations.scrollToSelected,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            onPressed: onScrollToSelected,
            style: _shrinkWrap,
            iconSize: 19,
            icon: const Icon(Icons.adjust),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: context.appLocalizations.delayTest,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            onPressed: onDelayTest,
            style: _shrinkWrap,
            icon: const Icon(Icons.network_ping),
          ),
          const SizedBox(width: 6),
        ] else ...[
          Text(groupType, style: context.textTheme.labelMedium?.toLight),
          const SizedBox(width: 6),
        ],
        IconButton.filledTonal(
          tooltip: isExpand
              ? context.appLocalizations.collapse
              : context.appLocalizations.expand,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(2),
          iconSize: 24,
          style: _shrinkWrap,
          onPressed: onToggle,
          icon: CommonExpandIcon(expand: isExpand),
        ),
      ],
    );
  }
}

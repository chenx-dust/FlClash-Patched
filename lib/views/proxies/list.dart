import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'card.dart';
import 'common.dart';

typedef GroupNameProxiesMap = Map<String, List<Proxy>>;

const double _listGroupSpacing = 10;
const double _listRowSpacing = 8;
const double _listBodyBottomSpacing = 8;

class ProxiesListView extends StatefulWidget {
  const ProxiesListView({super.key});

  @override
  State<ProxiesListView> createState() => ProxiesListViewState();
}

class ProxiesListViewState extends State<ProxiesListView> {
  final _controller = ScrollController();
  final _headerStateNotifier = ValueNotifier<ProxiesListHeaderSelectorState?>(
    null,
  );
  List<double> _headerOffset = [];
  List<String> _headerGroupNames = [];
  double containerHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_adjustHeader);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustHeader();
    });
  }

  ProxiesListHeaderSelectorState _getProxiesListHeaderSelectorState(
    double initOffset,
    ProxiesListHeaderStyle listHeaderStyle,
  ) {
    final index = _headerOffset.findInterval(initOffset);
    final currentIndex = index;
    final listHeaderHeight = getListHeaderHeight(listHeaderStyle);
    double headerOffset = 0.0;
    if (index + 1 <= _headerOffset.length - 1) {
      final endOffset = _headerOffset[index + 1];
      final startOffset = endOffset - listHeaderHeight - 8;
      if (initOffset > startOffset && initOffset < endOffset) {
        headerOffset = initOffset - startOffset;
      }
    }
    return ProxiesListHeaderSelectorState(
      offset: max(headerOffset, 0),
      currentIndex: currentIndex,
    );
  }

  void _adjustHeader() {
    final listHeaderStyle = globalState.container.read(
      proxiesStyleSettingProvider.select((state) => state.listHeaderStyle),
    );
    _headerStateNotifier.value = _getProxiesListHeaderSelectorState(
      !_controller.hasClients ? 0 : _controller.offset,
      listHeaderStyle,
    );
  }

  @override
  void dispose() {
    _headerStateNotifier.dispose();
    _controller.removeListener(_adjustHeader);
    _controller.dispose();
    super.dispose();
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
    } else {
      tempUnfoldSet.add(groupName);
    }
    updateCurrentUnfoldSet(tempUnfoldSet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustHeader();
    });
  }

  double _getGroupBodyHeight({
    required Group group,
    required bool isExpand,
    required int columns,
    required ProxyCardType cardType,
  }) {
    if (!isExpand) {
      return _listGroupSpacing;
    }
    final rowCount = (group.all.length / columns).ceil();
    if (rowCount == 0) {
      return _listGroupSpacing;
    }
    return _listGroupSpacing +
        rowCount * getItemHeight(cardType) +
        (rowCount - 1) * _listRowSpacing +
        _listBodyBottomSpacing;
  }

  void _updateHeaderOffsets({
    required List<Group> groups,
    required Set<String> currentUnfoldSet,
    required int columns,
    required ProxyCardType cardType,
    required ProxiesListHeaderStyle listHeaderStyle,
  }) {
    final headerOffset = <double>[];
    final headerGroupNames = <String>[];
    double currentHeight = 0;
    for (final group in groups) {
      headerOffset.add(currentHeight);
      headerGroupNames.add(group.name);
      currentHeight += getListHeaderHeight(listHeaderStyle);
      currentHeight += _getGroupBodyHeight(
        group: group,
        isExpand: currentUnfoldSet.contains(group.name),
        columns: columns,
        cardType: cardType,
      );
    }
    _headerOffset = headerOffset;
    _headerGroupNames = headerGroupNames;
  }

  List<Widget> _buildSlivers({
    required List<Group> groups,
    required int columns,
    required Set<String> currentUnfoldSet,
    required ProxyCardType cardType,
    required ProxiesListHeaderStyle listHeaderStyle,
  }) {
    final slivers = <Widget>[];
    for (final group in groups) {
      final groupName = group.name;
      final isExpand = currentUnfoldSet.contains(groupName);
      slivers.addAll([
        SliverToBoxAdapter(
          child: SizedBox(
            height: getListHeaderHeight(listHeaderStyle),
            child: ListHeader(
              onScrollToSelected: _scrollToGroupSelected,
              listHeaderStyle: listHeaderStyle,
              isExpand: isExpand,
              group: group,
              onChange: (String groupName) {
                _handleChange(currentUnfoldSet, groupName, listHeaderStyle);
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: _listGroupSpacing)),
        _ProxyGroupSliver(
          key: ValueKey('$groupName.body'),
          group: group,
          isExpand: isExpand,
          columns: columns,
          cardType: cardType,
        ),
      ]);
    }
    return slivers;
  }

  Widget _buildHeader({
    required Group group,
    required Set<String> currentUnfoldSet,
    required ProxiesListHeaderStyle listHeaderStyle,
  }) {
    final groupName = group.name;
    final isExpand = currentUnfoldSet.contains(groupName);
    return SizedBox(
      height: getListHeaderHeight(listHeaderStyle),
      child: ListHeader(
        onScrollToSelected: _scrollToGroupSelected,
        listHeaderStyle: listHeaderStyle,
        key: Key(groupName),
        isExpand: isExpand,
        group: group,
        onChange: (String groupName) {
          _handleChange(currentUnfoldSet, groupName, listHeaderStyle);
        },
      ),
    );
  }

  double _getGroupOffset(String groupName) {
    if (_controller.position.maxScrollExtent == 0) {
      return 0;
    }
    final findIndex = _headerGroupNames.indexOf(groupName);
    final index = findIndex != -1 ? findIndex : 0;
    return _headerOffset[index];
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

  void _scrollToGroupSelected(String groupName) {
    final currentInitOffset = _getGroupOffset(groupName);
    final currentGroups = getCurrentGroups();
    final proxies = currentGroups.getGroup(groupName)?.all;
    _jumpTo(
      currentInitOffset +
          8 +
          getScrollToSelectedOffset(
            groupName: groupName,
            proxies: proxies ?? [],
          ),
    );
  }

  Future<void> delayTestUnfoldedGroups() async {
    final state = globalState.container.read(proxiesListStateProvider);
    final expandedGroups = state.groups.where(
      (group) => state.currentUnfoldSet.contains(group.name),
    );
    for (final group in expandedGroups) {
      await delayTest(group.all, group.testUrl);
    }
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

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Consumer(
      builder: (_, ref, _) {
        final state = ref.watch(proxiesListStateProvider);
        final headerStyle = ref.watch(
          proxiesStyleSettingProvider.select((state) => state.listHeaderStyle),
        );
        ref.watch(themeSettingProvider.select((state) => state.textScale));
        if (state.groups.isEmpty) {
          return NullStatus(
            illustration: const ProxyEmptyIllustration(),
            label: appLocalizations.nullTip(appLocalizations.proxies),
          );
        }
        final slivers = _buildSlivers(
          groups: state.groups,
          currentUnfoldSet: state.currentUnfoldSet,
          columns: state.columns,
          cardType: state.proxyCardType,
          listHeaderStyle: headerStyle,
        );
        _updateHeaderOffsets(
          groups: state.groups,
          currentUnfoldSet: state.currentUnfoldSet,
          columns: state.columns,
          cardType: state.proxyCardType,
          listHeaderStyle: headerStyle,
        );
        return CommonScrollBar(
          controller: _controller,
          thumbVisibility: true,
          trackVisibility: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: ScrollConfiguration(
                  behavior: HiddenBarScrollBehavior(),
                  child: CustomScrollView(
                    key: proxiesListStoreKey,
                    controller: _controller,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverMainAxisGroup(slivers: slivers),
                      ),
                    ],
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (_, container) {
                  containerHeight = container.maxHeight;
                  return ValueListenableBuilder(
                    valueListenable: _headerStateNotifier,
                    builder: (_, headerState, _) {
                      if (headerState == null) {
                        return const SizedBox();
                      }
                      final index =
                          headerState.currentIndex > state.groups.length - 1
                          ? 0
                          : headerState.currentIndex;
                      if (index < 0 || state.groups.isEmpty) {
                        return Container();
                      }
                      return Stack(
                        children: [
                          Positioned(
                            top: -headerState.offset,
                            child: Container(
                              width: container.maxWidth,
                              color: context.colorScheme.surface,
                              padding: const EdgeInsets.only(
                                top: 16,
                                left: 16,
                                right: 16,
                                bottom: 8,
                              ),
                              child: _buildHeader(
                                group: state.groups[index],
                                currentUnfoldSet: state.currentUnfoldSet,
                                listHeaderStyle: headerStyle,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProxyGroupSliver extends StatelessWidget {
  final Group group;
  final bool isExpand;
  final int columns;
  final ProxyCardType cardType;

  const _ProxyGroupSliver({
    super.key,
    required this.group,
    required this.isExpand,
    required this.columns,
    required this.cardType,
  });

  int get _rowCount {
    return (group.all.length / max(columns, 1)).ceil();
  }

  double get _contentExtent {
    if (_rowCount == 0) {
      return 0;
    }
    return _rowCount * getItemHeight(cardType) +
        (_rowCount - 1) * _listRowSpacing +
        _listBodyBottomSpacing;
  }

  Duration get _animationDuration {
    final milliseconds = 80 + _contentExtent * 0.25;
    return Duration(milliseconds: min(milliseconds, isExpand ? 150 : 250).round());
  }

  Widget _buildGrid() {
    final groupName = group.name;
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: _listBodyBottomSpacing),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: _listRowSpacing,
          crossAxisSpacing: _listRowSpacing,
          mainAxisExtent: getItemHeight(cardType),
        ),
        delegate: SliverChildBuilderDelegate((_, index) {
          final proxy = group.all[index];
          return ProxyCard(
            testUrl: group.testUrl,
            type: cardType,
            groupType: group.type,
            key: ValueKey('$groupName.${proxy.name}'),
            proxy: proxy,
            groupName: groupName,
          );
        }, childCount: isExpand ? group.all.length : 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverAnimatedPaintExtent(
      duration: _animationDuration,
      curve: Curves.easeInOut,
      child: _buildGrid(),
    );
  }
}

class ListHeader extends StatefulWidget {
  final Group group;

  final Function(String groupName) onChange;
  final Function(String groupName) onScrollToSelected;
  final bool isExpand;

  final ProxiesListHeaderStyle listHeaderStyle;

  const ListHeader({
    super.key,
    this.listHeaderStyle = ProxiesListHeaderStyle.loose,
    required this.group,
    required this.onChange,
    required this.onScrollToSelected,
    required this.isExpand,
  });

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader> {
  var isLock = false;

  String get icon => widget.group.icon;

  String get groupName => widget.group.name;

  String get emojiIcon => getFirstEmoji(groupName);

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

  TextStyle? _getTitleStyle(BuildContext context) {
    return switch (widget.listHeaderStyle) {
      ProxiesListHeaderStyle.loose => context.textTheme.titleMedium,
      ProxiesListHeaderStyle.standard => context.textTheme.titleSmall,
      ProxiesListHeaderStyle.tight => context.textTheme.titleSmall,
    };
  }

  TextStyle? _getLabelStyle(BuildContext context) {
    return switch (widget.listHeaderStyle) {
      ProxiesListHeaderStyle.loose => context.textTheme.labelMedium,
      ProxiesListHeaderStyle.standard => context.textTheme.labelSmall,
      ProxiesListHeaderStyle.tight => context.textTheme.labelSmall,
    };
  }

  Future<void> _delayTest() async {
    if (isLock) return;
    isLock = true;
    await delayTest(widget.group.all, widget.group.testUrl);
    isLock = false;
  }

  void _handleChange(String groupName) {
    widget.onChange(groupName);
  }

  bool _shouldUseEmojiAsIcon(ProxiesIconSource source) {
    final emoji = emojiIcon;
    return switch (source) {
      ProxiesIconSource.standard => icon.isEmpty && emoji.isNotEmpty,
      ProxiesIconSource.config => false,
      ProxiesIconSource.emoji => emoji.isNotEmpty,
    };
  }

  Widget _buildIconContent(double size, ProxiesIconSource source) {
    final emoji = emojiIcon;
    if (_shouldUseEmojiAsIcon(source)) {
      return EmojiText(
        emoji,
        style: TextStyle(fontSize: size * 0.75, height: 1.2),
      );
    }
    final src = source == ProxiesIconSource.emoji ? '' : icon;
    return IconTheme.merge(
      data: IconThemeData(size: size),
      child: CommonTargetIcon(src: src),
    );
  }

  Widget _buildIcon() {
    return Consumer(
      builder: (_, ref, _) {
        final props = ref.watch(
          proxiesStyleSettingProvider.select(
            (state) => VM2(state.iconStyle, state.iconSource),
          ),
        );
        final iconStyle = props.a;
        final iconSource = props.b;
        return switch (iconStyle) {
          ProxiesIconStyle.standard => LayoutBuilder(
            builder: (_, constraints) {
              const double iconPadding = 6;
              return Container(
                margin: EdgeInsets.only(right: _iconSpacing),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(iconPadding.ap),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_iconRadius),
                      color: context.colorScheme.secondaryContainer,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildIconContent(
                      constraints.maxHeight - iconPadding.ap * 2,
                      iconSource,
                    ),
                  ),
                ),
              );
            },
          ),
          ProxiesIconStyle.icon => Container(
            margin: EdgeInsets.only(left: 8.ap, right: _iconSpacing),
            child: LayoutBuilder(
              builder: (_, constraints) {
                return _buildIconContent(
                  constraints.maxHeight - 8.ap,
                  iconSource,
                );
              },
            ),
          ),
          ProxiesIconStyle.none => Container(),
        };
      },
    );
  }

  Widget _buildTitle() {
    return Consumer(
      builder: (_, ref, _) {
        final props = ref.watch(
          proxiesStyleSettingProvider.select(
            (state) => VM2(state.iconStyle, state.iconSource),
          ),
        );
        final shouldUseEmojiAsIcon =
            props.a != ProxiesIconStyle.none && _shouldUseEmojiAsIcon(props.b);
        final displayGroupName = shouldUseEmojiAsIcon
            ? removeLeadingEmoji(groupName).takeFirstValid([groupName])
            : groupName;
        return EmojiText(
          displayGroupName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _getTitleStyle(context),
        );
      },
    );
  }

  Widget _buildInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          groupType,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _getLabelStyle(context)?.toLight,
        ),
        Flexible(
          flex: 1,
          child: Consumer(
            builder: (_, ref, _) {
              final proxyName = ref
                  .watch(selectedProxyNameProvider(groupName))
                  .takeFirstValid([]);
              if (proxyName.isEmpty) {
                return const SizedBox();
              }
              return EmojiText(
                ' · $proxyName',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: _getLabelStyle(context)?.toLight,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderContent() {
    if (widget.listHeaderStyle == ProxiesListHeaderStyle.tight) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(flex: 2, child: _buildTitle()),
          const SizedBox(width: 8),
          Flexible(flex: 3, child: _buildInfo()),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(),
          const SizedBox(height: 4),
          Flexible(flex: 1, child: _buildInfo()),
          const SizedBox(width: 4),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      focusNode: FocusNode(skipTraversal: true),
      enterAnimated: false,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIcon(),
                  Flexible(child: _buildHeaderContent()),
                ],
              ),
            ),
            Row(
              children: [
                if (isExpand) ...[
                  IconButton(
                    tooltip: context.appLocalizations.scrollToSelected,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(2),
                    onPressed: () {
                      widget.onScrollToSelected(groupName);
                    },
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    iconSize: 19,
                    icon: const Icon(Icons.adjust),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: context.appLocalizations.delayTest,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(2),
                    onPressed: _delayTest,
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.network_ping),
                  ),
                  const SizedBox(width: 6),
                ] else
                  const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: isExpand
                      ? context.appLocalizations.collapse
                      : context.appLocalizations.expand,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(2),
                  iconSize: 24,
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    _handleChange(groupName);
                  },
                  icon: CommonExpandIcon(expand: isExpand),
                ),
              ],
            ),
          ],
        ),
      ),
      onPressed: () {
        _handleChange(groupName);
      },
    );
  }
}

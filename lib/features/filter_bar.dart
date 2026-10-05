import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

class FilterChipData {
  final IconData icon;
  final String label;
  final VoidCallback onDeleted;

  const FilterChipData({
    required this.icon,
    required this.label,
    required this.onDeleted,
  });
}

class FilterMenuGroup {
  final IconData icon;
  final String label;
  final Iterable<String> values;
  final Set<String> selected;
  final String Function(String value) labelOf;
  final ValueChanged<String> onToggled;

  const FilterMenuGroup({
    required this.icon,
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onToggled,
  });

  List<CommonPopupMenuItem> buildOptions() {
    final counts = <String, int>{};
    for (final value in values) {
      if (value.trim().isEmpty) {
        continue;
      }
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final options = {...counts.keys, ...selected}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final option in options)
        CommonPopupMenuItem(
          label: labelOf(option),
          trailing: '${counts[option] ?? 0}',
          checked: selected.contains(option),
          keepOpen: true,
          onPressed: () => onToggled(option),
        ),
    ];
  }
}

class FilterChipBar extends StatelessWidget {
  final bool visible;
  final bool active;
  final List<FilterChipData> chips;
  final List<FilterMenuGroup> groups;

  const FilterChipBar({
    super.key,
    required this.visible,
    required this.active,
    required this.chips,
    required this.groups,
  });

  @override
  Widget build(BuildContext context) {
    final showBar = visible || active;
    return AnimatedSwitcher(
      duration: animateDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          alignment: AlignmentDirectional.topStart,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: showBar
          ? Material(
              // ListTile hover ink is painted on the scaffold and is not
              // clipped to the list. This fill covers the part that lands here.
              key: const ValueKey(true),
              color: context.colorScheme.surface,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ).copyWith(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: chips.isEmpty
                            ? Text(
                                context.appLocalizations.noFilterCondition,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context
                                      .colorScheme
                                      .onSurfaceVariant
                                      .opacity60,
                                ),
                              )
                            : _ChipRowFade(
                                child: HorizontalWheelScroll(
                                  child: Row(
                                    spacing: 8,
                                    children: [
                                      for (final chip in chips)
                                        CommonChip(
                                          icon: chip.icon,
                                          label: chip.label,
                                          onDeleted: chip.onDeleted,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      _FilterAddButton(groups: groups),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox(key: ValueKey(false)),
    );
  }
}

class _FilterAddButton extends StatefulWidget {
  final List<FilterMenuGroup> groups;

  const _FilterAddButton({required this.groups});

  @override
  State<_FilterAddButton> createState() => _FilterAddButtonState();
}

class _FilterAddButtonState extends State<_FilterAddButton> {
  late final _groups = ValueNotifier(widget.groups);
  ModalRoute<Object?>? _menuRoute;

  @override
  void didUpdateWidget(_FilterAddButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The open menu lives in another route, so it cannot be marked dirty
    // while this subtree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _groups.value = widget.groups;
      }
    });
  }

  @override
  void dispose() {
    final route = _menuRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
      _groups.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonPopupBox(
      popupBuilder: (menuContext) {
        _menuRoute = ModalRoute.of(menuContext);
        return ValueListenableBuilder(
          valueListenable: _groups,
          builder: (_, groups, _) => CommonPopupMenu(
            items: [
              for (final group in groups)
                CommonPopupMenuItem(
                  icon: group.icon,
                  label: group.label,
                  subItems: group.buildOptions(),
                ),
            ],
          ),
        );
      },
      targetBuilder: (open) {
        return IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          tooltip: context.appLocalizations.filter,
          onPressed: () => open(targetContext: context),
          icon: const Icon(Symbols.add),
        );
      },
    );
  }
}

class _ChipRowFade extends StatefulWidget {
  final Widget child;

  const _ChipRowFade({required this.child});

  @override
  State<_ChipRowFade> createState() => _ChipRowFadeState();
}

class _ChipRowFadeState extends State<_ChipRowFade> {
  var _overflows = false;

  bool _onNotification(Notification notification) {
    final ScrollMetrics? metrics = switch (notification) {
      ScrollNotification(:final metrics) => metrics,
      ScrollMetricsNotification(:final metrics) => metrics,
      _ => null,
    };
    if (metrics == null || (metrics.maxScrollExtent > 0) == _overflows) {
      return false;
    }
    _overflows = metrics.maxScrollExtent > 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: Stack(
        children: [
          widget.child,
          if (_overflows)
            const PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              width: 32,
              child: IgnorePointer(child: _ChipRowFadeMask()),
            ),
        ],
      ),
    );
  }
}

class _ChipRowFadeMask extends StatelessWidget {
  const _ChipRowFadeMask();

  @override
  Widget build(BuildContext context) {
    final surface = context.colorScheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [surface.opacity0, surface],
        ),
      ),
    );
  }
}

class FilterToggleButton extends StatelessWidget {
  final bool visible;
  final bool active;
  final VoidCallback onPressed;

  const FilterToggleButton({
    super.key,
    required this.visible,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Symbols.filter_alt);
    final tooltip = context.appLocalizations.filter;
    if (visible || active) {
      return IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
      );
    }
    return IconButton(tooltip: tooltip, onPressed: onPressed, icon: icon);
  }
}

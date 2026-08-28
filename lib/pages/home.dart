import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

typedef OnSelected = void Function(int index);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final Map<PageLabel, GlobalKey<_NavigationPageState>> _navigatorKeys = {};
  bool _isSwitchingPage = false;

  Future<void> _handleToPage(PageLabel pageLabel) async {
    final currentPageLabel = ref.read(currentPageLabelProvider);
    if (_isSwitchingPage || pageLabel == currentPageLabel) {
      return;
    }
    final focusNode = FocusManager.instance.primaryFocus;
    final preserveNavigationFocus =
        focusNode?.context?.findAncestorWidgetOfExactType<NavigationRail>() !=
        null;
    _isSwitchingPage = true;
    try {
      final navigatorState = _navigatorKeys[currentPageLabel]?.currentState;
      if (navigatorState != null && !await navigatorState.popToRoot()) {
        return;
      }
      ref.read(currentPageLabelProvider.notifier).toPage(pageLabel);
      if (!preserveNavigationFocus || focusNode == null) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focusNode.context != null && focusNode.canRequestFocus) {
          focusNode.requestFocus();
        }
      });
    } finally {
      _isSwitchingPage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasViewSize = ref.watch(
      viewSizeProvider.select((size) => !size.isEmpty),
    );
    if (!hasViewSize) {
      return const SizedBox.shrink();
    }
    return HomeBackScopeContainer(
      child: AppSidebarContainer(
        onDestinationSelected: _handleToPage,
        child: _HomeShell(
          onDestinationSelected: _handleToPage,
          child: Consumer(
            builder: (_, ref, _) {
              final navigationItems = ref
                  .watch(currentNavigationItemsStateProvider)
                  .value;
              final isMobile = ref.watch(isMobileViewProvider);
              return _HomePageView(
                navigationItems: navigationItems,
                pageBuilder: (_, index) {
                  final navigationItem = navigationItems[index];
                  return _NavigationPage(
                    key: _navigatorKeys.putIfAbsent(
                      navigationItem.label,
                      GlobalKey<_NavigationPageState>.new,
                    ),
                    item: navigationItem,
                    isMobile: isMobile,
                    view: navigationItem.builder(context),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeShell extends ConsumerWidget {
  const _HomeShell({required this.child, required this.onDestinationSelected});

  final Widget child;
  final ValueChanged<PageLabel> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(navigationStateProvider);
    final isMobile = state.viewMode == ViewMode.mobile;
    final navigationItems = state.navigationItems;
    return Material(
      color: context.colorScheme.surface,
      child: Column(
        children: [
          Flexible(
            flex: 1,
            child: FocusTraversalGroup(
              policy: PageTraversalPolicy(),
              child: MediaQuery.removePadding(
                removeTop: false,
                removeBottom: isMobile,
                removeLeft: isMobile,
                removeRight: isMobile,
                context: context,
                child: child,
              ),
            ),
          ),
          AnimatedVisibility.bottomNavigation(
            visible: isMobile,
            child: MediaQuery.removePadding(
              removeTop: true,
              removeBottom: false,
              removeLeft: true,
              removeRight: true,
              context: context,
              child: NavigationBarTheme(
                data: _NavigationBarDefaultsM3(context),
                child: NavigationBar(
                  destinations: [
                    for (final item in navigationItems)
                      NavigationDestination(
                        icon: item.icon,
                        label: Intl.message(item.label.name),
                      ),
                  ],
                  onDestinationSelected: (index) {
                    onDestinationSelected(navigationItems[index].label);
                  },
                  selectedIndex: state.currentIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationPage extends StatefulWidget {
  const _NavigationPage({
    super.key,
    required this.item,
    required this.isMobile,
    required this.view,
  });

  final NavigationItem item;
  final bool isMobile;
  final Widget view;

  @override
  State<_NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<_NavigationPage> {
  final HomeNavigatorObserver _navigatorObserver = HomeNavigatorObserver();

  Future<bool> popToRoot() => _navigatorObserver.popToRoot();

  @override
  Widget build(BuildContext context) {
    final scopedView = PageFocusScope(child: widget.view);
    final keptView = KeepScope(
      key: ValueKey(widget.item.label),
      keep: widget.item.keep,
      child: widget.isMobile
          ? scopedView
          : NotificationListener<CommonPopScopeAttemptNotification>(
              onNotification: _navigatorObserver.onPopScopeAttempt,
              child: Navigator(
                key: ValueKey('${widget.item.label.name}_navigator'),
                observers: [_navigatorObserver],
                pages: [MaterialPage(child: scopedView)],
                onDidRemovePage: (_) {},
                routeDirectionalTraversalEdgeBehavior:
                    TraversalEdgeBehavior.parentScope,
              ),
            ),
    );
    return Consumer(
      builder: (_, ref, child) {
        final isActive = ref.watch(
          currentPageLabelProvider.select(
            (label) => label == widget.item.label,
          ),
        );
        return PageActivityScope(
          isActive: isActive,
          child: ExcludeFocus(excluding: !isActive, child: child!),
        );
      },
      child: keptView,
    );
  }
}

class HomeNavigatorObserver extends NavigatorObserver {
  NavigatorState? _trackedNavigator;
  final List<Route<dynamic>> _routes = [];
  List<Future<void>>? _pendingPopAttempts;

  bool onPopScopeAttempt(CommonPopScopeAttemptNotification notification) {
    _pendingPopAttempts?.add(notification.completion);
    return false;
  }

  void _track(Route<dynamic> route) {
    if (_trackedNavigator == route.navigator) {
      return;
    }
    _trackedNavigator = route.navigator;
    _routes.clear();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
    _routes.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      final index = _routes.indexOf(oldRoute);
      if (index != -1) {
        if (newRoute == null) {
          _routes.removeAt(index);
        } else {
          _track(newRoute);
          _routes[index] = newRoute;
        }
      }
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  Future<bool> popToRoot() async {
    final currentNavigator = navigator;
    if (currentNavigator == null) {
      return true;
    }
    while (_routes.length > 1 && currentNavigator.canPop()) {
      final route = _routes.last;
      final popAttempts = <Future<void>>[];
      _pendingPopAttempts = popAttempts;
      try {
        await currentNavigator.maybePop();
      } finally {
        _pendingPopAttempts = null;
      }
      if (_routes.contains(route)) {
        if (popAttempts.isEmpty) {
          return false;
        }
        await Future.wait(popAttempts);
        if (_routes.contains(route)) {
          return false;
        }
      }
    }
    return _routes.length <= 1;
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;
  int _programmaticPageChangeCount = 0;
  bool _isUpdatingPageLabelFromView = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _closePopupMenus(prev);
        if (!_isUpdatingPageLabelFromView) {
          _toPage(next);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    final pageLabel = ref.read(currentPageLabelProvider);
    return widget.navigationItems.indexWhere((item) => item.label == pageLabel);
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    _programmaticPageChangeCount++;
    try {
      if (isAnimateToPage && !ignoreAnimateTo) {
        await _pageController.animateToPage(
          index,
          duration: midDuration,
          curve: Curves.easeOutCubic,
        );
      } else {
        _pageController.jumpToPage(index);
      }
    } finally {
      _programmaticPageChangeCount--;
    }
  }

  void _handlePageChanged(int index) {
    if (_programmaticPageChangeCount > 0 ||
        index < 0 ||
        index >= widget.navigationItems.length) {
      return;
    }
    final pageLabel = widget.navigationItems[index].label;
    if (pageLabel == ref.read(currentPageLabelProvider)) {
      return;
    }
    _isUpdatingPageLabelFromView = true;
    try {
      ref.read(currentPageLabelProvider.notifier).toPage(pageLabel);
    } finally {
      _isUpdatingPageLabelFromView = false;
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    _toPage(pageLabel, true);
  }

  void _closePopupMenus(PageLabel? pageLabel) {
    if (pageLabel == null) {
      return;
    }
    final pageContext = GlobalObjectKey(pageLabel).currentContext;
    if (pageContext != null) {
      CommonPopupRoute.closeAll(pageContext);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(
      currentNavigationItemsStateProvider.select((state) => state.value.length),
    );
    final isMobile = ref.read(isMobileViewProvider);
    final isSwipeToPage = ref.watch(
      appSettingProvider.select((state) => state.isSwipeToPage),
    );
    return PageView.builder(
      scrollDirection: isMobile ? Axis.horizontal : Axis.vertical,
      controller: _pageController,
      physics: isMobile && isSwipeToPage
          ? null
          : const NeverScrollableScrollPhysics(),
      onPageChanged: isMobile && isSwipeToPage ? _handlePageChanged : null,
      itemCount: itemCount,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<PageLabel>) {
          return null;
        }
        final index = widget.navigationItems.indexWhere(
          (item) => item.label == key.value,
        );
        return index == -1 ? null : index;
      },
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
  }
}

class _NavigationBarDefaultsM3 extends NavigationBarThemeData {
  _NavigationBarDefaultsM3(this.context)
    : super(
        height: 80.0,
        elevation: 3.0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get backgroundColor => _colors.surfaceContainer;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => Colors.transparent;

  @override
  WidgetStateProperty<IconThemeData?>? get iconTheme {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return IconThemeData(
        size: 24.0,
        color: states.contains(WidgetState.disabled)
            ? _colors.onSurfaceVariant.opacity38
            : states.contains(WidgetState.selected)
            ? _colors.onSecondaryContainer
            : _colors.onSurfaceVariant,
      );
    });
  }

  @override
  Color? get indicatorColor => _colors.secondaryContainer;

  @override
  ShapeBorder? get indicatorShape => AppShape.full;

  @override
  WidgetStateProperty<TextStyle?>? get labelTextStyle {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      final TextStyle style = _textTheme.labelMedium!;
      return style.apply(
        overflow: TextOverflow.ellipsis,
        color: states.contains(WidgetState.disabled)
            ? _colors.onSurfaceVariant.opacity38
            : states.contains(WidgetState.selected)
            ? _colors.onSurface
            : _colors.onSurfaceVariant,
      );
    });
  }
}

class HomeBackScopeContainer extends ConsumerStatefulWidget {
  final Widget child;

  const HomeBackScopeContainer({super.key, required this.child});

  @override
  ConsumerState<HomeBackScopeContainer> createState() =>
      _HomeBackScopeContainerState();
}

class _HomeBackScopeContainerState
    extends ConsumerState<HomeBackScopeContainer> {
  bool _canHandlePop = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = ref.watch(isMobileViewProvider);
    return CommonPopScope(
      canPop: isMobile && !_canHandlePop,
      onPop: (context) async {
        final pageLabel = ref.read(currentPageLabelProvider);
        final realContext =
            GlobalObjectKey(pageLabel).currentContext ?? context;
        final navigator = Navigator.of(realContext);
        if (isMobile) {
          if (navigator.canPop()) {
            navigator.pop();
            return false;
          }
        } else if (await navigator.maybePop()) {
          return false;
        }
        await ref.read(systemActionProvider.notifier).handleClose();
        return false;
      },
      child: NotificationListener<NavigationNotification>(
        onNotification: (notification) {
          if (_canHandlePop != notification.canHandlePop) {
            setState(() {
              _canHandlePop = notification.canHandlePop;
            });
          }
          return false;
        },
        child: widget.child,
      ),
    );
  }
}

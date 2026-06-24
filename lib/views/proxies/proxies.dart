import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/models/state.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/proxies/list.dart';
import 'package:fl_clash/views/proxies/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'setting.dart';
import 'tab.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> {
  final GlobalKey<CommonScaffoldState> _scaffoldKey = GlobalKey();
  final GlobalKey<ProxiesTabViewState> _proxiesTabKey = GlobalKey();
  final GlobalKey<ProxiesListViewState> _proxiesListKey = GlobalKey();
  bool _hasProviders = false;
  bool _isTab = false;

  List<Widget> _buildActions(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return [
      if (_isTab)
        IconButton(
          tooltip: appLocalizations.scrollToSelected,
          onPressed: () {
            _proxiesTabKey.currentState?.scrollToGroupSelected();
          },
          icon: const Icon(Icons.adjust, weight: 1),
        ),
      if (!_isTab) _buildListUnfoldButton(),
      CommonPopupBox(
        targetBuilder: (open) {
          return IconButton(
            onPressed: () {
              final isMobile = ref.read(isMobileViewProvider);
              open(offset: Offset(0, isMobile ? 0 : 40));
            },
            icon: const Icon(Icons.more_vert),
          );
        },
        popup: CommonPopupMenu(
          items: [
            PopupMenuItemData(
              icon: Icons.tune,
              label: appLocalizations.settings,
              onPressed: () {
                showSheet(
                  context: context,
                  props: const SheetProps(isScrollControlled: true),
                  builder: (_) {
                    return AdaptiveSheetScaffold(
                      body: const ProxiesSetting(),
                      title: appLocalizations.settings,
                    );
                  },
                );
              },
            ),
            if (_hasProviders)
              PopupMenuItemData(
                icon: Icons.poll_outlined,
                label: appLocalizations.providers,
                onPressed: () {
                  showExtend(
                    context,
                    builder: (_) {
                      return const ProvidersView();
                    },
                  );
                },
              ),
          ],
        ),
      ),
    ];
  }

  Widget _buildListUnfoldButton() {
    return Consumer(
      builder: (_, ref, _) {
        final state = ref.watch(proxiesListStateProvider);
        final allCollapsed = state.groups.every(
          (group) => !state.currentUnfoldSet.contains(group.name),
        );
        return IconButton(
          tooltip: allCollapsed
              ? context.appLocalizations.expand
              : context.appLocalizations.collapse,
          onPressed: () {
            final unfoldSet = allCollapsed
                ? state.groups.map((group) => group.name).toSet()
                : <String>{};
            ref
                .read(proxiesActionProvider.notifier)
                .updateCurrentUnfoldSet(unfoldSet);
          },
          icon: Icon(allCollapsed ? Icons.unfold_more : Icons.unfold_less),
        );
      },
    );
  }

  Widget _buildFAB() {
    return DelayTestButton(
      onClick: () async {
        if (_isTab) {
          await _proxiesTabKey.currentState?.delayTestCurrentGroup();
        } else {
          await _proxiesListKey.currentState?.delayTestUnfoldedGroups();
        }
      },
    );
  }

  bool _canDelayTest(ProxiesType proxiesType) {
    return switch (proxiesType) {
      ProxiesType.tab => ref.watch(
        proxiesTabStateProvider.select((state) {
          final currentGroup = state.groups.getGroup(
            state.currentGroupName ?? '',
          );
          return currentGroup?.all.isNotEmpty ?? false;
        }),
      ),
      ProxiesType.list => ref.watch(
        proxiesListStateProvider.select((state) {
          return state.groups.any((group) {
            return state.currentUnfoldSet.contains(group.name) &&
                group.all.isNotEmpty;
          });
        }),
      ),
    };
  }

  void _onSearch(String value) {
    ref.read(queryProvider(QueryTag.proxies).notifier).value = value;
  }

  void _onRegexSearchChange(bool value) {
    ref.read(searchUseRegexProvider(QueryTag.proxies).notifier).value = value;
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(providersProvider.select((state) => state.isNotEmpty), (
      prev,
      next,
    ) {
      if (prev != next) {
        setState(() {
          _hasProviders = next;
        });
      }
    }, fireImmediately: true);
    ref.listenManual(
      proxiesStyleSettingProvider.select(
        (state) => state.type == ProxiesType.tab,
      ),
      (prev, next) {
        if (prev != next) {
          setState(() {
            _isTab = next;
          });
        }
      },
      fireImmediately: true,
    );
    ref.listenManual(
      currentPageLabelProvider.select((state) => state == PageLabel.proxies),
      (prev, next) {
        if (prev != next && next == false) {
          _scaffoldKey.currentState?.handleExitSearching();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.type),
    );
    final isLoading = ref.watch(loadingProvider(LoadingTag.proxies));
    final useRegex = ref.watch(searchUseRegexProvider(QueryTag.proxies));
    return CommonScaffold(
      key: _scaffoldKey,
      isLoading: isLoading,
      resizeToAvoidBottomInset: false,
      floatingActionButton: _canDelayTest(proxiesType) ? _buildFAB() : null,
      actions: _buildActions(context),
      title: context.appLocalizations.proxies,
      searchState: AppBarSearchState(
        onSearch: _onSearch,
        onRegexChange: _onRegexSearchChange,
        useRegex: useRegex,
      ),
      body: switch (proxiesType) {
        ProxiesType.tab => ProxiesTabView(key: _proxiesTabKey),
        ProxiesType.list => ProxiesListView(key: _proxiesListKey),
      },
    );
  }
}

import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class DnsQueryListController extends ValueNotifier<DnsQueriesState> {
  DnsQueryListController() : super(const DnsQueriesState());

  void search(String query) {
    value = value.copyWith(query: query);
  }

  void setUseRegex(bool useRegex) {
    value = value.copyWith(useRegex: useRegex);
  }

  void setDnsQueries(List<DnsQuery> dnsQueries) {
    if (identical(dnsQueries, value.dnsQueries)) {
      return;
    }
    value = value.copyWith(
      dnsQueries: value.autoScrollToEnd
          ? dnsQueries
          : retainTrimmedHead(
              value.dnsQueries,
              dnsQueries,
              pausedMaxDnsQueriesLength,
            ),
    );
  }

  void setAutoScrollToEnd(bool autoScrollToEnd) {
    value = value.copyWith(autoScrollToEnd: autoScrollToEnd);
  }

  void resumeAutoScrollToEnd(List<DnsQuery> dnsQueries) {
    value = value.copyWith(autoScrollToEnd: true, dnsQueries: dnsQueries);
  }
}

class DnsQueriesView extends ConsumerStatefulWidget {
  const DnsQueriesView({super.key});

  @override
  ConsumerState<DnsQueriesView> createState() => _DnsQueriesViewState();
}

class _DnsQueriesViewState extends ConsumerState<DnsQueriesView> {
  final _listController = DnsQueryListController();
  late final ScrollController _scrollController;
  late final CoreController _core;
  DnsQueryFilter _filter = const DnsQueryFilter();
  bool _showFilterBar = false;
  bool _listening = false;

  void _setFilter(DnsQueryFilter filter) {
    setState(() {
      _filter = filter;
      if (filter.isNotEmpty) _showFilterBar = true;
    });
  }

  void _toggleFilterBar() {
    setState(() {
      if (_showFilterBar || _filter.isNotEmpty) {
        _showFilterBar = false;
        _filter = const DnsQueryFilter();
      } else {
        _showFilterBar = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _core = ref.read(coreHandlerProvider);
    _scrollController = ScrollController(initialScrollOffset: double.maxFinite);
    _listController.setDnsQueries(ref.read(dnsQueriesProvider).list);
    ref.listenManual(dnsQueriesProvider.select((state) => state.revision), (
      _,
      _,
    ) {
      _updateDnsQueriesThrottler();
    });
    ref.listenManual(coreStatusProvider, (_, _) => _syncListening());
    globalState.isBackground.addListener(_syncListening);
    _syncListening();
  }

  @override
  void dispose() {
    globalState.isBackground.removeListener(_syncListening);
    _stopListening();
    _listController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncListening() {
    if (globalState.isBackground.value ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      _stopListening();
      return;
    }
    _startListening();
  }

  void _startListening() {
    if (_listening) return;
    _listening = true;
    unawaited(
      _core.startDnsNotify().then((queries) {
        if (!mounted || !_listening) return;
        ref.read(dnsQueriesProvider.notifier).addQueries(queries);
      }),
    );
  }

  void _stopListening() {
    if (!_listening) return;
    _listening = false;
    _core.stopDnsNotify();
  }

  void _updateDnsQueriesThrottler() {
    throttler.call(FunctionTag.dnsQueries, () {
      if (!mounted) {
        return;
      }
      _listController.setDnsQueries(ref.read(dnsQueriesProvider).list);
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      actions: [
        DnsQueryFilterButton(
          visible: _showFilterBar,
          filter: _filter,
          onPressed: _toggleFilterBar,
        ),
      ],
      searchState: AppBarSearchState(
        onSearch: _listController.search,
        onRegexChange: (value) {
          _listController.setUseRegex(value);
          setState(() {});
        },
        useRegex: _listController.value.useRegex,
      ),
      title: appLocalizations.dnsQueries,
      floatingActionButton: ValueListenableBuilder(
        valueListenable: _listController,
        builder: (_, state, _) {
          final autoScrollToEnd = state.autoScrollToEnd;
          return FadeRotationScaleBox(
            child: FloatingActionButton(
              key: ValueKey(autoScrollToEnd),
              onPressed: () {
                if (autoScrollToEnd) {
                  _listController.setAutoScrollToEnd(false);
                } else {
                  _listController.resumeAutoScrollToEnd(
                    ref.read(dnsQueriesProvider).list,
                  );
                }
              },
              child: autoScrollToEnd
                  ? const Icon(Icons.pause)
                  : const Icon(Icons.play_arrow),
            ),
          );
        },
      ),
      body: ValueListenableBuilder<DnsQueriesState>(
        valueListenable: _listController,
        builder: (context, state, _) {
          final dnsQueries = state.list.withDnsQueryFilter(_filter);
          final body = NullStatusSwitcher(
            isEmpty: dnsQueries.isEmpty,
            nullStatus: NullStatus(
              illustration: NullStatusIllustration.requests,
              label: appLocalizations.nullTip(appLocalizations.dnsQueries),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: FloatingScrollbar(
                controller: _scrollController,
                hintBuilder: (fraction) {
                  final index = (fraction * (dnsQueries.length - 1)).round();
                  return dnsQueries[index].time.showFull;
                },
                child: ScrollToEndBox(
                  onCancelToEnd: () {
                    _listController.setAutoScrollToEnd(false);
                  },
                  controller: _scrollController,
                  enable: state.autoScrollToEnd,
                  dataSource: dnsQueries,
                  child: SuperListView.separated(
                    physics: const NextClampingScrollPhysics(),
                    reverse: true,
                    shrinkWrap: true,
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      bottom: 16 + BottomInsetScope.of(context),
                    ),
                    itemCount: dnsQueries.length,
                    separatorBuilder: (_, _) => const Divider(height: 0),
                    itemBuilder: (_, index) {
                      return DnsQueryItem(
                        dnsQuery: dnsQueries[index],
                        filter: _filter,
                        onClickFilter: (type, value) {
                          _setFilter(_filter.toggle(type, value));
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          return Column(
            children: [
              DnsQueryFilterBar(
                visible: _showFilterBar,
                dnsQueries: state.dnsQueries,
                filter: _filter,
                onChanged: _setFilter,
              ),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }
}

class DnsQueryItem extends StatelessWidget {
  final DnsQuery dnsQuery;
  final DnsQueryFilter filter;
  final void Function(DnsQueryFilterType type, String value)? onClickFilter;

  const DnsQueryItem({
    super.key,
    required this.dnsQuery,
    this.filter = const DnsQueryFilter(),
    this.onClickFilter,
  });

  void _showDetail(BuildContext context) {
    showExtend(
      context,
      builder: (_) {
        return AdaptiveSheetScaffold(
          sheetTransparentToolBar: true,
          title: context.appLocalizations.details('DNS'),
          body: DnsQueryDetailView(
            dnsQuery: dnsQuery,
            filter: filter,
            onClickFilter: onClickFilter,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final results = dnsQuery.results;
    final meta = [
      dnsQuery.time.getLastUpdateTimeDesc(context),
      dnsQuery.type,
      ?dnsQuery.initiator?.label,
      if (dnsQuery.cached) appLocalizations.cache,
      if (dnsQuery.hasFailureRcode) dnsQuery.rcode,
      '${dnsQuery.delay} ms',
      if (dnsQuery.upstream.isNotEmpty) dnsQuery.upstream,
    ].join(' · ');
    return ListItem(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ).copyWith(bottom: 12),
      minVerticalPadding: 0,
      horizontalTitleGap: 12,
      tileTitleAlignment: ListTileTitleAlignment.top,
      onTap: () => _showDetail(context),
      title: Text(
        dnsQuery.domain,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyLarge,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final result in results) CommonChip(label: result),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class DnsQueryDetailView extends StatefulWidget {
  final DnsQuery dnsQuery;
  final DnsQueryFilter filter;
  final void Function(DnsQueryFilterType type, String value)? onClickFilter;

  const DnsQueryDetailView({
    super.key,
    required this.dnsQuery,
    this.filter = const DnsQueryFilter(),
    this.onClickFilter,
  });

  @override
  State<DnsQueryDetailView> createState() => _DnsQueryDetailViewState();
}

class _DnsQueryDetailViewState extends State<DnsQueryDetailView> {
  late DnsQueryFilter _filter;

  DnsQuery get dnsQuery => widget.dnsQuery;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
  }

  void _applyFilter(DnsQueryFilterType type, String value) {
    widget.onClickFilter?.call(type, value);
    setState(() {
      _filter = _filter.toggle(type, value);
    });
  }

  VoidCallback? _filterTap(DnsQueryFilterType type, String value) {
    if (widget.onClickFilter == null || value.isEmpty) {
      return null;
    }
    return () => _applyFilter(type, value);
  }

  List<Widget> _rows(
    List<(String, String, DnsQueryFilterType?, String?, bool)> entries,
  ) {
    return [
      for (final (title, value, filterType, filterValue, isError) in entries)
        if (value.isNotEmpty)
          _DnsDetailRow(
            title: title,
            value: value,
            isError: isError,
            filtered:
                filterType != null &&
                filterValue != null &&
                _filter.contains(filterType, filterValue),
            onFilter: filterType != null && filterValue != null
                ? _filterTap(filterType, filterValue)
                : null,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final initiator = dnsQuery.initiator;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(bottom: 20, top: context.sheetTopPadding),
      children: [
        generateSectionV3(
          title: appLocalizations.basicInfo,
          isFirst: true,
          items: _rows([
            (appLocalizations.time, dnsQuery.time.showFull, null, null, false),
            (appLocalizations.domain, dnsQuery.domain, null, null, false),
            (
              appLocalizations.recordType,
              dnsQuery.type,
              DnsQueryFilterType.type,
              dnsQuery.type,
              false,
            ),
            (
              appLocalizations.initiator,
              initiator?.label ?? '',
              DnsQueryFilterType.initiator,
              initiator?.name ?? '',
              false,
            ),
            (
              appLocalizations.source,
              dnsQuery.upstream,
              DnsQueryFilterType.upstream,
              dnsQuery.upstream,
              false,
            ),
            (
              appLocalizations.cache,
              dnsQuery.cached ? appLocalizations.yes : appLocalizations.no,
              null,
              null,
              false,
            ),
            (
              appLocalizations.responseCode,
              dnsQuery.rcode,
              DnsQueryFilterType.rcode,
              dnsQuery.rcode,
              false,
            ),
            (appLocalizations.delay, '${dnsQuery.delay} ms', null, null, false),
          ]),
        ),
        if (dnsQuery.error.isNotEmpty)
          generateSectionV3(
            title: appLocalizations.error,
            items: _rows([(dnsQuery.error, dnsQuery.error, null, null, true)]),
          ),
        if (dnsQuery.answers.isNotEmpty)
          generateSectionV3(
            title: appLocalizations.answers,
            items: [
              for (final answer in dnsQuery.answers)
                DecorationListItem(
                  onPressed: () => copyText(context, answer),
                  minVerticalPadding: 14,
                  title: Text(answer, style: context.textTheme.bodyMedium),
                ),
            ],
          ),
      ],
    );
  }
}

class _DnsDetailRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isError;
  final bool filtered;
  final VoidCallback? onFilter;

  const _DnsDetailRow({
    required this.title,
    required this.value,
    this.isError = false,
    this.filtered = false,
    this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = isError
        ? context.colorScheme.error
        : context.colorScheme.onSurfaceVariant;
    return DecorationListItem(
      onPressed: onFilter ?? () => copyText(context, value),
      minVerticalPadding: 14,
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
          if (!isError)
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

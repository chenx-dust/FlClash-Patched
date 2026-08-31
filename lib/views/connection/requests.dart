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

class RequestsView extends ConsumerStatefulWidget {
  const RequestsView({super.key});

  @override
  ConsumerState<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends ConsumerState<RequestsView> {
  final _listController = TrackerInfoListController();
  late final ScrollController _scrollController;
  late final CoreController _core;
  TrackerInfoFilter _trackerFilter = const TrackerInfoFilter();
  bool _showFilterBar = false;
  bool _requestListening = false;

  void _setTrackerFilter(TrackerInfoFilter filter) {
    setState(() {
      _trackerFilter = filter;
      if (filter.isNotEmpty) _showFilterBar = true;
    });
  }

  void _toggleFilterBar() {
    setState(() {
      if (_showFilterBar || _trackerFilter.isNotEmpty) {
        _showFilterBar = false;
        _trackerFilter = const TrackerInfoFilter();
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
    _listController.setTrackerInfos(ref.read(requestsProvider).list);
    ref.listenManual(requestsProvider.select((state) => state.revision), (
      _,
      _,
    ) {
      updateRequestsThrottler();
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
    if (_requestListening) return;
    _requestListening = true;
    unawaited(
      _core.startRequestNotify().then((requests) {
        if (!mounted || !_requestListening) return;
        ref.read(requestsProvider.notifier).addRequests(requests);
      }),
    );
  }

  void _stopListening() {
    if (!_requestListening) return;
    _requestListening = false;
    _core.stopRequestNotify();
  }

  void updateRequestsThrottler() {
    throttler.call(FunctionTag.requests, () {
      if (!mounted) {
        return;
      }
      _listController.setTrackerInfos(ref.read(requestsProvider).list);
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      title: appLocalizations.requests,
      actions: [
        TrackerInfoFilterButton(
          visible: _showFilterBar,
          filter: _trackerFilter,
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
      onKeywordsUpdate: _listController.updateKeywords,
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
                    ref.read(requestsProvider).list,
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
      body: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: _listController,
        builder: (context, state, _) {
          final requests = state.list.withTrackerFilter(_trackerFilter);
          final body = requests.isEmpty
              ? Expanded(
                  child: NullStatus(
                    label: appLocalizations.nullTip(appLocalizations.requests),
                  ),
                )
              : Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FloatingScrollbar(
                      controller: _scrollController,
                      hintBuilder: (fraction) {
                        final index = (fraction * (requests.length - 1))
                            .round();
                        return requests[index].start.showFull;
                      },
                      child: ScrollToEndBox(
                        controller: _scrollController,
                        dataSource: requests,
                        enable: state.autoScrollToEnd,
                        onCancelToEnd: () {
                          _listController.setAutoScrollToEnd(false);
                        },
                        child: TrackerInfoList(
                          reverse: true,
                          shrinkWrap: true,
                          physics: const NextClampingScrollPhysics(),
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            bottom: 16 + BottomInsetScope.of(context),
                          ),
                          trackerInfos: requests,
                          detailTitle: appLocalizations.details(
                            appLocalizations.request,
                          ),
                          filter: _trackerFilter,
                          onClickFilter: (type, value) {
                            _setTrackerFilter(
                              _trackerFilter.toggle(type, value),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
          return Column(
            children: [
              TrackerInfoFilterBar(
                visible: _showFilterBar,
                trackerInfos: state.trackerInfos,
                filter: _trackerFilter,
                onChanged: _setTrackerFilter,
              ),
              body,
            ],
          );
        },
      ),
    );
  }
}

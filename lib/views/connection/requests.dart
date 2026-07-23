import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'filter.dart';
import 'item.dart';

class RequestsView extends ConsumerStatefulWidget {
  const RequestsView({super.key});

  @override
  ConsumerState<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends ConsumerState<RequestsView> {
  final _requestsStateNotifier = ValueNotifier<TrackerInfosState>(
    const TrackerInfosState(),
  );
  List<TrackerInfo> _requests = [];
  TrackerInfoFilter _trackerFilter = const TrackerInfoFilter();
  bool _showFilterBar = false;
  late final ScrollController _scrollController;
  bool _requestListening = false;

  void _onSearch(String value) {
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      query: value,
    );
  }

  void _onRegexSearchChange(bool value) {
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      useRegex: value,
    );
  }

  void _setTrackerFilter(TrackerInfoFilter filter) {
    setState(() {
      _trackerFilter = filter;
      if (filter.isNotEmpty) {
        _showFilterBar = true;
      }
    });
  }

  void _toggleFilterBar() {
    setState(() {
      if (_showFilterBar || _trackerFilter.isNotEmpty) {
        _showFilterBar = false;
        _trackerFilter = const TrackerInfoFilter();
        return;
      }
      _showFilterBar = true;
    });
  }

  @override
  void initState() {
    super.initState();
    globalState.isBackground.addListener(_syncListening);
    _syncListening();
    _requests = ref.read(requestsProvider).list;
    _scrollController = ScrollController(initialScrollOffset: double.maxFinite);
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      trackerInfos: _requests,
    );
    ref.listenManual(requestsProvider.select((state) => VM(state.list)), (
      prev,
      next,
    ) {
      _requests = next.a;
      updateRequestsThrottler();
    });
  }

  @override
  void dispose() {
    globalState.isBackground.removeListener(_syncListening);
    _stopListening();
    _requestsStateNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncListening() {
    if (globalState.isBackground.value) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _startListening() {
    if (_requestListening) {
      return;
    }
    commonPrint.log('start listening requests', logLevel: LogLevel.debug);
    _requestListening = true;
    unawaited(
      coreController.startRequestNotify().then((requests) {
        if (!mounted || !_requestListening) {
          return;
        }
        ref.read(requestsProvider.notifier).addRequests(requests);
      }),
    );
  }

  void _stopListening() {
    if (!_requestListening) {
      return;
    }
    commonPrint.log('stop listening requests', logLevel: LogLevel.debug);
    _requestListening = false;
    coreController.stopRequestNotify();
  }

  void updateRequestsThrottler() {
    throttler.call(FunctionTag.requests, () {
      if (!mounted) {
        return;
      }
      final isEquality = trackerInfoListEquality.equals(
        _requests,
        _requestsStateNotifier.value.trackerInfos,
      );
      if (isEquality) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
            trackerInfos: _requests,
          );
        }
      });
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
        onSearch: _onSearch,
        onRegexChange: _onRegexSearchChange,
        useRegex: _requestsStateNotifier.value.useRegex,
      ),
      floatingActionButton: ValueListenableBuilder(
        valueListenable: _requestsStateNotifier,
        builder: (_, state, _) {
          final autoScrollToEnd = state.autoScrollToEnd;
          return FadeRotationScaleBox(
            child: FloatingActionButton(
              key: ValueKey(autoScrollToEnd),
              onPressed: () {
                _requestsStateNotifier.value = _requestsStateNotifier.value
                    .copyWith(
                      autoScrollToEnd:
                          !_requestsStateNotifier.value.autoScrollToEnd,
                    );
              },
              child: autoScrollToEnd
                  ? const Icon(Icons.pause)
                  : const Icon(Icons.play_arrow),
            ),
          );
        },
      ),
      body: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: _requestsStateNotifier,
        builder: (context, state, _) {
          final requests = state.list.withTrackerFilter(_trackerFilter);
          final body = () {
            if (requests.isEmpty) {
              return Expanded(
                child: NullStatus(
                  label: appLocalizations.nullTip(appLocalizations.requests),
                ),
              );
            }
            return Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: CommonScrollBar(
                  trackVisibility: false,
                  controller: _scrollController,
                  child: ScrollToEndBox(
                    controller: _scrollController,
                    dataSource: requests,
                    enable: state.autoScrollToEnd,
                    onCancelToEnd: () {
                      _requestsStateNotifier.value = _requestsStateNotifier
                          .value
                          .copyWith(autoScrollToEnd: false);
                    },
                    child: SuperListView.separated(
                      reverse: true,
                      shrinkWrap: true,
                      physics: const NextClampingScrollPhysics(),
                      controller: _scrollController,
                      itemBuilder: (_, index) {
                        final trackerInfo = requests[index];
                        return TrackerInfoItem(
                          key: Key(trackerInfo.id),
                          trackerInfo: trackerInfo,
                          onClickFilter: (type, value) {
                            _setTrackerFilter(_trackerFilter.add(type, value));
                          },
                          detailTitle: appLocalizations.details(
                            appLocalizations.request,
                          ),
                        );
                      },
                      separatorBuilder: (_, _) => const Divider(height: 0),
                      itemCount: requests.length,
                    ),
                  ),
                ),
              ),
            );
          }();
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

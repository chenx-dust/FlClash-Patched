import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'tracker_info_item.dart';
import 'tracker_info_filter.dart';

class TrackerInfoListController extends ValueNotifier<TrackerInfosState> {
  TrackerInfoListController() : super(const TrackerInfosState());

  void search(String query) {
    value = value.copyWith(query: query);
  }

  void updateKeywords(List<String> keywords) {
    value = value.copyWith(keywords: keywords);
  }

  void setUseRegex(bool useRegex) {
    value = value.copyWith(useRegex: useRegex);
  }

  void setTrackerInfos(List<TrackerInfo> trackerInfos) {
    if (identical(trackerInfos, value.trackerInfos)) {
      return;
    }
    value = value.copyWith(
      trackerInfos: value.autoScrollToEnd
          ? trackerInfos
          : retainTrimmedHead(
              value.trackerInfos,
              trackerInfos,
              pausedMaxRequestsLength,
            ),
    );
  }

  void setAutoScrollToEnd(bool autoScrollToEnd) {
    value = value.copyWith(autoScrollToEnd: autoScrollToEnd);
  }

  void resumeAutoScrollToEnd(List<TrackerInfo> trackerInfos) {
    value = value.copyWith(autoScrollToEnd: true, trackerInfos: trackerInfos);
  }
}

class TrackerInfoList extends StatelessWidget {
  final List<TrackerInfo> trackerInfos;
  final String detailTitle;
  final ScrollController? controller;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final Widget? Function(TrackerInfo trackerInfo)? trailingBuilder;
  final TrackerInfoFilter filter;
  final void Function(TrackerInfoFilterType type, String value)? onClickFilter;
  final VoidCallback? onDetailClosed;

  const TrackerInfoList({
    super.key,
    required this.trackerInfos,
    required this.detailTitle,
    this.controller,
    this.reverse = false,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.trailingBuilder,
    this.filter = const TrackerInfoFilter(),
    this.onClickFilter,
    this.onDetailClosed,
  });

  @override
  Widget build(BuildContext context) {
    return SuperListView.separated(
      reverse: reverse,
      shrinkWrap: shrinkWrap,
      physics: physics,
      controller: controller,
      padding: padding,
      itemCount: trackerInfos.length,
      separatorBuilder: (_, _) => const Divider(height: 0),
      itemBuilder: (_, index) => _buildTrackerInfoItem(
        context,
        trackerInfos[index],
        detailTitle: detailTitle,
        trailingBuilder: trailingBuilder,
        filter: filter,
        onClickFilter: onClickFilter,
        onDetailClosed: onDetailClosed,
      ),
    );
  }
}

/// Same rows as [TrackerInfoList], but diffed by connection id so closed
/// connections collapse out and surviving rows slide to their new slot.
class TrackerInfoAnimatedList extends StatelessWidget {
  final List<TrackerInfo> trackerInfos;
  final String detailTitle;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final Widget? Function(TrackerInfo trackerInfo)? trailingBuilder;
  final TrackerInfoFilter filter;
  final void Function(TrackerInfoFilterType type, String value)? onClickFilter;
  final VoidCallback? onDetailClosed;

  const TrackerInfoAnimatedList({
    super.key,
    required this.trackerInfos,
    required this.detailTitle,
    this.controller,
    this.padding,
    this.trailingBuilder,
    this.filter = const TrackerInfoFilter(),
    this.onClickFilter,
    this.onDetailClosed,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedAnimatedList<TrackerInfo>(
      controller: controller,
      padding: padding,
      items: trackerInfos,
      keyOf: (trackerInfo) => trackerInfo.id,
      separator: const Divider(height: 0),
      itemBuilder: (context, trackerInfo) => _buildTrackerInfoItem(
        context,
        trackerInfo,
        detailTitle: detailTitle,
        trailingBuilder: trailingBuilder,
        filter: filter,
        onClickFilter: onClickFilter,
        onDetailClosed: onDetailClosed,
      ),
    );
  }
}

Widget _buildTrackerInfoItem(
  BuildContext context,
  TrackerInfo trackerInfo, {
  required String detailTitle,
  required Widget? Function(TrackerInfo trackerInfo)? trailingBuilder,
  required TrackerInfoFilter filter,
  required void Function(TrackerInfoFilterType type, String value)?
  onClickFilter,
  required VoidCallback? onDetailClosed,
}) {
  return TrackerInfoItem(
    key: Key(trackerInfo.id),
    trackerInfo: trackerInfo,
    onClickKeyword: (value) {
      context.commonScaffoldState?.addKeyword(value);
    },
    trailing: trailingBuilder?.call(trackerInfo),
    detailTitle: detailTitle,
    filter: filter,
    onClickFilter: onClickFilter,
    onDetailClosed: onDetailClosed,
  );
}

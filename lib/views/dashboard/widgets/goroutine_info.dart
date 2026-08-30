import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class GoroutineInfo extends ConsumerStatefulWidget {
  final Future<int> Function()? countReader;

  const GoroutineInfo({super.key, @visibleForTesting this.countReader});

  @override
  ConsumerState<GoroutineInfo> createState() => _GoroutineInfoState();
}

class _GoroutineInfoState extends ConsumerState<GoroutineInfo>
    with WidgetsBindingObserver, ActivePollingMixin<GoroutineInfo> {
  final _countNotifier = ValueNotifier<int>(0);

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  void dispose() {
    _countNotifier.dispose();
    super.dispose();
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    final count = await _readCount();
    if (count == null || !isCurrent()) {
      return;
    }
    _countNotifier.value = count;
  }

  Future<int?> _readCount() async {
    try {
      final countReader = widget.countReader;
      if (countReader != null) {
        return await countReader();
      }
      final connected = ref.read(coreStatusProvider) == CoreStatus.connected;
      return connected ? await _core.getGoroutineCount() : null;
    } catch (error) {
      commonPrint.log(
        'updateGoroutineCount error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: RepaintBoundary(
        child: CommonCard(
          radius: AppCorner.lg,
          onPressed: () {},
          info: Info(
            iconData: Icons.account_tree_outlined,
            label: appLocalizations.goroutineInfo,
          ),
          child: Container(
            padding: baseInfoEdgeInsets.copyWith(top: 0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: globalState.measure.bodyMediumHeight + 2,
                  child: ValueListenableBuilder(
                    valueListenable: _countNotifier,
                    builder: (_, count, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          '$count',
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

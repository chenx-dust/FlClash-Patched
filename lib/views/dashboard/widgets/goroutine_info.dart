import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

final _goroutineCountNotifier = ValueNotifier<int>(0);

class GoroutineInfo extends StatefulWidget {
  const GoroutineInfo({super.key});

  @override
  State<GoroutineInfo> createState() => _GoroutineInfoState();
}

class _GoroutineInfoState extends State<GoroutineInfo> {
  @override
  void initState() {
    super.initState();
    foregroundTicker.register(this, _updateGoroutineCount, fire: true);
  }

  @override
  void dispose() {
    foregroundTicker.unregister(this);
    super.dispose();
  }

  Future<void> _updateGoroutineCount() async {
    if (!coreController.isCompleted) {
      return;
    }
    final count = await coreController.getGoroutineCount();
    if (!mounted) {
      return;
    }
    _goroutineCountNotifier.value = count;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: RepaintBoundary(
        child: CommonCard(
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
                    valueListenable: _goroutineCountNotifier,
                    builder: (_, count, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            '$count',
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                          ),
                        ],
                      );
                    },
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

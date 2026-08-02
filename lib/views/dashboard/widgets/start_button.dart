import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _widthAnimationDuration = Duration(milliseconds: 200);
const _buttonHeight = 56.0;

TextStyle? _runTimeTextStyle(BuildContext context) {
  return context.textTheme.titleMedium?.toSoftBold.copyWith(
    color: context.colorScheme.onPrimaryContainer,
  );
}

double _computeRunTimeTextWidth(BuildContext context, String text) {
  final daySeparator = text.indexOf('d ');
  final placeholder = daySeparator == -1
      ? '99:99:99'
      : '${List.filled(daySeparator, '9').join()}d 99:99:99';
  return globalState.measure
          .computeTextSize(Text(placeholder, style: _runTimeTextStyle(context)))
          .width +
      16;
}

class RunTimeText extends StatelessWidget {
  final int? timeStamp;

  const RunTimeText({super.key, required this.timeStamp});

  @override
  Widget build(BuildContext context) {
    return Text(
      utils.getTimeText(timeStamp),
      maxLines: 1,
      overflow: TextOverflow.visible,
      style: _runTimeTextStyle(context),
    );
  }
}

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;
  final _runTimeTextWidths = <int, double>{};
  double? _suspendedTextWidth;
  int? _displayRunTime;

  @override
  void initState() {
    super.initState();
    final isStart = ref.read(isStartProvider);
    _displayRunTime = ref.read(runTimeProvider);
    _controller = AnimationController(
      vsync: this,
      value: isStart ? 1 : 0,
      duration: _widthAnimationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutBack,
    );
    ref.listenManual(runTimeProvider, (_, next) {
      _updateDisplayRunTime(next);
    });
    ref.listenManual(isStartProvider, (prev, next) {
      updateController(next);
    }, fireImmediately: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _runTimeTextWidths.clear();
    _suspendedTextWidth = null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void handleSwitchStart() {
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  void _updateDisplayRunTime(int? runTime) {
    if (!mounted ||
        _displayRunTime == runTime ||
        (runTime == null && !(_controller?.isDismissed ?? true))) {
      return;
    }
    setState(() {
      _displayRunTime = runTime;
    });
  }

  void updateController(bool isStart) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final controller = _controller;
      if (controller == null) {
        return;
      }
      if (isStart) {
        controller.forward();
        return;
      }
      controller.reverse().whenCompleteOrCancel(() {
        if (mounted && controller.isDismissed) {
          _updateDisplayRunTime(ref.read(runTimeProvider));
        }
      });
    });
  }

  double _getRunTimeTextWidth(BuildContext context, String text) {
    return _runTimeTextWidths.putIfAbsent(
      text.length,
      () => _computeRunTimeTextWidth(context, text),
    );
  }

  double _getSuspendedTextWidth(BuildContext context, String suspendedText) {
    return _suspendedTextWidth ??=
        globalState.measure
            .computeTextSize(
              Text(suspendedText, style: context.textTheme.titleMedium),
            )
            .width +
        24;
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (!hasProfile) {
      return Container();
    }
    final suspend = ref.watch(suspendProvider);
    final runTimeText = utils.getTimeText(_displayRunTime);
    final theme = Theme.of(context);
    final appLocalizations = context.appLocalizations;
    final textWidth = suspend
        ? _getSuspendedTextWidth(context, appLocalizations.suspended)
        : _getRunTimeTextWidth(context, runTimeText);
    return RepaintBoundary(
      child: FocusTraversalOrder(
        order: const PrimaryFocusOrder(),
        child: Theme(
          data: theme.copyWith(
            floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
              sizeConstraints: const BoxConstraints(
                minWidth: 56,
                minHeight: _buttonHeight,
                maxHeight: _buttonHeight,
              ),
            ),
          ),
          child: FloatingActionButton(
            clipBehavior: Clip.antiAlias,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            heroTag: null,
            onPressed: handleSwitchStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (_, child) {
                    return Container(
                      height: _buttonHeight,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16 - 8 * _animation.value,
                      ),
                      alignment: Alignment.centerLeft,
                      child: child,
                    );
                  },
                  child: AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _animation,
                  ),
                ),
                SizeTransition(
                  axis: Axis.horizontal,
                  alignment: Alignment.centerLeft,
                  sizeFactor: _animation,
                  child: AnimatedContainer(
                    width: textWidth,
                    duration: _widthAnimationDuration,
                    curve: Curves.easeOut,
                    child: suspend
                        ? Text(
                            appLocalizations.suspended,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: context.colorScheme.onPrimaryContainer,
                                ),
                          )
                        : RunTimeText(timeStamp: _displayRunTime),
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

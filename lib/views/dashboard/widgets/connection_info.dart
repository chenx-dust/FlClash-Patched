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

class ConnectionInfo extends ConsumerStatefulWidget {
  final Future<int> Function()? connectionCountReader;

  const ConnectionInfo({
    super.key,
    @visibleForTesting this.connectionCountReader,
  });

  @override
  ConsumerState<ConnectionInfo> createState() => _ConnectionInfoState();
}

class _ConnectionInfoState extends ConsumerState<ConnectionInfo>
    with WidgetsBindingObserver, ActivePollingMixin<ConnectionInfo> {
  final _connectionCountNotifier = ValueNotifier<int>(0);

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  Duration get pollInterval => const Duration(seconds: 1);

  @override
  void dispose() {
    _connectionCountNotifier.dispose();
    super.dispose();
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    final count = await _readConnectionCount();
    if (count == null || !isCurrent()) {
      return;
    }
    _connectionCountNotifier.value = count;
  }

  Future<int?> _readConnectionCount() async {
    try {
      final connectionCountReader = widget.connectionCountReader;
      if (connectionCountReader != null) {
        return await connectionCountReader();
      }
      final connected = ref.read(coreStatusProvider) == CoreStatus.connected;
      return connected ? (await _core.getConnections()).length : null;
    } catch (error) {
      commonPrint.log(
        'updateConnectionCount error: $error',
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
            iconData: Icons.link,
            label: appLocalizations.connectionInfo,
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
                    valueListenable: _connectionCountNotifier,
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

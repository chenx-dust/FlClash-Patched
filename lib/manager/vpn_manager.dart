import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VpnManager extends ConsumerStatefulWidget {
  final Widget child;
  final Future<VpnOptions?> Function()? readActiveOptions;
  final ValueListenable<TunnelState>? tunnelState;

  const VpnManager({
    super.key,
    this.readActiveOptions,
    this.tunnelState,
    required this.child,
  });

  @override
  ConsumerState<VpnManager> createState() => _VpnContainerState();
}

class _VpnContainerState extends ConsumerState<VpnManager>
    with WidgetsBindingObserver {
  VpnOptions? _lastNotifiedOptions;
  Object? _check;
  late final ValueListenable<TunnelState>? _tunnelState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tunnelState = widget.tunnelState ?? service?.tunnelState;
    _tunnelState?.addListener(_scheduleCheck);
    ref.listenManual(vpnOptionsProvider, (prev, next) {
      if (prev != next) {
        _scheduleCheck();
      }
    });
    ref.listenManual(isStartProvider, (_, next) {
      if (!next) _lastNotifiedOptions = null;
      _scheduleCheck();
    });
    _scheduleCheck();
  }

  void _scheduleCheck() {
    _check = null;
    debouncer.call(this, _checkOptions);
  }

  Future<void> _checkOptions() async {
    if (!mounted || !ref.read(isStartProvider)) return;
    final check = Object();
    _check = check;
    try {
      final active =
          await (widget.readActiveOptions?.call() ??
              service?.getActiveVpnOptions() ??
              Future<VpnOptions?>.value());
      if (!mounted || !identical(_check, check) || !ref.read(isStartProvider)) {
        return;
      }
      final options = ref.read(vpnOptionsProvider);
      if (active == null || options == null) return;
      if (options == active) {
        _lastNotifiedOptions = null;
        return;
      }
      if (options == _lastNotifiedOptions) return;
      _lastNotifiedOptions = options;
      dialogs.showNotifier(
        currentAppLocalizations.vpnConfigChangeDetected,
        level: MessageLevel.warning,
        actionState: MessageActionState(
          actionText: currentAppLocalizations.restart,
          action: () async {
            final setupAction = ref.read(setupActionProvider.notifier);
            await setupAction.setRunning(false);
            await setupAction.setRunning(true);
          },
        ),
      );
    } catch (error) {
      commonPrint.log('Unable to read active VPN options: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleCheck();
  }

  @override
  void dispose() {
    _check = null;
    debouncer.cancel(this);
    _tunnelState?.removeListener(_scheduleCheck);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

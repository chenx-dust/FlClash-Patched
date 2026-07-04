import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MobileManager extends ConsumerStatefulWidget {
  final Widget child;

  const MobileManager({super.key, required this.child});

  @override
  ConsumerState<MobileManager> createState() => _MobileManagerState();
}

class _MobileManagerState extends ConsumerState<MobileManager>
    with ServiceListener {
  @override
  void initState() {
    super.initState();
    if (system.isAndroid) {
      // hidden from recents
      ref.listenManual(appSettingProvider.select((state) => state.hidden), (
        prev,
        next,
      ) {
        app?.updateExcludeFromRecents(next);
      }, fireImmediately: true);
    }
    ref.listenManual(sharedStateProvider, (prev, next) {
      if (prev != next) {
        debouncer.call(FunctionTag.saveSharedFile, () async {
          preferences.saveShareState(next);
        }, duration: const Duration(seconds: 1));
        if (prev?.needSyncSharedState != next.needSyncSharedState) {
          service?.syncState(next.needSyncSharedState);
        }
      }
    });
    service?.addListener(this);
  }

  @override
  void dispose() {
    service?.removeListener(this);
    super.dispose();
  }

  @override
  void onServiceEvent(CoreEvent event) {
    coreEventManager.sendEvent(event);
    super.onServiceEvent(event);
  }

  @override
  void onServiceCrash(String message) {
    coreEventManager.sendEvent(
      CoreEvent(type: CoreEventType.crash, data: message),
    );
    super.onServiceCrash(message);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

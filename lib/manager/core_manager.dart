import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoreManager extends ConsumerStatefulWidget {
  final Widget child;

  const CoreManager({super.key, required this.child});

  @override
  ConsumerState<CoreManager> createState() => _CoreContainerState();
}

class _CoreContainerState extends ConsumerState<CoreManager>
    with CoreEventListener {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    coreEventManager.addListener(this);
    ref.listenManual(currentProfileIdProvider, (prev, next) {
      if (prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(setupActionProvider.notifier).fullSetup();
        });
      }
    });
    ref.listenManual(updateParamsProvider, (prev, next) {
      if (prev != next) {
        ref.read(setupActionProvider.notifier).updateConfigDebounce();
      }
    });
  }

  @override
  Future<void> dispose() async {
    coreEventManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onDelay(Delay delay) async {
    super.onDelay(delay);
    final proxiesAction = ref.read(proxiesActionProvider.notifier);
    proxiesAction.setDelay(delay);
    debouncer.call(FunctionTag.updateDelay, () async {
      proxiesAction.updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 5000));
  }

  @override
  void onLog(Log log) {
    final coreLog = log.copyWith(source: LogSource.core);
    ref.read(logsProvider.notifier).add(coreLog);
    if (log.logLevel == LogLevel.error) {
      globalState.showNotifier(log.payload, allowCopy: true);
    }
    super.onLog(log);
  }

  @override
  void onRequest(TrackerInfo trackerInfo) async {
    ref.read(requestsProvider.notifier).addRequest(trackerInfo);
    super.onRequest(trackerInfo);
  }

  @override
  Future<void> onLoaded(String providerName) async {
    final ref = globalState.container;
    ref
        .read(providersProvider.notifier)
        .setProvider(await coreController.getExternalProvider(providerName));
    debouncer.call(FunctionTag.loadedProvider, () async {
      ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 5000));
    super.onLoaded(providerName);
  }

  @override
  Future<void> onCrash(String message) async {
    globalState.container
      .read(initProvider.notifier).value = false;
    globalState.container
      .read(setupActionProvider.notifier)
      .updateStatus(false, isInit: !ref.read(initProvider));
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      context.showNotifier(message, allowCopy: true);
    }
    await coreController.shutdown(false);
    super.onCrash(message);
  }

  @override
  void onGeoUpdate(String geoType, bool updating, bool skipped, String? error) {
    final geoResource = GeoResource.fromJson(geoType.toLowerCase());
    final key = geoResource.updatingKey;
    final l10n = currentAppLocalizations;
    if (updating) {
      globalState.showNotifier(l10n.geoUpdating(geoResource.name));
    } else if (skipped) {
      globalState.showNotifier(l10n.geoSkipped(geoResource.name));
    } else {
      globalState.showNotifier(l10n.geoUpdated(geoResource.name));
    }
    ref.read(isUpdatingProvider(key).notifier).value = updating;
    if (!updating && error != null && error.isNotEmpty) {
      globalState.showNotifier(error, allowCopy: true);
    }
    super.onGeoUpdate(geoType, updating, skipped, error);
  }
}

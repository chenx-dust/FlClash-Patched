part of '../action.dart';

@Riverpod(keepAlive: true)
class SystemAction extends _$SystemAction {
  Future<void>? _exitFuture;
  Future<void>? _exitSaveFuture;

  @override
  void build() {}

  Future<List<Package>> getPackages() async {
    if (ref.read(isMobileViewProvider)) {
      await Future.delayed(commonDuration);
    }
    if (ref.read(packagesProvider).isEmpty) {
      ref.read(packagesProvider.notifier).value =
          await app?.getPackages() ?? [];
    }
    return ref.read(packagesProvider);
  }

  Future<void> handleExit([bool needSave = false]) {
    if (needSave) {
      _exitSaveFuture ??= preferences.saveConfig(ref.read(configProvider));
    }
    return _exitFuture ??= _handleExit();
  }

  Future<void> _handleExit() async {
    Future.delayed(const Duration(seconds: 3), () {
      system.exit();
    });
    try {
      await window?.hide();
      await Future.wait([
        if (macOS != null) macOS!.updateDns(true),
        if (proxy != null) proxy!.stopProxy(),
        if (tray != null) tray!.destroy(),
      ]);
      await coreController.destroy();
      await _exitSaveFuture;
      commonPrint.log('exit');
    } finally {
      system.exit();
    }
  }

  Future<void> handleClose([bool exit = true]) async {
    if (!system.isDesktop) {
      if (ref.read(backBlockProvider)) return;
    }
    if (ref.read(appSettingProvider).minimizeOnExit || !exit) {
      if (system.isDesktop) {
        await preferences.saveConfig(ref.read(configProvider));
      }
      await system.back();
    } else {
      await handleExit();
    }
  }

  Future<void> updateVisible() async {
    final visible = await window?.isVisible;
    if (visible != null && !visible) {
      window?.show();
    } else {
      window?.hide();
    }
  }

  void updateTun() {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.tun(enable: !state.tun.enable));
  }

  void updateSystemProxy() {
    ref
        .read(networkSettingProvider.notifier)
        .update((state) => state.copyWith(systemProxy: !state.systemProxy));
  }

  void updateAutoLaunch() {
    ref
        .read(appSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            autoLaunch: !state.autoLaunch,
            highPriorityAutoLaunch: false,
          ),
        );
  }

  Future<void> updateTray() async {
    final currentTray = tray;
    if (currentTray == null) {
      return;
    }
    try {
      await currentTray.update(trayState: ref.read(trayStateProvider));
    } catch (e) {
      commonPrint.log('update tray error: $e', logLevel: LogLevel.error);
    }
  }

  Future<void> updateLocalIp() async {
    ref.read(localIpProvider.notifier).value = null;
    await Future.delayed(commonDuration);
    ref.read(localIpProvider.notifier).value = await utils.getLocalIpAddress();
  }
}

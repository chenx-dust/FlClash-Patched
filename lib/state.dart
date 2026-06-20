import 'dart:async';
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/palettes/core_palette.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common/common.dart';
import 'core/controller.dart';
import 'database/database.dart';
import 'enum/enum.dart';
import 'l10n/l10n.dart';
import 'models/models.dart';
import 'plugins/service.dart';
import 'providers/providers.dart';

typedef UpdateTasks = List<FutureOr<void> Function()>;

class GlobalState {
  static GlobalState? _instance;
  final navigatorKey = GlobalKey<NavigatorState>();
  final backgroundMode = ValueNotifier<bool>(false);
  final animationEnabled = ValueNotifier<bool>(true);
  bool isPre = true;
  late final String coreSHA256;
  late final PackageInfo packageInfo;
  Function? updateCurrentDelayDebounce;
  late Measure measure;
  late CommonTheme theme;
  late Color accentColor;
  late ProviderContainer container;
  bool needInitStatus = true;

  // ignore: deprecated_member_use
  CorePalette? corePalette;
  String? lastConfigMd5;
  VpnState? lastVpnState;
  bool isAttach = false;
  Timer? _taskTimer;
  Timer? _backgroundCleanupTimer;
  UpdateTasks _tasks = [];
  int _taskLoopToken = 0;
  bool _isExecutingTasks = false;
  bool _needsTaskRestart = false;

  GlobalState._internal();

  factory GlobalState() {
    _instance ??= GlobalState._internal();
    return _instance!;
  }

  Future<ProviderContainer> init(int version) async {
    coreSHA256 = const String.fromEnvironment('CORE_SHA256');
    isPre = const String.fromEnvironment('APP_ENV') != 'stable';
    await _initDynamicColor();
    return _initData(version);
  }

  Future<void> _initDynamicColor() async {
    try {
      corePalette = await DynamicColorPlugin.getCorePalette();
      accentColor =
          await DynamicColorPlugin.getAccentColor() ??
          const Color(defaultPrimaryColor);
    } catch (_) {}
  }

  String get ua => container
      .read(patchClashConfigProvider.select((state) => state.globalUa))
      .takeFirstValid([packageInfo.ua]);

  BuildContext get _context => navigatorKey.currentContext!;

  Future<void> startUpdateTasks([UpdateTasks? tasks]) async {
    if (tasks != null) {
      _tasks = tasks;
    }
    final token = ++_taskLoopToken;
    _taskTimer?.cancel();
    _taskTimer = null;
    if (_isExecutingTasks) {
      _needsTaskRestart = true;
      return;
    }
    await _runUpdateLoop(token);
  }

  Future<void> _runUpdateLoop(int token) async {
    if (token != _taskLoopToken) {
      return;
    }
    _isExecutingTasks = true;
    try {
      await _executeUpdateTasks();
    } finally {
      _isExecutingTasks = false;
    }
    if (_needsTaskRestart) {
      _needsTaskRestart = false;
      await _runUpdateLoop(_taskLoopToken);
      return;
    }
    if (token != _taskLoopToken) {
      return;
    }
    _taskTimer = Timer(const Duration(seconds: 1), () {
      unawaited(_runUpdateLoop(token));
    });
  }

  Future<void> _executeUpdateTasks() async {
    for (final task in _tasks) {
      try {
        await task();
      } catch (e, s) {
        commonPrint.log(
          'update task failed: $e, $s',
          logLevel: LogLevel.warning,
        );
      }
    }
    _taskTimer = null;
  }

  void stopUpdateTasks() {
    _taskLoopToken++;
    _needsTaskRestart = false;
    _taskTimer?.cancel();
    _taskTimer = null;
  }

  bool get _shouldKeepBackgroundUpdateTasks {
    return system.isAndroid &&
        container.read(
          vpnSettingProvider.select((state) => state.networkSpeedNotification),
        );
  }

  Future<void> handleBackground() async {
    if (system.isDesktop) {
      final isMinimized = await window?.isMinimized ?? false;
      final isVisible = await window?.isVisible ?? true;
      if (!isMinimized && isVisible) {
        return;
      }
      animationEnabled.value = false;
    }
    if (!backgroundMode.value) {
      backgroundMode.value = true;
      _scheduleBackgroundCleanup();
    }
    render?.pause();
    if (!_shouldKeepBackgroundUpdateTasks) {
      stopUpdateTasks();
    }
    dashboardRefreshManager.stop();
  }

  void handleForeground() {
    if (system.isDesktop) {
      animationEnabled.value = true;
    }
    if (!backgroundMode.value) {
      return;
    }
    backgroundMode.value = false;
    _backgroundCleanupTimer?.cancel();
    _backgroundCleanupTimer = null;
    unawaited(_syncVpnState());
  }

  Future<void> _syncVpnState() async {
    if (!system.isAndroid) {
      return;
    }
    try {
      final startTime = await service?.getRunTime();
      if (startTime != null) {
        container.read(setupActionProvider.notifier).startTime = startTime;
        if (container.read(runTimeProvider) == null) {
          container.read(runTimeProvider.notifier).value = 0;
        }
      } else if (container.read(runTimeProvider) != null) {
        container.read(setupActionProvider.notifier).startTime = null;
        container.read(runTimeProvider.notifier).value = null;
      }
    } catch (e, s) {
      commonPrint.log('sync vpn state failed: $e, $s');
    }
  }

  Future<void> resumeForegroundUpdates() async {
    dashboardRefreshManager.start();
    if (!container.read(isStartProvider)) {
      return;
    }
    final commonAction = container.read(commonActionProvider.notifier);
    commonAction.updateRunTime();
    await commonAction.updateTraffic();
    await startUpdateTasks([commonAction.updateTraffic]);
  }

  void _scheduleBackgroundCleanup() {
    _backgroundCleanupTimer?.cancel();
    _backgroundCleanupTimer = Timer(const Duration(minutes: 3), () {
      _backgroundCleanupTimer = null;
      if (!backgroundMode.value) {
        return;
      }
      unawaited(cleanupBackgroundResources());
    });
  }

  Future<void> cleanupBackgroundResources() async {
    if (!backgroundMode.value) {
      return;
    }
    PaintingBinding.instance.imageCache.clearLiveImages();
    await Future.delayed(const Duration(milliseconds: 250));
    if (!backgroundMode.value) {
      return;
    }
    WidgetsBinding.instance.handleMemoryPressure();
    await Future.delayed(const Duration(milliseconds: 250));
    if (!backgroundMode.value) {
      return;
    }
    await coreController.requestGc();
  }

  Future<ProviderContainer> _initData(int version) async {
    final appState = AppState(
      brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
      version: version,
      viewSize: Size.zero,
      requests: FixedList(maxLength),
      logs: FixedList(maxLength),
      traffics: FixedList(30),
      totalTraffic: const Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    final appStateOverrides = buildAppStateOverrides(appState);
    packageInfo = await PackageInfo.fromPlatform();
    final configMap = await preferences.getConfigMap();
    final config = await migration.migrationIfNeeded(
      configMap,
      sync: (data) async {
        final newConfigMap = data.configMap;
        final config = Config.realFromJson(newConfigMap);
        await Future.wait([
          database.restore(
            data.profiles,
            data.scripts,
            data.rules,
            data.links,
            data.proxyGroups,
          ),
          preferences.saveConfig(config),
        ]);
        return config;
      },
    );
    final configOverrides = buildConfigOverrides(config);
    container = ProviderContainer(
      overrides: [...appStateOverrides, ...configOverrides],
    );
    final profiles = await database.profilesDao.query().get();
    container.read(profilesProvider.notifier).setAndReorder(profiles);
    await AppLocalizations.load(
      utils.getLocaleForString(config.appSettingProps.locale) ??
          WidgetsBinding.instance.platformDispatcher.locale,
    );
    await window?.init(version, config.windowProps);
    return container;
  }

  Future<T?> loadingRun<T>(
    FutureOr<T> Function() futureFunction, {
    String? title,
    required LoadingTag? tag,
    bool silence = false,
  }) async {
    return globalState.safeRun(
      futureFunction,
      silence: silence,
      title: title,
      onStart: () {
        if (tag != null) {
          container.read(loadingProvider(tag).notifier).start();
        }
      },
      onEnd: () {
        if (tag != null) {
          container.read(loadingProvider(tag).notifier).stop();
        }
      },
    );
  }

  Future<T?> safeRun<T>(
    FutureOr<T> Function() futureFunction, {
    String? title,
    VoidCallback? onStart,
    VoidCallback? onEnd,
    bool silence = true,
  }) async {
    try {
      onStart?.call();
      return await futureFunction();
    } catch (e, s) {
      commonPrint.log('$title ===> $e, $s', logLevel: LogLevel.warning);
      if (silence) {
        showNotifier(e.toString());
      } else {
        showMessage(
          title: title ?? currentAppLocalizations.tip,
          message: TextSpan(text: e.toString()),
        );
      }
      return null;
    } finally {
      onEnd?.call();
    }
  }

  Future<bool?> showMessage({
    required InlineSpan message,
    BuildContext? context,
    String? title,
    String? confirmText,
    String? cancelText,
    bool cancelable = true,
    bool? dismissible,
  }) async {
    return showCommonDialog<bool>(
      context: context,
      dismissible: dismissible,
      child: Builder(
        builder: (context) {
          final appLocalizations = context.appLocalizations;
          return CommonDialog(
            title: title ?? appLocalizations.tip,
            actions: [
              if (cancelable)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(cancelText ?? appLocalizations.cancel),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(confirmText ?? appLocalizations.confirm),
              ),
            ],
            child: Container(
              width: 300,
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.labelLarge,
                    children: [message],
                  ),
                  style: const TextStyle(overflow: TextOverflow.visible),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool?> showAllUpdatingMessagesDialog(
    List<UpdatingMessage> messages,
  ) async {
    return showCommonDialog<bool>(
      child: Builder(
        builder: (context) {
          final appLocalizations = currentAppLocalizations;
          return CommonDialog(
            padding: EdgeInsets.zero,
            title: appLocalizations.tip,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(appLocalizations.confirm),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                itemBuilder: (_, index) {
                  final message = messages[index];
                  return ListItem(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(message.label),
                    subtitle: Text(message.message),
                  );
                },
                itemCount: messages.length,
                separatorBuilder: (_, _) => const Divider(height: 0),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<T?> showCommonDialog<T>({
    required Widget child,
    BuildContext? context,
    bool? dismissible,
    bool filter = true,
  }) async {
    return showModal<T>(
      useRootNavigator: false,
      context: context ?? globalState.navigatorKey.currentContext!,
      configuration: FadeScaleTransitionConfiguration(
        barrierColor: Colors.black38,
        barrierDismissible: dismissible ?? true,
      ),
      builder: (_) => child,
      filter: filter ? commonFilter : null,
    );
  }

  void showNotifier(String text, {MessageActionState? actionState}) {
    if (text.isEmpty) {
      return;
    }
    navigatorKey.currentContext?.showNotifier(text, actionState: actionState);
  }

  Future<void> openUrl(String url) async {
    final res = await showMessage(
      message: TextSpan(text: url),
      title: currentAppLocalizations.externalLink,
      confirmText: currentAppLocalizations.go,
    );
    if (res != true) {
      return;
    }
    launchUrl(Uri.parse(url));
  }

  Future<void> attach() async {
    if (isAttach == true) {
      return;
    }
    await _initApp();
    isAttach = true;
  }

  Future<void> _initApp() async {
    FlutterError.onError = (details) {
      commonPrint.log(
        'exception: ${details.exception} stack: ${details.stack}',
        logLevel: LogLevel.warning,
      );
    };
    container.read(systemActionProvider.notifier).updateTray();
    container.read(profilesActionProvider.notifier).autoUpdateProfiles();
    container.read(commonActionProvider.notifier).autoCheckUpdate();
    final appSetting = container.read(appSettingProvider);
    autoLaunch?.updateStatus(
      isAutoLaunch: appSetting.autoLaunch,
      isHighPriorityAutoLaunch: appSetting.highPriorityAutoLaunch,
    );
    if (!container.read(appSettingProvider).silentLaunch) {
      window?.show();
    } else {
      window?.hide();
    }
    await _handleFailedPreference();
    await _handlerDisclaimer();
    await container.read(coreActionProvider.notifier).connectCore();
    await container.read(coreActionProvider.notifier).initCore();
    await container.read(setupActionProvider.notifier).initStatus();
    container.read(initProvider.notifier).value = true;
    permissions.check();
  }

  Future<void> _handleFailedPreference() async {
    if (await preferences.isInit) return;
    final res = await showMessage(
      title: currentAppLocalizations.tip,
      message: TextSpan(text: currentAppLocalizations.cacheCorrupt),
    );
    if (res == true) {
      final file = File(await appPath.sharedPreferencesPath);
      await file.safeDelete();
    }
    await container.read(systemActionProvider.notifier).handleExit();
  }

  Future<bool> showDisclaimer() async {
    return await showCommonDialog<bool>(
          dismissible: false,
          child: CommonDialog(
            title: currentAppLocalizations.disclaimer,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(_context).pop<bool>(false);
                },
                child: Text(currentAppLocalizations.exit),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(_context).pop<bool>(true);
                },
                child: Text(currentAppLocalizations.agree),
              ),
            ],
            child: Text(currentAppLocalizations.disclaimerDesc),
          ),
        ) ??
        false;
  }

  Future<void> _handlerDisclaimer() async {
    if (container.read(
      appSettingProvider.select((state) => state.disclaimerAccepted),
    )) {
      return;
    }
    final isDisclaimerAccepted = await showDisclaimer();
    if (!isDisclaimerAccepted) {
      await container.read(systemActionProvider.notifier).handleExit();
    }
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(disclaimerAccepted: true));
  }
}

class DashboardRefreshManager {
  final tick1s = ValueNotifier<int>(0);
  final tick2s = ValueNotifier<int>(0);
  final tick5s = ValueNotifier<int>(0);
  Timer? _timer;
  int _tickCount = 0;
  int _tickToken = 0;

  void start() {
    if (_timer != null) {
      return;
    }
    final token = ++_tickToken;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tick(token));
    });
  }

  void stop() {
    _tickToken++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick(int token) async {
    if (token != _tickToken) {
      return;
    }
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (system.isDesktop) {
      if (await window?.isVisible == false) {
        return;
      }
      if (await window?.isMinimized == true) {
        return;
      }
    }
    if (token != _tickToken) {
      return;
    }
    _tickCount++;
    tick1s.value++;
    if (_tickCount % 2 == 0) {
      tick2s.value++;
    }
    if (_tickCount % 5 == 0) {
      tick5s.value++;
    }
  }
}

final dashboardRefreshManager = DashboardRefreshManager();
final globalState = GlobalState();

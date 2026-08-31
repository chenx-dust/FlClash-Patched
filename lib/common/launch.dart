import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'constant.dart';
import 'system.dart';

class AutoLaunch {
  static AutoLaunch? _instance;

  AutoLaunch._internal() {
    launcher.setup(appName: appName, appPath: Platform.resolvedExecutable);
  }

  factory AutoLaunch() {
    _instance ??= AutoLaunch._internal();
    return _instance!;
  }

  @visibleForTesting
  static LaunchAtStartup launcher = launchAtStartup;

  Future<bool> get isEnable async {
    return launcher.isEnabled();
  }

  Future<bool> get isHighPriorityEnable async {
    if (!system.isWindows) return false;
    return windows?.isTaskRegistered(appName) ?? false;
  }

  Future<bool> enable() async {
    return launcher.enable();
  }

  Future<bool> disable() async {
    return launcher.disable();
  }

  Future<bool> enableHighPriority() async {
    if (!system.isWindows) return false;
    return windows?.registerTask(appName) ?? false;
  }

  Future<bool> disableHighPriority() async {
    if (!system.isWindows) return true;
    return windows?.unregisterTask(appName) ?? true;
  }

  Future<void> updateStatus({
    required bool isAutoLaunch,
    bool isHighPriorityAutoLaunch = false,
  }) async {
    if (kDebugMode) {
      return;
    }
    final shouldUseTask =
        system.isWindows && isAutoLaunch && isHighPriorityAutoLaunch;
    final shouldUseLauncher = isAutoLaunch && !shouldUseTask;

    if (system.isWindows && await isHighPriorityEnable != shouldUseTask) {
      await (shouldUseTask ? enableHighPriority() : disableHighPriority());
    }
    if (await isEnable != shouldUseLauncher) {
      await (shouldUseLauncher ? enable() : disable());
    }
  }
}

final autoLaunch = system.isDesktop ? AutoLaunch() : null;

import 'dart:async';
import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

import 'constant.dart';
import 'system.dart';

class AutoLaunch {
  static AutoLaunch? _instance;

  AutoLaunch._internal() {
    launchAtStartup.setup(
      appName: appName,
      appPath: Platform.resolvedExecutable,
    );
  }

  factory AutoLaunch() {
    _instance ??= AutoLaunch._internal();
    return _instance!;
  }

  Future<bool> get isEnable async {
    return launchAtStartup.isEnabled();
  }

  Future<bool> get isHighPriorityEnable async {
    if (!system.isWindows) {
      return false;
    }
    return windows?.isTaskRegistered(appName) ?? false;
  }

  Future<bool> enable() async {
    return launchAtStartup.enable();
  }

  Future<bool> disable() async {
    return launchAtStartup.disable();
  }

  Future<bool> enableHighPriority() async {
    if (!system.isWindows) {
      return false;
    }
    return windows?.registerTask(appName) ?? false;
  }

  Future<bool> disableHighPriority() async {
    if (!system.isWindows) {
      return true;
    }
    return windows?.unregisterTask(appName) ?? true;
  }

  Future<void> updateStatus({
    required bool isAutoLaunch,
    bool isHighPriorityAutoLaunch = false,
  }) async {
    final shouldHighPriority =
        system.isWindows && isAutoLaunch && isHighPriorityAutoLaunch;
    final shouldNormal = isAutoLaunch && !shouldHighPriority;

    if (system.isWindows) {
      if (await isHighPriorityEnable != shouldHighPriority) {
        if (shouldHighPriority) {
          await enableHighPriority();
        } else {
          await disableHighPriority();
        }
      }
    }

    if (await isEnable != shouldNormal) {
      if (shouldNormal) {
        await enable();
      } else {
        await disable();
      }
    }
  }
}

final autoLaunch = system.isDesktop ? AutoLaunch() : null;

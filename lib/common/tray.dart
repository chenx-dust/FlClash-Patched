import 'dart:async';
import 'dart:io';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tray_manager/tray_manager.dart';

import 'app_localizations.dart';
import 'constant.dart';
import 'print.dart';
import 'system.dart';
import 'window.dart';

class Tray {
  static Tray? _instance;

  Timer? _trafficTimer;
  bool _isUpdatingTraffic = false;

  Tray._internal();

  factory Tray() {
    _instance ??= Tray._internal();
    return _instance!;
  }

  String get trayIconSuffix {
    return system.isWindows ? 'ico' : 'png';
  }

  Future<void> destroy() async {
    _trafficTimer?.cancel();
    _trafficTimer = null;
    await trayManager.destroy();
  }

  String getTryIcon({
    required bool isStart,
    required bool tunEnable,
    bool monochrome = false,
  }) {
    if (system.isMacOS) {
      return 'assets/images/icon/status_1.$trayIconSuffix';
    }
    if (monochrome && system.isLinux) {
      return 'assets/images/icon/flclash-symbolic.svg';
    }
    if (!isStart) {
      return 'assets/images/icon/status_1.$trayIconSuffix';
    }
    if (!tunEnable) {
      return 'assets/images/icon/status_2.$trayIconSuffix';
    }
    return 'assets/images/icon/status_3.$trayIconSuffix';
  }

  Future _updateSystemTray({
    required bool isStart,
    required bool tunEnable,
    required bool monochrome,
  }) async {
    if (Platform.isLinux) {
      await trayManager.destroy();
    }
    await trayManager.setIcon(
      getTryIcon(
        isStart: isStart,
        tunEnable: tunEnable,
        monochrome: monochrome,
      ),
      isTemplate: system.isMacOS,
    );
    if (!Platform.isLinux) {
      await trayManager.setToolTip(appName);
    }
  }

  Future<void> update({required TrayState trayState}) async {
    if (system.isMobile) {
      return;
    }
    if (!system.isLinux) {
      await _updateSystemTray(
        isStart: trayState.isStart,
        tunEnable: trayState.tunEnable,
        monochrome: trayState.monochromeTrayIcon,
      );
    }
    final List<MenuItem> menuItems = [];
    final ref = globalState.container;
    final commonAction = ref.read(commonActionProvider.notifier);
    final systemAction = ref.read(systemActionProvider.notifier);
    final setupAction = ref.read(setupActionProvider.notifier);
    final appLocalizations = currentAppLocalizations;
    final showMenuItem = MenuItem(
      label: appLocalizations.show,
      onClick: (_) {
        window?.show();
      },
    );
    menuItems.add(showMenuItem);
    final startMenuItem = MenuItem.checkbox(
      label: trayState.isStart ? appLocalizations.stop : appLocalizations.start,
      onClick: (_) async {
        commonAction.updateStart();
      },
      checked: trayState.isStart,
    );
    menuItems.add(startMenuItem);
    if (system.isMacOS) {
      final speedStatistics = MenuItem.checkbox(
        label: appLocalizations.speedStatistics,
        onClick: (_) async {
          commonAction.updateSpeedStatistics();
        },
        checked: trayState.showTrayTitle,
      );
      menuItems.add(speedStatistics);
    }
    menuItems.add(MenuItem.separator());
    for (final mode in Mode.values) {
      menuItems.add(
        MenuItem.checkbox(
          label: Intl.message(mode.name),
          onClick: (_) {
            setupAction.changeMode(mode);
          },
          checked: mode == trayState.mode,
        ),
      );
    }
    menuItems.add(MenuItem.separator());
    if (system.isMacOS) {
      for (final group in trayState.groups) {
        final List<MenuItem> subMenuItems = [];
        for (final proxy in group.all) {
          subMenuItems.add(
            MenuItem.checkbox(
              label: proxy.name,
              checked:
                  ref.read(selectedProxyNameProvider(group.name)) == proxy.name,
              onClick: (_) {
                ref
                    .read(profilesActionProvider.notifier)
                    .updateCurrentSelectedMap(group.name, proxy.name);
                ref
                    .read(proxiesActionProvider.notifier)
                    .changeProxy(groupName: group.name, proxyName: proxy.name);
              },
            ),
          );
        }
        menuItems.add(
          MenuItem.submenu(
            label: group.name,
            submenu: Menu(items: subMenuItems),
          ),
        );
      }
      if (trayState.groups.isNotEmpty) {
        menuItems.add(MenuItem.separator());
      }
    }
    if (trayState.isStart) {
      menuItems.add(
        MenuItem.checkbox(
          label: appLocalizations.tun,
          onClick: (_) {
            systemAction.updateTun();
          },
          checked: trayState.tunEnable,
        ),
      );
      menuItems.add(
        MenuItem.checkbox(
          label: appLocalizations.systemProxy,
          onClick: (_) {
            systemAction.updateSystemProxy();
          },
          checked: trayState.systemProxy,
        ),
      );
      menuItems.add(MenuItem.separator());
    }
    final autoStartMenuItem = MenuItem.checkbox(
      label: appLocalizations.autoLaunch,
      onClick: (_) async {
        systemAction.updateAutoLaunch();
      },
      checked: trayState.autoLaunch,
    );
    final copyEnvVarMenuItem = MenuItem(
      label: appLocalizations.copyEnvVar,
      onClick: (_) async {
        await _copyEnv(trayState.port);
      },
    );
    menuItems.add(autoStartMenuItem);
    menuItems.add(copyEnvVarMenuItem);
    menuItems.add(MenuItem.separator());
    final exitMenuItem = MenuItem(
      label: appLocalizations.exit,
      onClick: (_) async {
        await systemAction.handleExit();
      },
    );
    menuItems.add(exitMenuItem);
    final menu = Menu(items: menuItems);
    await trayManager.setContextMenu(menu, brightness: trayState.brightness);
    if (system.isLinux) {
      await _updateSystemTray(
        isStart: trayState.isStart,
        tunEnable: trayState.tunEnable,
        monochrome: trayState.monochromeTrayIcon,
      );
    }
    await updateTrayTitle(
      showTrayTitle: trayState.showTrayTitle,
      isStart: trayState.isStart,
    );
  }

  Future<void> updateTrayTitle({
    required bool showTrayTitle,
    required bool isStart,
  }) async {
    if (!system.isMacOS) {
      return;
    }
    if (!showTrayTitle || !isStart) {
      _trafficTimer?.cancel();
      _trafficTimer = null;
      await trayManager.setTitle('');
      return;
    }
    _trafficTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_updateTraffic());
    });
    await _updateTraffic();
  }

  Future<void> _updateTraffic() async {
    if (_trafficTimer == null || _isUpdatingTraffic) {
      return;
    }
    _isUpdatingTraffic = true;
    try {
      final onlyStatisticsProxy = globalState.container
          .read(appSettingProvider)
          .onlyStatisticsProxy;
      final traffic = await coreController.getTraffic(onlyStatisticsProxy);
      if (_trafficTimer != null) {
        await trayManager.setTitle(traffic.trayTitle);
      }
    } catch (e) {
      commonPrint.log(
        'update tray traffic error: $e',
        logLevel: LogLevel.error,
      );
    } finally {
      _isUpdatingTraffic = false;
    }
  }

  Future<void> _copyEnv(int port) async {
    final url = 'http://127.0.0.1:$port';

    final cmdline = system.isWindows
        ? 'set \$env:all_proxy=$url'
        : 'export all_proxy=$url';

    await Clipboard.setData(ClipboardData(text: cmdline));
  }
}

final tray = system.isDesktop ? Tray() : null;

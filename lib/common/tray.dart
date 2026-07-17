import 'dart:async';
import 'dart:io';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tray_manager/tray_manager.dart';

import 'app_localizations.dart';
import 'constant.dart';
import 'keyboard.dart';
import 'print.dart';
import 'system.dart';
import 'window.dart';

typedef TrayMenuShortcut = ({
  String keyEquivalent,
  Set<TrayMenuItemModifier> modifiers,
});

final Map<PhysicalKeyboardKey, String> _macOSSpecialKeyEquivalents = {
  PhysicalKeyboardKey.enter: '\r',
  PhysicalKeyboardKey.escape: '\u001B',
  PhysicalKeyboardKey.backspace: '\u0008',
  PhysicalKeyboardKey.tab: '\t',
  PhysicalKeyboardKey.space: ' ',
  PhysicalKeyboardKey.quote: "'",
  PhysicalKeyboardKey.arrowUp: '\uF700',
  PhysicalKeyboardKey.arrowDown: '\uF701',
  PhysicalKeyboardKey.arrowLeft: '\uF702',
  PhysicalKeyboardKey.arrowRight: '\uF703',
  PhysicalKeyboardKey.f1: '\uF704',
  PhysicalKeyboardKey.f2: '\uF705',
  PhysicalKeyboardKey.f3: '\uF706',
  PhysicalKeyboardKey.f4: '\uF707',
  PhysicalKeyboardKey.f5: '\uF708',
  PhysicalKeyboardKey.f6: '\uF709',
  PhysicalKeyboardKey.f7: '\uF70A',
  PhysicalKeyboardKey.f8: '\uF70B',
  PhysicalKeyboardKey.f9: '\uF70C',
  PhysicalKeyboardKey.f10: '\uF70D',
  PhysicalKeyboardKey.f11: '\uF70E',
  PhysicalKeyboardKey.f12: '\uF70F',
  PhysicalKeyboardKey.insert: '\uF727',
  PhysicalKeyboardKey.delete: '\uF728',
  PhysicalKeyboardKey.home: '\uF729',
  PhysicalKeyboardKey.end: '\uF72B',
  PhysicalKeyboardKey.pageUp: '\uF72C',
  PhysicalKeyboardKey.pageDown: '\uF72D',
};

TrayMenuItemModifier _getTrayMenuItemModifier(KeyboardModifier modifier) {
  return switch (modifier) {
    KeyboardModifier.alt => TrayMenuItemModifier.option,
    KeyboardModifier.capsLock => TrayMenuItemModifier.capsLock,
    KeyboardModifier.control => TrayMenuItemModifier.control,
    KeyboardModifier.fn => TrayMenuItemModifier.function,
    KeyboardModifier.meta => TrayMenuItemModifier.command,
    KeyboardModifier.shift => TrayMenuItemModifier.shift,
  };
}

@visibleForTesting
TrayMenuShortcut? getTrayMenuShortcut(HotKeyAction hotKeyAction) {
  final key = hotKeyAction.key;
  if (key == null || hotKeyAction.modifiers.isEmpty) {
    return null;
  }
  final physicalKey = PhysicalKeyboardKey(key);
  final label = physicalKey.label;
  final keyEquivalent =
      _macOSSpecialKeyEquivalents[physicalKey] ??
      (label.length == 1 ? label.toLowerCase() : null);
  if (keyEquivalent == null) {
    return null;
  }
  return (
    keyEquivalent: keyEquivalent,
    modifiers: hotKeyAction.modifiers.map(_getTrayMenuItemModifier).toSet(),
  );
}

@visibleForTesting
({String? label, TrayMenuItemSublabelStyle style}) getTrayDelayPresentation(
  int? delay, {
  required String loadingLabel,
  required String timeoutLabel,
}) {
  if (delay == null) {
    return (label: null, style: TrayMenuItemSublabelStyle.badge);
  }
  if (delay == 0) {
    return (label: loadingLabel, style: TrayMenuItemSublabelStyle.muted);
  }
  if (delay < 0) {
    return (label: timeoutLabel, style: TrayMenuItemSublabelStyle.destructive);
  }
  return (label: '$delay ms', style: TrayMenuItemSublabelStyle.badge);
}

@visibleForTesting
String? getTrayGroupSelectionLabel(
  Group group,
  Map<String, String> selectedMap,
) {
  final selectedProxyName = group.getCurrentSelectedName(
    selectedMap[group.name] ?? '',
  );
  return selectedProxyName.isEmpty ? null : selectedProxyName;
}

String _trayDelayTestKey(String groupName) {
  return 'delay-test:${Uri.encodeComponent(groupName)}';
}

String _trayProxyDelayKey(String groupName, String proxyName) {
  return 'delay:${Uri.encodeComponent(groupName)}:'
      '${Uri.encodeComponent(proxyName)}';
}

class Tray {
  static Tray? _instance;

  Timer? _trafficTimer;
  bool _isUpdatingTraffic = false;
  final Set<String> _testingGroups = {};

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
    if (!system.isMacOS) {
      await trayManager.destroy();
    }
  }

  String getTrayIcon({
    required bool isStart,
    required bool tunEnable,
    bool monochrome = false,
  }) {
    final useSymbolicIcon = (monochrome && !system.isWindows) || system.isMacOS;
    if (!isStart && useSymbolicIcon) {
      return 'assets/images/icon/flclash-disabled-symbolic.svg';
    }
    if (useSymbolicIcon) {
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
      getTrayIcon(
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

    TrayMenuShortcut? shortcutFor(HotAction action) {
      if (!system.isMacOS) {
        return null;
      }
      return getTrayMenuShortcut(ref.read(getHotKeyActionProvider(action)));
    }

    final viewShortcut = shortcutFor(HotAction.view);
    final showMenuItem = TrayMenuItem(
      label: appLocalizations.show,
      usesCustomView: false,
      keyEquivalent: viewShortcut?.keyEquivalent,
      keyEquivalentModifiers:
          viewShortcut?.modifiers ?? const <TrayMenuItemModifier>{},
      onClickWithDetails: (_, details) {
        window?.show(activationTimestamp: details.activationTimestamp);
      },
    );
    menuItems.add(showMenuItem);
    final startShortcut = shortcutFor(HotAction.start);
    final startMenuItem = TrayMenuItem(
      label: trayState.isStart ? appLocalizations.stop : appLocalizations.start,
      usesCustomView: false,
      keyEquivalent: startShortcut?.keyEquivalent,
      keyEquivalentModifiers:
          startShortcut?.modifiers ?? const <TrayMenuItemModifier>{},
      onClick: (_) async {
        commonAction.updateStart();
      },
    );
    menuItems.add(startMenuItem);
    menuItems.add(MenuItem.separator());
    final nextMode =
        Mode.values[(trayState.mode.index + 1) % Mode.values.length];
    for (final mode in Mode.values) {
      final modeShortcut = mode == nextMode
          ? shortcutFor(HotAction.mode)
          : null;
      menuItems.add(
        TrayMenuItem.checkbox(
          label: Intl.message(mode.name),
          usesCustomView: false,
          keyEquivalent: modeShortcut?.keyEquivalent,
          keyEquivalentModifiers:
              modeShortcut?.modifiers ?? const <TrayMenuItemModifier>{},
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
        final isTesting = _testingGroups.contains(group.name);
        final selectedProxyName = group.getCurrentSelectedName(
          trayState.selectedMap[group.name] ?? '',
        );
        final List<MenuItem> subMenuItems = [
          TrayMenuItem(
            key: _trayDelayTestKey(group.name),
            label: appLocalizations.delayTest,
            disabled: isTesting,
            keepsMenuOpen: true,
            onClick: (_) {
              unawaited(_testGroupDelay(group));
            },
          ),
          MenuItem.separator(),
        ];
        for (final proxy in group.all) {
          final delay = ref.read(
            delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
          );
          final presentation = getTrayDelayPresentation(
            delay,
            loadingLabel: '...',
            timeoutLabel: appLocalizations.timeout,
          );
          subMenuItems.add(
            TrayMenuItem.checkbox(
              key: _trayProxyDelayKey(group.name, proxy.name),
              label: proxy.name,
              sublabel: presentation.label,
              sublabelStyle: presentation.style,
              checked: selectedProxyName == proxy.name,
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
          TrayMenuItem.submenu(
            label: group.name,
            sublabel: getTrayGroupSelectionLabel(group, trayState.selectedMap),
            sublabelStyle: TrayMenuItemSublabelStyle.secondary,
            submenu: Menu(items: subMenuItems),
          ),
        );
      }
      if (trayState.groups.isNotEmpty) {
        menuItems.add(MenuItem.separator());
      }
    }
    if (trayState.isStart) {
      final tunShortcut = shortcutFor(HotAction.tun);
      menuItems.add(
        TrayMenuItem.checkbox(
          label: appLocalizations.tun,
          usesCustomView: false,
          keyEquivalent: tunShortcut?.keyEquivalent,
          keyEquivalentModifiers:
              tunShortcut?.modifiers ?? const <TrayMenuItemModifier>{},
          onClick: (_) {
            systemAction.updateTun();
          },
          checked: trayState.tunEnable,
        ),
      );
      final proxyShortcut = shortcutFor(HotAction.proxy);
      menuItems.add(
        TrayMenuItem.checkbox(
          label: appLocalizations.systemProxy,
          usesCustomView: false,
          keyEquivalent: proxyShortcut?.keyEquivalent,
          keyEquivalentModifiers:
              proxyShortcut?.modifiers ?? const <TrayMenuItemModifier>{},
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
  }

  Future<void> _testGroupDelay(Group group) async {
    if (!_testingGroups.add(group.name)) {
      return;
    }
    final ref = globalState.container;
    await trayManager.updateMenuItem(
      key: _trayDelayTestKey(group.name),
      disabled: true,
    );
    try {
      await ref
          .read(proxiesActionProvider.notifier)
          .testProxyDelays(
            group.all,
            group.testUrl,
            onDelayChanged: (proxy) {
              return _updateProxyDelayMenuItem(group, proxy);
            },
          );
    } finally {
      _testingGroups.remove(group.name);
      await trayManager.updateMenuItem(
        key: _trayDelayTestKey(group.name),
        disabled: false,
      );
    }
  }

  Future<void> _updateProxyDelayMenuItem(Group group, Proxy proxy) async {
    final ref = globalState.container;
    final delay = ref.read(
      delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
    );
    final presentation = getTrayDelayPresentation(
      delay,
      loadingLabel: '...',
      timeoutLabel: currentAppLocalizations.timeout,
    );
    final label = presentation.label;
    if (label == null) {
      return;
    }
    await trayManager.updateMenuItem(
      key: _trayProxyDelayKey(group.name, proxy.name),
      sublabel: label,
      sublabelStyle: presentation.style,
    );
  }

  Future<void> updateTrayTitle({
    required bool showNetworkSpeed,
    required bool isStart,
  }) async {
    if (!system.isMacOS) {
      return;
    }
    if (!showNetworkSpeed || !isStart) {
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

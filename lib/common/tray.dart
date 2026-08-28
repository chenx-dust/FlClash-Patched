import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tray/tray.dart';

import 'app_localizations.dart';
import 'app_ports.dart';
import 'constant.dart';
import 'keyboard.dart';
import 'provider_reader.dart';
import 'system.dart';
import 'window.dart';

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

TrayMenuModifier _trayMenuModifier(KeyboardModifier modifier) {
  return switch (modifier) {
    KeyboardModifier.alt => TrayMenuModifier.option,
    KeyboardModifier.capsLock => TrayMenuModifier.capsLock,
    KeyboardModifier.control => TrayMenuModifier.control,
    KeyboardModifier.fn => TrayMenuModifier.function,
    KeyboardModifier.meta => TrayMenuModifier.command,
    KeyboardModifier.shift => TrayMenuModifier.shift,
  };
}

@visibleForTesting
TrayMenuShortcut? getTrayMenuShortcut(HotKeyAction action) {
  final key = action.key;
  if (key == null || action.modifiers.isEmpty) {
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
  return TrayMenuShortcut(
    key: keyEquivalent,
    modifiers: action.modifiers.map(_trayMenuModifier).toSet(),
  );
}

@visibleForTesting
({String? label, TrayMenuSublabelStyle style}) getTrayDelayPresentation(
  int? delay, {
  required String loadingLabel,
  required String timeoutLabel,
}) {
  if (delay == null) {
    return (label: null, style: TrayMenuSublabelStyle.badge);
  }
  if (delay == 0) {
    return (label: loadingLabel, style: TrayMenuSublabelStyle.muted);
  }
  if (delay < 0) {
    return (label: timeoutLabel, style: TrayMenuSublabelStyle.destructive);
  }
  return (label: '$delay ms', style: TrayMenuSublabelStyle.badge);
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

@visibleForTesting
String proxyEnvironmentCommand({required int port, required bool isWindows}) {
  final url = 'http://127.0.0.1:$port';
  return isWindows
      ? '\$env:http_proxy="$url"; \$env:https_proxy="$url"; '
            '\$env:all_proxy="$url"; '
            '\$env:no_proxy="localhost,::1,127.0.0.1"'
      : 'export http_proxy="$url"; export https_proxy="$url"; '
            'export all_proxy="$url"; '
            'export no_proxy="localhost,::1,127.0.0.1"';
}

class AppTray implements TrayPort {
  static AppTray? _instance;

  final bool isMacOS;
  final bool isWindows;

  bool _isShutDown = false;
  final Set<String> _testingGroups = {};

  AppTray._internal({required this.isMacOS, required this.isWindows});

  factory AppTray() {
    _instance ??= AppTray._internal(
      isMacOS: system.isMacOS,
      isWindows: system.isWindows,
    );
    return _instance!;
  }

  @visibleForTesting
  factory AppTray.forPlatform({
    required bool isMacOS,
    required bool isWindows,
  }) {
    return AppTray._internal(isMacOS: isMacOS, isWindows: isWindows);
  }

  String get trayIconSuffix {
    return isWindows ? 'ico' : 'png';
  }

  String getTrayIcon({
    required bool isStart,
    required bool tunEnable,
    bool monochrome = false,
  }) {
    if (isMacOS) {
      return isStart
          ? 'assets/images/icon/flclash-symbolic.svg'
          : 'assets/images/icon/flclash-disabled-symbolic.svg';
    }
    if (monochrome && !isMacOS && !isWindows) {
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

  @override
  Future<void> shutdown() async {
    _isShutDown = true;
    await Tray.instance.hide();
  }

  @override
  Future<void> update({
    required TrayState trayState,
    required Traffic traffic,
    required ProviderReader read,
  }) async {
    if (_isShutDown) {
      return;
    }
    await Tray.instance.show(
      TraySpec(
        icon: TrayIcon.asset(
          getTrayIcon(
            isStart: trayState.isStart,
            tunEnable: trayState.tunEnable,
            monochrome: trayState.monochromeTrayIcon,
          ),
          isTemplate: isMacOS,
        ),
        toolTip: appName,
        menu: _buildMenu(trayState: trayState, read: read),
        brightness: trayState.brightness == Brightness.dark
            ? TrayBrightness.dark
            : TrayBrightness.light,
      ),
    );
    await updateTitle(
      showTrayTitle: trayState.showTrayTitle,
      isStart: trayState.isStart,
      traffic: traffic,
    );
  }

  Future<void> updateTitle({
    required bool showTrayTitle,
    required bool isStart,
    required Traffic traffic,
  }) async {
    if (_isShutDown || !isMacOS) {
      return;
    }
    await Tray.instance.setTitle(
      showTrayTitle && isStart ? traffic.trayTitle : '',
    );
  }

  List<TrayMenuItem> _buildMenu({
    required TrayState trayState,
    required ProviderReader read,
  }) {
    final commonAction = read(commonActionProvider.notifier);
    final systemAction = read(systemActionProvider.notifier);
    final setupAction = read(setupActionProvider.notifier);
    final appLocalizations = currentAppLocalizations;

    TrayMenuShortcut? shortcutFor(HotAction action) {
      return isMacOS
          ? getTrayMenuShortcut(read(getHotKeyActionProvider(action)))
          : null;
    }

    final nextMode =
        Mode.values[(trayState.mode.index + 1) % Mode.values.length];

    return [
      TrayMenuAction(
        label: appLocalizations.show,
        shortcut: shortcutFor(HotAction.view),
        activatesWindow: true,
        onSelected: () {
          window?.show();
        },
      ),
      TrayMenuCheckbox(
        label: trayState.isStart
            ? appLocalizations.stop
            : appLocalizations.start,
        checked: trayState.isStart,
        shortcut: shortcutFor(HotAction.start),
        onSelected: commonAction.toggleRunning,
      ),
      if (isMacOS)
        TrayMenuCheckbox(
          label: appLocalizations.speedStatistics,
          checked: trayState.showTrayTitle,
          onSelected: commonAction.updateSpeedStatistics,
        ),
      const TrayMenuSeparator(),
      for (final mode in Mode.values)
        TrayMenuCheckbox(
          label: Intl.message(mode.name),
          checked: mode == trayState.mode,
          shortcut: mode == nextMode ? shortcutFor(HotAction.mode) : null,
          onSelected: () {
            setupAction.changeMode(mode);
          },
        ),
      const TrayMenuSeparator(),
      if (isMacOS) ..._buildGroupMenu(trayState: trayState, read: read),
      if (trayState.isStart) ...[
        TrayMenuCheckbox(
          label: appLocalizations.tun,
          checked: trayState.tunEnable,
          shortcut: shortcutFor(HotAction.tun),
          onSelected: systemAction.updateTun,
        ),
        TrayMenuCheckbox(
          label: appLocalizations.systemProxy,
          checked: trayState.systemProxy,
          shortcut: shortcutFor(HotAction.proxy),
          onSelected: systemAction.updateSystemProxy,
        ),
        const TrayMenuSeparator(),
      ],
      TrayMenuCheckbox(
        label: appLocalizations.autoLaunch,
        checked: trayState.autoLaunch,
        onSelected: systemAction.updateAutoLaunch,
      ),
      TrayMenuAction(
        label: appLocalizations.copyEnvVar,
        onSelected: () {
          _copyEnv(trayState.port);
        },
      ),
      const TrayMenuSeparator(),
      TrayMenuAction(
        label: appLocalizations.exit,
        onSelected: () {
          systemAction.handleExit();
        },
      ),
    ];
  }

  List<TrayMenuItem> _buildGroupMenu({
    required TrayState trayState,
    required ProviderReader read,
  }) {
    if (trayState.groups.isEmpty) {
      return const [];
    }
    return [
      for (final group in trayState.groups)
        TrayMenuSubmenu(
          label: group.name,
          sublabel: getTrayGroupSelectionLabel(group, trayState.selectedMap),
          items: [
            TrayMenuAction(
              key: _trayDelayTestKey(group.name),
              label: currentAppLocalizations.delayTest,
              enabled: !_testingGroups.contains(group.name),
              keepsMenuOpen: true,
              onSelected: () {
                unawaited(_testGroupDelay(group, read));
              },
            ),
            const TrayMenuSeparator(),
            for (final proxy in group.all)
              _buildProxyMenuItem(group: group, proxy: proxy, read: read),
          ],
        ),
      const TrayMenuSeparator(),
    ];
  }

  TrayMenuCheckbox _buildProxyMenuItem({
    required Group group,
    required Proxy proxy,
    required ProviderReader read,
  }) {
    final pending = read(
      delayTestPendingProvider(proxyName: proxy.name, testUrl: group.testUrl),
    );
    final delay = pending
        ? 0
        : read(delayProvider(proxyName: proxy.name, testUrl: group.testUrl));
    final presentation = getTrayDelayPresentation(
      delay,
      loadingLabel: '...',
      timeoutLabel: currentAppLocalizations.timeout,
    );
    return TrayMenuCheckbox(
      key: _trayProxyDelayKey(group.name, proxy.name),
      label: proxy.name,
      sublabel: presentation.label,
      sublabelStyle: presentation.style,
      checked: read(selectedProxyNameProvider(group.name)) == proxy.name,
      onSelected: () {
        read(
          proxiesActionProvider.notifier,
        ).changeProxy(groupName: group.name, proxyName: proxy.name);
      },
    );
  }

  Future<void> _testGroupDelay(Group group, ProviderReader read) async {
    if (!_testingGroups.add(group.name)) {
      return;
    }
    await Tray.instance.updateMenuItem(
      key: _trayDelayTestKey(group.name),
      enabled: false,
    );
    try {
      await read(proxiesActionProvider.notifier).delayTest(
        group.all,
        group.testUrl,
        () => _updateGroupDelays(group, read),
      );
    } finally {
      _testingGroups.remove(group.name);
      await Tray.instance.updateMenuItem(
        key: _trayDelayTestKey(group.name),
        enabled: true,
      );
    }
  }

  Future<void> _updateGroupDelays(Group group, ProviderReader read) async {
    for (final proxy in group.all) {
      final pending = read(
        delayTestPendingProvider(proxyName: proxy.name, testUrl: group.testUrl),
      );
      final delay = pending
          ? 0
          : read(delayProvider(proxyName: proxy.name, testUrl: group.testUrl));
      final presentation = getTrayDelayPresentation(
        delay,
        loadingLabel: '...',
        timeoutLabel: currentAppLocalizations.timeout,
      );
      final label = presentation.label;
      if (label == null) {
        continue;
      }
      await Tray.instance.updateMenuItem(
        key: _trayProxyDelayKey(group.name, proxy.name),
        sublabel: label,
        sublabelStyle: presentation.style,
      );
    }
  }

  Future<void> _copyEnv(int port) async {
    final cmdline = proxyEnvironmentCommand(port: port, isWindows: isWindows);
    await Clipboard.setData(ClipboardData(text: cmdline));
  }
}

final appTray = system.isDesktop ? AppTray() : null;

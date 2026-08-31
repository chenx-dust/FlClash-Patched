import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:tray/tray.dart';

import 'app_localizations.dart';
import 'l10n_labels.dart';
import 'app_ports.dart';
import 'constant.dart';
import 'keyboard.dart';
import 'provider_reader.dart';
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
  PhysicalKeyboardKey.quote: '\'',
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
  final modifiers = hotKeyAction.modifiers.map((modifier) {
    return switch (modifier) {
      KeyboardModifier.alt => TrayMenuItemModifier.option,
      KeyboardModifier.capsLock => TrayMenuItemModifier.capsLock,
      KeyboardModifier.control => TrayMenuItemModifier.control,
      KeyboardModifier.fn => TrayMenuItemModifier.function,
      KeyboardModifier.meta => TrayMenuItemModifier.command,
      KeyboardModifier.shift => TrayMenuItemModifier.shift,
    };
  }).toSet();
  return (keyEquivalent: keyEquivalent, modifiers: modifiers);
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
  final label = group.getCurrentSelectedName(selectedMap[group.name] ?? '');
  return label.isEmpty ? null : label;
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
    final useSymbolicIcon = isMacOS || (monochrome && !isWindows);
    if (useSymbolicIcon) {
      return isStart
          ? 'assets/images/icon/flclash-symbolic.svg'
          : 'assets/images/icon/flclash-disabled-symbolic.svg';
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
          size: 18,
        ),
        toolTip: appName,
        menu: _buildMenu(trayState: trayState, traffic: traffic, read: read),
        brightness: read(currentBrightnessProvider),
      ),
    );
    await updateTitle(
      showNetworkSpeed: trayState.showNetworkSpeed,
      isStart: trayState.isStart,
      traffic: traffic,
    );
  }

  Future<void> updateTitle({
    required bool showNetworkSpeed,
    required bool isStart,
    required Traffic traffic,
  }) async {
    if (_isShutDown || !isMacOS) {
      return;
    }
    await Tray.instance.setTitle(
      showNetworkSpeed && isStart ? traffic.trayTitle : '',
    );
  }

  List<TrayMenuItem> _buildMenu({
    required TrayState trayState,
    required Traffic traffic,
    required ProviderReader read,
  }) {
    final commonAction = read(commonActionProvider.notifier);
    final systemAction = read(systemActionProvider.notifier);
    final setupAction = read(setupActionProvider.notifier);
    final appLocalizations = currentAppLocalizations;

    TrayMenuShortcut? shortcutFor(HotAction action) {
      if (!isMacOS) {
        return null;
      }
      return getTrayMenuShortcut(read(getHotKeyActionProvider(action)));
    }

    final viewShortcut = shortcutFor(HotAction.view);
    final startShortcut = shortcutFor(HotAction.start);
    final nextMode =
        Mode.values[(trayState.mode.index + 1) % Mode.values.length];

    return [
      TrayMenuAction(
        label: appLocalizations.show,
        keyEquivalent: viewShortcut?.keyEquivalent,
        keyEquivalentModifiers: viewShortcut?.modifiers ?? const {},
        onSelectedWithDetails: (details) {
          window?.show(
            activationTimestamp: details.activationTimestamp,
            activationToken: details.activationToken,
          );
        },
      ),
      TrayMenuCheckbox(
        label: trayState.isStart
            ? appLocalizations.stop
            : appLocalizations.start,
        checked: false,
        keyEquivalent: startShortcut?.keyEquivalent,
        keyEquivalentModifiers: startShortcut?.modifiers ?? const {},
        onSelected: commonAction.toggleRunning,
      ),
      if (isMacOS)
        TrayMenuCheckbox(
          label: appLocalizations.speedStatistics,
          checked: trayState.showNetworkSpeed,
          onSelected: commonAction.updateSpeedStatistics,
        ),
      const TrayMenuSeparator(),
      for (final mode in Mode.values)
        TrayMenuCheckbox(
          label: mode.label,
          checked: mode == trayState.mode,
          keyEquivalent: mode == nextMode
              ? shortcutFor(HotAction.mode)?.keyEquivalent
              : null,
          keyEquivalentModifiers: mode == nextMode
              ? shortcutFor(HotAction.mode)?.modifiers ?? const {}
              : const {},
          onSelected: () {
            setupAction.changeMode(mode);
          },
        ),
      const TrayMenuSeparator(),
      if (isMacOS)
        ..._buildGroupMenu(trayState: trayState, traffic: traffic, read: read),
      if (trayState.isStart) ...[
        TrayMenuCheckbox(
          label: appLocalizations.tun,
          checked: trayState.tunEnable,
          keyEquivalent: shortcutFor(HotAction.tun)?.keyEquivalent,
          keyEquivalentModifiers:
              shortcutFor(HotAction.tun)?.modifiers ?? const {},
          onSelected: systemAction.updateTun,
        ),
        TrayMenuCheckbox(
          label: appLocalizations.systemProxy,
          checked: trayState.systemProxy,
          keyEquivalent: shortcutFor(HotAction.proxy)?.keyEquivalent,
          keyEquivalentModifiers:
              shortcutFor(HotAction.proxy)?.modifiers ?? const {},
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
    required Traffic traffic,
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
              label: currentAppLocalizations.delayTest,
              enabled: !_testingGroups.contains(group.name),
              keepsMenuOpen: true,
              onSelected: () {
                unawaited(
                  _testGroupDelay(
                    group: group,
                    trayState: trayState,
                    traffic: traffic,
                    read: read,
                  ),
                );
              },
            ),
            const TrayMenuSeparator(),
            for (final proxy in group.all)
              TrayMenuCheckbox(
                label: proxy.name,
                sublabel: getTrayDelayPresentation(
                  read(
                        delayTestPendingProvider(
                          proxyName: proxy.name,
                          testUrl: group.testUrl,
                        ),
                      )
                      ? 0
                      : read(
                          delayProvider(
                            proxyName: proxy.name,
                            testUrl: group.testUrl,
                          ),
                        ),
                  loadingLabel: '...',
                  timeoutLabel: currentAppLocalizations.timeout,
                ).label,
                sublabelStyle: getTrayDelayPresentation(
                  read(
                        delayTestPendingProvider(
                          proxyName: proxy.name,
                          testUrl: group.testUrl,
                        ),
                      )
                      ? 0
                      : read(
                          delayProvider(
                            proxyName: proxy.name,
                            testUrl: group.testUrl,
                          ),
                        ),
                  loadingLabel: '...',
                  timeoutLabel: currentAppLocalizations.timeout,
                ).style,
                checked:
                    getTrayGroupSelectionLabel(group, trayState.selectedMap) ==
                    proxy.name,
                onSelected: () {
                  read(
                    proxiesActionProvider.notifier,
                  ).changeProxy(groupName: group.name, proxyName: proxy.name);
                },
              ),
          ],
        ),
      const TrayMenuSeparator(),
    ];
  }

  Future<void> _testGroupDelay({
    required Group group,
    required TrayState trayState,
    required Traffic traffic,
    required ProviderReader read,
  }) async {
    if (!_testingGroups.add(group.name)) {
      return;
    }
    try {
      unawaited(update(trayState: trayState, traffic: traffic, read: read));
      await read(
        proxiesActionProvider.notifier,
      ).delayTest(group.all, group.testUrl);
    } finally {
      _testingGroups.remove(group.name);
      unawaited(update(trayState: trayState, traffic: traffic, read: read));
    }
  }

  Future<void> _copyEnv(int port) async {
    final url = 'http://127.0.0.1:$port';

    final cmdline = isWindows
        ? '\$env:http_proxy="$url"; \$env:https_proxy="$url"; '
              '\$env:all_proxy="$url"; '
              '\$env:no_proxy="localhost,::1,127.0.0.1"'
        : 'export http_proxy="$url"; export https_proxy="$url"; '
              'export all_proxy="$url"; '
              'export no_proxy="localhost,::1,127.0.0.1"';

    await Clipboard.setData(ClipboardData(text: cmdline));
  }
}

final appTray = system.isDesktop ? AppTray() : null;

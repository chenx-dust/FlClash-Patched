import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:tray/tray.dart';

import 'app_localizations.dart';
import 'l10n_labels.dart';
import 'app_ports.dart';
import 'compute.dart';
import 'constant.dart';
import 'keyboard.dart';
import 'provider_reader.dart';
import 'string.dart';
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
  return (
    label: '$delay ms',
    style: delay < 600
        ? TrayMenuItemSublabelStyle.badge
        : TrayMenuItemSublabelStyle.warning,
  );
}

@visibleForTesting
String? getTrayGroupSelectionLabel(
  Group group,
  Map<String, String> selectedMap,
) {
  final label = group.getCurrentSelectedName(selectedMap[group.name] ?? '');
  return label.isEmpty ? null : label;
}

String _trayDelayTestKey(String groupName) {
  return 'delay-test:${Uri.encodeComponent(groupName)}';
}

String _trayProxyDelayKey(String groupName, String proxyName) {
  return 'delay:${Uri.encodeComponent(groupName)}:'
      '${Uri.encodeComponent(proxyName)}';
}

class _TrayDelaySnapshot {
  final List<Group> _groups;
  final Map<String, String> _selectedMap;
  final DelayMap _delays;
  final Set<String> _pending;
  final String _defaultTestUrl;
  final Map<String, SelectedProxyState> _selections = {};

  _TrayDelaySnapshot(ProviderReader read)
    : _groups = read(groupsProvider),
      _selectedMap = read(selectedMapProvider),
      _delays = read(delayDataSourceProvider),
      _pending = read(pendingDelayTestsProvider),
      _defaultTestUrl = read(appSettingProvider).testUrl;

  ({String proxyName, String testUrl}) targetFor(
    String proxyName,
    String? testUrl,
  ) {
    final selected = _selections.putIfAbsent(
      proxyName,
      () => computeRealSelectedProxyState(
        proxyName,
        groups: _groups,
        selectedMap: _selectedMap,
      ),
    );
    final effectiveUrl = selected.testUrl.takeFirstValid([
      testUrl,
      _defaultTestUrl,
    ]);
    return (proxyName: selected.proxyName, testUrl: effectiveUrl);
  }

  int? delayFor(String proxyName, String? testUrl) {
    final target = targetFor(proxyName, testUrl);
    if (_pending.contains(delayTestKey(target.testUrl, target.proxyName))) {
      return 0;
    }
    return _delays[target.testUrl]?[target.proxyName];
  }
}

class AppTray implements TrayPort {
  static AppTray? _instance;

  final bool isMacOS;
  final bool isWindows;

  bool _isShutDown = false;
  final Set<String> _testingGroups = {};
  List<Group> _menuGroups = const [];

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

  String get _trayIconSuffix {
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
      return '${isWindows ? 'assets/images/tray/windows' : 'assets/images/tray/unix'}/status_1.$_trayIconSuffix';
    }
    if (!tunEnable) {
      return '${isWindows ? 'assets/images/tray/windows' : 'assets/images/tray/unix'}/status_2.$_trayIconSuffix';
    }
    return '${isWindows ? 'assets/images/tray/windows' : 'assets/images/tray/unix'}/status_3.$_trayIconSuffix';
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
        menu: _buildMenu(trayState: trayState, read: read),
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
    await Tray.instance.setTitle(showNetworkSpeed ? traffic.trayTitle : '');
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
      if (!isMacOS) {
        return null;
      }
      return getTrayMenuShortcut(read(getHotKeyActionProvider(action)));
    }

    final viewShortcut = shortcutFor(HotAction.view);
    final startShortcut = shortcutFor(HotAction.start);
    final exitShortcut = shortcutFor(HotAction.exit);
    final copyEnvShortcut = shortcutFor(HotAction.copyEnv);
    final delayShortcut = shortcutFor(HotAction.delayTest);
    final updateShortcut = shortcutFor(HotAction.updateProfiles);

    return [
      TrayMenuAction(
        label: _menuLabel(appLocalizations.show, HotAction.view, read),
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
        label: _menuLabel(
          trayState.isStart ? appLocalizations.stop : appLocalizations.start,
          HotAction.start,
          read,
        ),
        checked: false,
        keyEquivalent: startShortcut?.keyEquivalent,
        keyEquivalentModifiers: startShortcut?.modifiers ?? const {},
        onSelected: commonAction.toggleRunning,
      ),
      const TrayMenuSeparator(),
      for (final mode in Mode.values)
        TrayMenuCheckbox(
          label: _menuLabel(mode.label, _modeHotAction(mode), read),
          checked: mode == trayState.mode,
          keyEquivalent: shortcutFor(_modeHotAction(mode))?.keyEquivalent,
          keyEquivalentModifiers:
              shortcutFor(_modeHotAction(mode))?.modifiers ?? const {},
          onSelected: () {
            setupAction.changeMode(mode);
          },
        ),
      const TrayMenuSeparator(),
      _buildProfileMenu(read),
      const TrayMenuSeparator(),
      ..._buildGroupMenu(trayState: trayState, read: read),
      TrayMenuAction(
        label: _menuLabel(
          appLocalizations.actionDelayTest,
          HotAction.delayTest,
          read,
        ),
        keyEquivalent: delayShortcut?.keyEquivalent,
        keyEquivalentModifiers: delayShortcut?.modifiers ?? const {},
        onSelected: () {
          unawaited(
            read(
              proxiesActionProvider.notifier,
            ).delayTestGroups(trayState.groups),
          );
        },
      ),
      TrayMenuAction(
        label: _menuLabel(
          appLocalizations.actionUpdateProfiles,
          HotAction.updateProfiles,
          read,
        ),
        keyEquivalent: updateShortcut?.keyEquivalent,
        keyEquivalentModifiers: updateShortcut?.modifiers ?? const {},
        onSelected: () {
          unawaited(
            globalState.safeRun(
              read(profilesActionProvider.notifier).updateProfiles,
            ),
          );
        },
      ),
      const TrayMenuSeparator(),
      TrayMenuCheckbox(
        label: _menuLabel(appLocalizations.tun, HotAction.tun, read),
        checked: trayState.tunEnable,
        keyEquivalent: shortcutFor(HotAction.tun)?.keyEquivalent,
        keyEquivalentModifiers:
            shortcutFor(HotAction.tun)?.modifiers ?? const {},
        onSelected: systemAction.updateTun,
      ),
      TrayMenuCheckbox(
        label: _menuLabel(appLocalizations.systemProxy, HotAction.proxy, read),
        checked: trayState.systemProxy,
        keyEquivalent: shortcutFor(HotAction.proxy)?.keyEquivalent,
        keyEquivalentModifiers:
            shortcutFor(HotAction.proxy)?.modifiers ?? const {},
        onSelected: systemAction.updateSystemProxy,
      ),
      const TrayMenuSeparator(),
      TrayMenuCheckbox(
        label: appLocalizations.autoLaunch,
        checked: trayState.autoLaunch,
        onSelected: systemAction.updateAutoLaunch,
      ),
      TrayMenuAction(
        label: _menuLabel(appLocalizations.copyEnvVar, HotAction.copyEnv, read),
        keyEquivalent: copyEnvShortcut?.keyEquivalent,
        keyEquivalentModifiers: copyEnvShortcut?.modifiers ?? const {},
        onSelected: systemAction.copyProxyEnv,
      ),
      const TrayMenuSeparator(),
      TrayMenuAction(
        label: _menuLabel(appLocalizations.exit, HotAction.exit, read),
        keyEquivalent: exitShortcut?.keyEquivalent,
        keyEquivalentModifiers: exitShortcut?.modifiers ?? const {},
        onSelected: () {
          systemAction.handleExit();
        },
      ),
    ];
  }

  TrayMenuSubmenu _buildProfileMenu(ProviderReader read) {
    final profiles = read(profilesProvider);
    final currentProfile = read(currentProfileProvider);
    return TrayMenuSubmenu(
      label: currentAppLocalizations.profile,
      sublabel: currentProfile?.realLabel,
      usesCustomView: isMacOS,
      items: [
        for (final profile in profiles)
          TrayMenuCheckbox(
            label: profile.realLabel,
            checked: profile.id == currentProfile?.id,
            onSelected: () {
              if (read(profilesProvider).any((item) => item.id == profile.id)) {
                read(currentProfileIdProvider.notifier).value = profile.id;
              }
            },
          ),
        if (profiles.isNotEmpty) const TrayMenuSeparator(),
        TrayMenuAction(
          label: currentAppLocalizations.sync,
          enabled:
              currentProfile != null &&
              currentProfile.type != ProfileType.file &&
              !read(isUpdatingProvider(currentProfile.updatingKey)),
          onSelected: () async {
            final profile = read(currentProfileProvider);
            if (profile == null ||
                profile.type == ProfileType.file ||
                read(isUpdatingProvider(profile.updatingKey))) {
              return;
            }
            await globalState.safeRun(() async {
              await read(
                profilesActionProvider.notifier,
              ).updateProfile(profile, showLoading: true);
            });
          },
        ),
      ],
    );
  }

  List<TrayMenuItem> _buildGroupMenu({
    required TrayState trayState,
    required ProviderReader read,
  }) {
    _menuGroups = trayState.groups;
    if (trayState.groups.isEmpty) {
      return const [];
    }
    final delays = _TrayDelaySnapshot(read);
    return [
      for (final group in trayState.groups)
        _buildGroupMenuItem(
          group: group,
          selectedMap: trayState.selectedMap,
          delays: delays,
          read: read,
        ),
      const TrayMenuSeparator(),
    ];
  }

  TrayMenuSubmenu _buildGroupMenuItem({
    required Group group,
    required Map<String, String> selectedMap,
    required _TrayDelaySnapshot delays,
    required ProviderReader read,
  }) {
    final selectedProxyName = group.getCurrentSelectedName(
      selectedMap[group.name] ?? '',
    );
    return TrayMenuSubmenu(
      key: 'group:${Uri.encodeComponent(group.name)}',
      label: group.name,
      sublabel: getTrayGroupSelectionLabel(group, selectedMap),
      usesCustomView: isMacOS,
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
          _buildProxyMenuItem(
            group: group,
            proxy: proxy,
            selectedProxyName: selectedProxyName,
            delays: delays,
            read: read,
          ),
      ],
    );
  }

  TrayMenuCheckbox _buildProxyMenuItem({
    required Group group,
    required Proxy proxy,
    required String? selectedProxyName,
    required _TrayDelaySnapshot delays,
    required ProviderReader read,
  }) {
    final presentation = getTrayDelayPresentation(
      delays.delayFor(proxy.name, group.testUrl),
      loadingLabel: '...',
      timeoutLabel: currentAppLocalizations.timeout,
    );
    return TrayMenuCheckbox(
      key: _trayProxyDelayKey(group.name, proxy.name),
      label: proxy.name,
      sublabel: presentation.label,
      sublabelStyle: presentation.style,
      usesCustomView: isMacOS,
      checked: selectedProxyName == proxy.name,
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
    await Tray.instance.updateMenuItems([
      TrayMenuItemUpdate(key: _trayDelayTestKey(group.name), enabled: false),
    ]);
    try {
      await read(proxiesActionProvider.notifier).delayTest(
        group.all,
        group.testUrl,
        const Duration(seconds: 1),
        (proxyNames) => _updateGroupDelays(group, read, proxyNames),
      );
    } finally {
      _testingGroups.remove(group.name);
      await Tray.instance.updateMenuItems([
        TrayMenuItemUpdate(key: _trayDelayTestKey(group.name), enabled: true),
      ]);
    }
  }

  Future<void> _updateGroupDelays(
    Group group,
    ProviderReader read,
    Set<String> proxyNames,
  ) async {
    final updates = <TrayMenuItemUpdate>[];
    final delays = _TrayDelaySnapshot(read);
    final targets = {
      for (final name in proxyNames) delays.targetFor(name, group.testUrl),
    };
    for (final menuGroup in _menuGroups) {
      for (final proxy in menuGroup.all) {
        if (!targets.contains(
          delays.targetFor(proxy.name, menuGroup.testUrl),
        )) {
          continue;
        }
        final presentation = getTrayDelayPresentation(
          delays.delayFor(proxy.name, menuGroup.testUrl),
          loadingLabel: '...',
          timeoutLabel: currentAppLocalizations.timeout,
        );
        final label = presentation.label;
        if (label == null) {
          continue;
        }
        updates.add(
          TrayMenuItemUpdate(
            key: _trayProxyDelayKey(menuGroup.name, proxy.name),
            sublabel: label,
            sublabelStyle: presentation.style,
          ),
        );
      }
    }
    await Tray.instance.updateMenuItems(updates);
  }

  String _menuLabel(String label, HotAction action, ProviderReader read) {
    if (isMacOS) {
      return label;
    }
    final hotKey = read(getHotKeyActionProvider(action));
    final key = hotKey.key;
    if (key == null) {
      return label;
    }
    final shortcut = ShortcutLabels(
      isMacOS: false,
      isWindows: isWindows,
    ).text(hotKey.modifiers, key);
    if (shortcut.isEmpty) {
      return label;
    }
    return '$label\t$shortcut';
  }
}

HotAction _modeHotAction(Mode mode) {
  return switch (mode) {
    Mode.rule => HotAction.ruleMode,
    Mode.global => HotAction.globalMode,
    Mode.direct => HotAction.directMode,
  };
}

final appTray = system.isDesktop ? AppTray() : null;

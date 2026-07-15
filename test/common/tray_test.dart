import 'dart:io';

import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  group('Tray.getTrayIcon', () {
    final tray = Tray();
    final suffix = tray.trayIconSuffix;

    test('returns idle icon when core is not started', () {
      expect(
        tray.getTrayIcon(isStart: false, tunEnable: false),
        Platform.isMacOS
            ? 'assets/images/icon/flclash-disabled-symbolic.svg'
            : 'assets/images/icon/status_1.$suffix',
      );
    });

    test('returns a dimmed symbolic icon when monochrome and not started', () {
      expect(
        tray.getTrayIcon(isStart: false, tunEnable: false, monochrome: true),
        Platform.isWindows
            ? 'assets/images/icon/status_1.$suffix'
            : 'assets/images/icon/flclash-disabled-symbolic.svg',
      );
    });

    test('returns normal mode icon when core is started without TUN', () {
      expect(
        tray.getTrayIcon(isStart: true, tunEnable: false),
        Platform.isMacOS
            ? 'assets/images/icon/flclash-symbolic.svg'
            : 'assets/images/icon/status_2.$suffix',
      );
    });

    test('returns enhanced mode icon when core is started with TUN', () {
      expect(
        tray.getTrayIcon(isStart: true, tunEnable: true),
        Platform.isMacOS
            ? 'assets/images/icon/flclash-symbolic.svg'
            : 'assets/images/icon/status_3.$suffix',
      );
    });
  });

  group('getTrayDelayPresentation', () {
    test('hides untested delay values', () {
      final presentation = getTrayDelayPresentation(
        null,
        loadingLabel: 'Loading',
        timeoutLabel: 'Timeout',
      );

      expect(presentation.label, isNull);
      expect(presentation.style, TrayMenuItemSublabelStyle.badge);
    });

    test('formats loading, timeout, and successful delay values', () {
      final loading = getTrayDelayPresentation(
        0,
        loadingLabel: 'Loading',
        timeoutLabel: 'Timeout',
      );
      final timeout = getTrayDelayPresentation(
        -1,
        loadingLabel: 'Loading',
        timeoutLabel: 'Timeout',
      );
      final success = getTrayDelayPresentation(
        42,
        loadingLabel: 'Loading',
        timeoutLabel: 'Timeout',
      );

      expect(loading.label, 'Loading');
      expect(loading.style, TrayMenuItemSublabelStyle.muted);
      expect(timeout.label, 'Timeout');
      expect(timeout.style, TrayMenuItemSublabelStyle.destructive);
      expect(success.label, '42 ms');
      expect(success.style, TrayMenuItemSublabelStyle.badge);
    });
  });

  group('getTrayMenuShortcut', () {
    test('maps printable keys and macOS modifiers', () {
      final shortcut = getTrayMenuShortcut(
        HotKeyAction(
          action: HotAction.start,
          key: PhysicalKeyboardKey.keyS.usbHidUsage,
          modifiers: const {KeyboardModifier.meta, KeyboardModifier.shift},
        ),
      );

      expect(shortcut?.keyEquivalent, 's');
      expect(shortcut?.modifiers, {
        TrayMenuItemModifier.command,
        TrayMenuItemModifier.shift,
      });
    });

    test('maps AppKit special key equivalents', () {
      final shortcut = getTrayMenuShortcut(
        HotKeyAction(
          action: HotAction.view,
          key: PhysicalKeyboardKey.arrowUp.usbHidUsage,
          modifiers: const {KeyboardModifier.control},
        ),
      );

      expect(shortcut?.keyEquivalent, '\uF700');
      expect(shortcut?.modifiers, {TrayMenuItemModifier.control});
    });

    test('ignores incomplete hotkeys', () {
      expect(
        getTrayMenuShortcut(const HotKeyAction(action: HotAction.start)),
        isNull,
      );
      expect(
        getTrayMenuShortcut(
          HotKeyAction(
            action: HotAction.start,
            key: PhysicalKeyboardKey.keyS.usbHidUsage,
          ),
        ),
        isNull,
      );
    });
  });

  group('getTrayGroupSelectionLabel', () {
    test('shows the selected proxy for selector groups', () {
      const group = Group(
        type: GroupType.Selector,
        name: 'Proxy',
        now: 'Fallback',
      );

      expect(
        getTrayGroupSelectionLabel(group, {'Proxy': 'Selected'}),
        'Selected',
      );
    });

    test('falls back to the core selection when none is saved', () {
      const group = Group(
        type: GroupType.Selector,
        name: 'Proxy',
        now: 'Default',
      );

      expect(getTrayGroupSelectionLabel(group, const {}), 'Default');
    });

    test('shows the computed selection for url-test groups', () {
      const group = Group(
        type: GroupType.URLTest,
        name: 'Auto',
        now: 'Fastest',
      );

      expect(
        getTrayGroupSelectionLabel(group, {'Auto': 'Override'}),
        'Fastest',
      );
    });

    test('shows the current proxy for non-selector groups', () {
      const group = Group(
        type: GroupType.LoadBalance,
        name: 'Balance',
        now: 'Proxy A',
      );

      expect(getTrayGroupSelectionLabel(group, const {}), 'Proxy A');
    });

    test('hides the label when the group has no current proxy', () {
      const group = Group(type: GroupType.Selector, name: 'Proxy');

      expect(getTrayGroupSelectionLabel(group, const {}), isNull);
    });
  });
}

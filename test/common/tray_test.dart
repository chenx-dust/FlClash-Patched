import 'dart:io';

import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';
import 'package:tray/tray.dart';

void main() {
  group('AppTray.getTrayIcon', () {
    final tray = AppTray();
    final suffix = tray.trayIconSuffix;

    test('returns idle icon when core is not started', () {
      expect(
        tray.getTrayIcon(isStart: false, tunEnable: false),
        'assets/images/icon/status_1.$suffix',
      );
    });

    test('returns symbolic icons for monochrome non-Windows trays', () {
      final symbolicTray = AppTray.forPlatform(
        isMacOS: false,
        isWindows: false,
      );
      expect(
        symbolicTray.getTrayIcon(
          isStart: true,
          tunEnable: false,
          monochrome: true,
        ),
        'assets/images/icon/flclash-symbolic.svg',
      );
      expect(
        symbolicTray.getTrayIcon(
          isStart: false,
          tunEnable: false,
          monochrome: true,
        ),
        'assets/images/icon/flclash-disabled-symbolic.svg',
      );
    });

    test('returns normal mode icon when core is started without TUN', () {
      expect(
        tray.getTrayIcon(isStart: true, tunEnable: false),
        Platform.isMacOS
            ? 'assets/images/icon/status_1.$suffix'
            : 'assets/images/icon/status_2.$suffix',
      );
    });

    test('returns enhanced mode icon when core is started with TUN', () {
      expect(
        tray.getTrayIcon(isStart: true, tunEnable: true),
        Platform.isMacOS
            ? 'assets/images/icon/status_1.$suffix'
            : 'assets/images/icon/status_3.$suffix',
      );
    });
  });

  group('getTrayDelayPresentation', () {
    test('formats loading, timeout, and successful delay values', () {
      expect(
        getTrayDelayPresentation(
          0,
          loadingLabel: 'Loading',
          timeoutLabel: 'Timeout',
        ),
        (label: 'Loading', style: TrayMenuItemSublabelStyle.muted),
      );
      expect(
        getTrayDelayPresentation(
          -1,
          loadingLabel: 'Loading',
          timeoutLabel: 'Timeout',
        ),
        (label: 'Timeout', style: TrayMenuItemSublabelStyle.destructive),
      );
      expect(
        getTrayDelayPresentation(
          42,
          loadingLabel: 'Loading',
          timeoutLabel: 'Timeout',
        ).label,
        '42 ms',
      );
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
  });

  test('group selection labels follow selector semantics', () {
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
}

import 'dart:io';

import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';
import 'package:tray/tray.dart';
import 'package:test/test.dart';

void main() {
  group('getTrayDelayPresentation', () {
    test('maps loading, timeout and measured delays', () {
      expect(
        getTrayDelayPresentation(
          0,
          loadingLabel: '...',
          timeoutLabel: 'Timeout',
        ),
        (label: '...', style: TrayMenuSublabelStyle.muted),
      );
      expect(
        getTrayDelayPresentation(
          -1,
          loadingLabel: '...',
          timeoutLabel: 'Timeout',
        ),
        (label: 'Timeout', style: TrayMenuSublabelStyle.destructive),
      );
      expect(
        getTrayDelayPresentation(
          42,
          loadingLabel: '...',
          timeoutLabel: 'Timeout',
        ),
        (label: '42 ms', style: TrayMenuSublabelStyle.badge),
      );
    });

    test('leaves untested proxies without a sublabel', () {
      expect(
        getTrayDelayPresentation(
          null,
          loadingLabel: '...',
          timeoutLabel: 'Timeout',
        ).label,
        isNull,
      );
    });
  });

  group('getTrayMenuShortcut', () {
    test('maps a printable key and modifiers for macOS menus', () {
      final shortcut = getTrayMenuShortcut(
        HotKeyAction(
          action: HotAction.view,
          key: PhysicalKeyboardKey.keyK.usbHidUsage,
          modifiers: const {KeyboardModifier.meta, KeyboardModifier.shift},
        ),
      );

      expect(shortcut?.key, 'k');
      expect(shortcut?.modifiers, {
        TrayMenuModifier.command,
        TrayMenuModifier.shift,
      });
    });

    test('maps a special key for macOS menus', () {
      final shortcut = getTrayMenuShortcut(
        HotKeyAction(
          action: HotAction.view,
          key: PhysicalKeyboardKey.arrowUp.usbHidUsage,
          modifiers: const {KeyboardModifier.control},
        ),
      );

      expect(shortcut?.key, '\uF700');
      expect(shortcut?.modifiers, {TrayMenuModifier.control});
    });
  });

  group('proxyEnvironmentCommand', () {
    test('builds PowerShell proxy environment assignments', () {
      expect(
        proxyEnvironmentCommand(port: 7890, isWindows: true),
        '\$env:http_proxy="http://127.0.0.1:7890"; '
        '\$env:https_proxy="http://127.0.0.1:7890"; '
        '\$env:all_proxy="http://127.0.0.1:7890"; '
        '\$env:no_proxy="localhost,::1,127.0.0.1"',
      );
    });

    test('builds POSIX proxy environment assignments', () {
      expect(
        proxyEnvironmentCommand(port: 7890, isWindows: false),
        'export http_proxy="http://127.0.0.1:7890"; '
        'export https_proxy="http://127.0.0.1:7890"; '
        'export all_proxy="http://127.0.0.1:7890"; '
        'export no_proxy="localhost,::1,127.0.0.1"',
      );
    });
  });

  group('AppTray.getTrayIcon', () {
    final tray = AppTray();
    final suffix = tray.trayIconSuffix;

    test('returns idle icon when core is not started', () {
      expect(
        tray.getTrayIcon(isStart: false, tunEnable: false),
        Platform.isMacOS
            ? 'assets/images/icon/flclash-disabled-symbolic.svg'
            : 'assets/images/icon/status_1.$suffix',
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

    test('uses the symbolic icon only on supported desktop platforms', () {
      final linuxTray = AppTray.forPlatform(isMacOS: false, isWindows: false);
      final windowsTray = AppTray.forPlatform(isMacOS: false, isWindows: true);
      final macOSTray = AppTray.forPlatform(isMacOS: true, isWindows: false);

      expect(
        linuxTray.getTrayIcon(isStart: true, tunEnable: true, monochrome: true),
        'assets/images/icon/flclash-symbolic.svg',
      );
      expect(
        windowsTray.getTrayIcon(
          isStart: true,
          tunEnable: true,
          monochrome: true,
        ),
        'assets/images/icon/status_3.ico',
      );
      expect(
        macOSTray.getTrayIcon(isStart: true, tunEnable: true, monochrome: true),
        'assets/images/icon/flclash-symbolic.svg',
      );
    });
  });
}

import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';
import 'package:tray/tray.dart';

void main() {
  group('AppTray.getTrayIcon', () {
    final windows = AppTray.forPlatform(isMacOS: false, isWindows: true);
    final macOS = AppTray.forPlatform(isMacOS: true, isWindows: false);
    final linux = AppTray.forPlatform(isMacOS: false, isWindows: false);

    test('windows loads ico files from the windows directory', () {
      expect(
        windows.getTrayIcon(isStart: false, tunEnable: false),
        'assets/images/tray/windows/status_1.ico',
      );
      expect(
        windows.getTrayIcon(isStart: true, tunEnable: false),
        'assets/images/tray/windows/status_2.ico',
      );
      expect(
        windows.getTrayIcon(isStart: true, tunEnable: true),
        'assets/images/tray/windows/status_3.ico',
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

    test('linux loads png files from the unix directory', () {
      expect(
        linux.getTrayIcon(isStart: false, tunEnable: false),
        'assets/images/tray/unix/status_1.png',
      );
      expect(
        linux.getTrayIcon(isStart: true, tunEnable: false),
        'assets/images/tray/unix/status_2.png',
      );
      expect(
        linux.getTrayIcon(isStart: true, tunEnable: true),
        'assets/images/tray/unix/status_3.png',
      );
    });

    test('macOS keeps the template icon in every state', () {
      for (final (isStart, tunEnable) in [
        (false, false),
        (true, false),
        (true, true),
      ]) {
        expect(
          macOS.getTrayIcon(isStart: isStart, tunEnable: tunEnable),
          isStart
              ? 'assets/images/icon/flclash-symbolic.svg'
              : 'assets/images/icon/flclash-disabled-symbolic.svg',
        );
      }
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

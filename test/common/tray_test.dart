import 'dart:io';

import 'package:fl_clash/common/tray.dart';
import 'package:test/test.dart';

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
        'assets/images/icon/status_1.png',
      );
    });
  });
}

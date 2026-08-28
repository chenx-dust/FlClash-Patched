import 'tray_menu.dart';

enum TrayIconPosition { leading, trailing }

enum TrayBrightness { light, dark }

final class TrayIcon {
  const TrayIcon.asset(
    this.asset, {
    this.isTemplate = false,
    this.size = 18,
    this.position = TrayIconPosition.leading,
  });

  final String asset;
  final bool isTemplate;
  final int size;
  final TrayIconPosition position;
}

final class TraySpec {
  const TraySpec({
    required this.icon,
    this.toolTip = '',
    this.menu = const [],
    this.brightness = TrayBrightness.light,
  });

  final TrayIcon icon;
  final String toolTip;
  final List<TrayMenuItem> menu;
  final TrayBrightness brightness;
}

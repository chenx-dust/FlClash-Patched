typedef TrayMenuItemSelectedCallback = void Function();

enum TrayMenuModifier { option, capsLock, control, function, command, shift }

enum TrayMenuSublabelStyle { badge, muted, destructive, secondary }

final class TrayMenuShortcut {
  const TrayMenuShortcut({required this.key, this.modifiers = const {}});

  final String key;
  final Set<TrayMenuModifier> modifiers;
}

sealed class TrayMenuItem {
  const TrayMenuItem();
}

final class TrayMenuAction extends TrayMenuItem {
  const TrayMenuAction({
    required this.label,
    this.key,
    this.enabled = true,
    this.sublabel,
    this.sublabelStyle = TrayMenuSublabelStyle.badge,
    this.keepsMenuOpen = false,
    this.shortcut,
    this.activatesWindow = false,
    this.onSelected,
  });

  final String label;
  final String? key;
  final bool enabled;
  final String? sublabel;
  final TrayMenuSublabelStyle sublabelStyle;
  final bool keepsMenuOpen;
  final TrayMenuShortcut? shortcut;
  final bool activatesWindow;
  final TrayMenuItemSelectedCallback? onSelected;
}

final class TrayMenuCheckbox extends TrayMenuItem {
  const TrayMenuCheckbox({
    required this.label,
    required this.checked,
    this.key,
    this.enabled = true,
    this.sublabel,
    this.sublabelStyle = TrayMenuSublabelStyle.badge,
    this.keepsMenuOpen = false,
    this.shortcut,
    this.onSelected,
  });

  final String label;
  final String? key;
  final bool checked;
  final bool enabled;
  final String? sublabel;
  final TrayMenuSublabelStyle sublabelStyle;
  final bool keepsMenuOpen;
  final TrayMenuShortcut? shortcut;
  final TrayMenuItemSelectedCallback? onSelected;
}

final class TrayMenuSubmenu extends TrayMenuItem {
  const TrayMenuSubmenu({
    required this.label,
    required this.items,
    this.key,
    this.enabled = true,
    this.sublabel,
    this.sublabelStyle = TrayMenuSublabelStyle.secondary,
  });

  final String label;
  final String? key;
  final List<TrayMenuItem> items;
  final bool enabled;
  final String? sublabel;
  final TrayMenuSublabelStyle sublabelStyle;
}

final class TrayMenuSeparator extends TrayMenuItem {
  const TrayMenuSeparator();
}

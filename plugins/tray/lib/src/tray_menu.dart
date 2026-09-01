typedef TrayMenuItemSelectedCallback = void Function();
typedef TrayMenuItemSelectedWithDetailsCallback =
    void Function(TrayMenuSelectionDetails details);

enum TrayMenuItemModifier {
  option,
  capsLock,
  control,
  function,
  command,
  shift,
}

enum TrayMenuItemSublabelStyle { badge, secondary, muted, destructive }

final class TrayMenuSelectionDetails {
  const TrayMenuSelectionDetails({
    this.activationTimestamp,
    this.activationToken,
  });

  final int? activationTimestamp;
  final String? activationToken;
}

sealed class TrayMenuItem {
  const TrayMenuItem();
}

final class TrayMenuAction extends TrayMenuItem {
  const TrayMenuAction({
    required this.label,
    this.key,
    this.enabled = true,
    this.onSelected,
    this.onSelectedWithDetails,
    this.sublabel,
    this.sublabelStyle = TrayMenuItemSublabelStyle.badge,
    this.keepsMenuOpen = false,
    this.usesCustomView = false,
    this.keyEquivalent,
    this.keyEquivalentModifiers = const {},
  });

  final String label;
  final String? key;
  final bool enabled;
  final TrayMenuItemSelectedCallback? onSelected;
  final TrayMenuItemSelectedWithDetailsCallback? onSelectedWithDetails;
  final String? sublabel;
  final TrayMenuItemSublabelStyle sublabelStyle;
  final bool keepsMenuOpen;
  final bool usesCustomView;
  final String? keyEquivalent;
  final Set<TrayMenuItemModifier> keyEquivalentModifiers;
}

final class TrayMenuCheckbox extends TrayMenuItem {
  const TrayMenuCheckbox({
    required this.label,
    required this.checked,
    this.key,
    this.enabled = true,
    this.onSelected,
    this.onSelectedWithDetails,
    this.sublabel,
    this.sublabelStyle = TrayMenuItemSublabelStyle.badge,
    this.keepsMenuOpen = false,
    this.usesCustomView = false,
    this.keyEquivalent,
    this.keyEquivalentModifiers = const {},
  });

  final String label;
  final String? key;
  final bool checked;
  final bool enabled;
  final TrayMenuItemSelectedCallback? onSelected;
  final TrayMenuItemSelectedWithDetailsCallback? onSelectedWithDetails;
  final String? sublabel;
  final TrayMenuItemSublabelStyle sublabelStyle;
  final bool keepsMenuOpen;
  final bool usesCustomView;
  final String? keyEquivalent;
  final Set<TrayMenuItemModifier> keyEquivalentModifiers;
}

final class TrayMenuSubmenu extends TrayMenuItem {
  const TrayMenuSubmenu({
    required this.label,
    required this.items,
    this.key,
    this.enabled = true,
    this.sublabel,
    this.sublabelStyle = TrayMenuItemSublabelStyle.secondary,
    this.usesCustomView = false,
  });

  final String label;
  final String? key;
  final List<TrayMenuItem> items;
  final bool enabled;
  final String? sublabel;
  final TrayMenuItemSublabelStyle sublabelStyle;
  final bool usesCustomView;
}

final class TrayMenuSeparator extends TrayMenuItem {
  const TrayMenuSeparator();
}

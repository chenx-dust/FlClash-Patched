import 'dart:convert';

import 'tray_menu.dart';
import 'tray_spec.dart';

final class EncodedTray {
  const EncodedTray({
    required this.icon,
    required this.toolTip,
    required this.menu,
    required this.itemsById,
    required this.signature,
  });

  final Map<String, Object?> icon;
  final String toolTip;
  final List<Object?> menu;
  final Map<int, TrayMenuItem> itemsById;
  final String signature;
}

abstract final class TrayCodec {
  static const int firstItemId = 1024;

  static EncodedTray encode(TraySpec spec) {
    final itemsById = <int, TrayMenuItem>{};
    final menu = _encodeItems(spec.menu, itemsById, _IdAllocator());
    final icon = <String, Object?>{
      'asset': spec.icon.asset,
      'isTemplate': spec.icon.isTemplate,
      'size': spec.icon.size,
      'position': spec.icon.position.name,
    };
    return EncodedTray(
      icon: icon,
      toolTip: spec.toolTip,
      menu: menu,
      itemsById: itemsById,
      signature: jsonEncode(<String, Object?>{
        'icon': icon,
        'toolTip': spec.toolTip,
        'brightness': spec.brightness?.name,
        'menu': menu,
      }),
    );
  }

  static List<Object?> _encodeItems(
    List<TrayMenuItem> items,
    Map<int, TrayMenuItem> sink,
    _IdAllocator allocator,
  ) {
    return items.map((item) {
      final id = allocator.next();
      sink[id] = item;
      return switch (item) {
        TrayMenuSeparator() => <String, Object?>{'id': id, 'type': 'separator'},
        TrayMenuAction(
          :final label,
          :final key,
          :final enabled,
          :final sublabel,
          :final sublabelStyle,
          :final keepsMenuOpen,
          :final usesCustomView,
          :final keyEquivalent,
          :final keyEquivalentModifiers,
        ) =>
          <String, Object?>{
            'id': id,
            'type': 'action',
            'label': label,
            'key': ?key,
            'enabled': enabled,
            'sublabel': ?sublabel,
            'sublabelStyle': sublabelStyle.name,
            'keepsMenuOpen': keepsMenuOpen,
            if (usesCustomView) 'usesCustomView': true,
            'keyEquivalent': ?keyEquivalent,
            'keyEquivalentModifiers': keyEquivalentModifiers
                .map((modifier) => modifier.name)
                .toList(),
          },
        TrayMenuCheckbox(
          :final label,
          :final key,
          :final enabled,
          :final checked,
          :final sublabel,
          :final sublabelStyle,
          :final keepsMenuOpen,
          :final usesCustomView,
          :final keyEquivalent,
          :final keyEquivalentModifiers,
        ) =>
          <String, Object?>{
            'id': id,
            'type': 'checkbox',
            'label': label,
            'key': ?key,
            'enabled': enabled,
            'checked': checked,
            'sublabel': ?sublabel,
            'sublabelStyle': sublabelStyle.name,
            'keepsMenuOpen': keepsMenuOpen,
            if (usesCustomView) 'usesCustomView': true,
            'keyEquivalent': ?keyEquivalent,
            'keyEquivalentModifiers': keyEquivalentModifiers
                .map((modifier) => modifier.name)
                .toList(),
          },
        TrayMenuSubmenu(
          :final label,
          :final key,
          :final enabled,
          :final items,
          :final sublabel,
          :final sublabelStyle,
          :final usesCustomView,
        ) =>
          <String, Object?>{
            'id': id,
            'type': 'submenu',
            'label': label,
            'key': ?key,
            'enabled': enabled,
            'sublabel': ?sublabel,
            'sublabelStyle': sublabelStyle.name,
            if (usesCustomView) 'usesCustomView': true,
            'items': _encodeItems(items, sink, allocator),
          },
      };
    }).toList();
  }
}

final class _IdAllocator {
  int _next = TrayCodec.firstItemId;

  int next() {
    final id = _next;
    _next = _next + 1;
    return id;
  }
}

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
        'menu': menu,
        'brightness': spec.brightness.name,
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
          :final shortcut,
          :final activatesWindow,
        ) =>
          <String, Object?>{
            'id': id,
            'type': 'action',
            'label': label,
            'enabled': enabled,
            ..._encodePresentation(
              key: key,
              sublabel: sublabel,
              sublabelStyle: sublabelStyle,
              keepsMenuOpen: keepsMenuOpen,
              usesCustomView: usesCustomView,
            ),
            'activatesWindow': activatesWindow,
            ..._encodeShortcut(shortcut),
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
          :final shortcut,
        ) =>
          <String, Object?>{
            'id': id,
            'type': 'checkbox',
            'label': label,
            'enabled': enabled,
            'checked': checked,
            ..._encodePresentation(
              key: key,
              sublabel: sublabel,
              sublabelStyle: sublabelStyle,
              keepsMenuOpen: keepsMenuOpen,
              usesCustomView: usesCustomView,
            ),
            ..._encodeShortcut(shortcut),
          },
        TrayMenuSubmenu(
          :final label,
          :final key,
          :final enabled,
          :final sublabel,
          :final sublabelStyle,
          :final usesCustomView,
          :final items,
        ) =>
          <String, Object?>{
            'id': id,
            'type': 'submenu',
            'label': label,
            'enabled': enabled,
            ..._encodePresentation(
              key: key,
              sublabel: sublabel,
              sublabelStyle: sublabelStyle,
              usesCustomView: usesCustomView,
            ),
            'items': _encodeItems(items, sink, allocator),
          },
      };
    }).toList();
  }

  static Map<String, Object?> _encodeShortcut(TrayMenuShortcut? shortcut) {
    if (shortcut == null) {
      return const {};
    }
    return {
      'keyEquivalent': shortcut.key,
      'keyEquivalentModifiers': shortcut.modifiers
          .map((modifier) => modifier.name)
          .toList(),
    };
  }

  static Map<String, Object?> _encodePresentation({
    required String? key,
    required String? sublabel,
    required TrayMenuSublabelStyle sublabelStyle,
    bool keepsMenuOpen = false,
    bool usesCustomView = false,
  }) {
    final result = <String, Object?>{};
    if (key != null) {
      result['key'] = key;
    }
    if (sublabel != null) {
      result['sublabel'] = sublabel;
      result['sublabelStyle'] = sublabelStyle.name;
    }
    if (keepsMenuOpen) {
      result['keepsMenuOpen'] = true;
    }
    if (usesCustomView) {
      result['usesCustomView'] = true;
    }
    return result;
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

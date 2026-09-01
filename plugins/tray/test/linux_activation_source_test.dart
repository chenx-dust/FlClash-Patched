import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux tray forwards and consumes Wayland activation tokens', () {
    final source = File(
      _resolveSource('linux/tray_plugin.cc'),
    ).readAsStringSync();

    expect(source, contains('ProvideXdgActivationToken'));
    expect(source, contains('activationToken'));
    expect(source, contains('pending_activation_token'));
    expect(source, contains('g_dbus_connection_remove_filter'));
  });

  test('Linux recursively updates keyed GTK menu items', () {
    final source = File(
      _resolveSource('linux/tray_plugin.cc'),
    ).readAsStringSync();

    expect(source, contains('find_menu_item(submenu, key)'));
    expect(
      source,
      contains('g_object_set_data_full(G_OBJECT(item), "tray-menu-key"'),
    );
    expect(source, contains('gtk_menu_item_set_label'));
    expect(source, contains('gtk_widget_set_sensitive'));
    expect(source, contains('GTK_IS_CHECK_MENU_ITEM(item)'));
    expect(source, contains('handle_update_menu_item(self, args)'));
  });
}

String _resolveSource(String relativePath) {
  for (final prefix in ['', '..', 'plugins/tray']) {
    final candidate = File(
      prefix.isEmpty ? relativePath : '$prefix/$relativePath',
    );
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }
  throw StateError('Unable to locate $relativePath');
}

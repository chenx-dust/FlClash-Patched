import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

File _resolveSource(String relativePath) {
  final inPlugin = File('plugins/tray/$relativePath');
  if (inPlugin.existsSync()) {
    return inPlugin;
  }
  return File(relativePath);
}

void main() {
  late String pluginSource;

  setUpAll(() {
    pluginSource = _resolveSource(
      'linux/tray_plugin.cc',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('Linux show menu activation presents the application window', () {
    expect(pluginSource, contains('"activatesWindow"'));
    expect(pluginSource, contains('gtk_window_present_with_time'));
  });

  test('Wayland activation tokens are consumed before presenting', () {
    expect(pluginSource, contains('ProvideXdgActivationToken'));
    expect(
      pluginSource,
      contains('gdk_wayland_display_set_startup_notification_id'),
    );
    expect(pluginSource, contains('pending_activation_token'));
  });

  test('Linux recursively updates keyed GTK menu items', () {
    expect(pluginSource, contains('find_menu_item(submenu, key)'));
    expect(
      pluginSource,
      contains('g_object_set_data_full(G_OBJECT(item), "tray-menu-key"'),
    );
    expect(pluginSource, contains('gtk_menu_item_set_label'));
    expect(pluginSource, contains('gtk_widget_set_sensitive'));
    expect(
      pluginSource,
      contains('GTK_IS_CHECK_MENU_ITEM(item)'),
      reason: 'checked state must only be applied to checkbox items',
    );
    expect(pluginSource, contains('handle_update_menu_item(self, args)'));
    expect(
      pluginSource,
      contains('''
  GtkWidget* item = find_menu_item(self->menu, key);
  if (item == nullptr) {
    return respond(false);
  }

  const char* label'''),
      reason: 'unknown keys must not be reported as applied',
    );
    expect(
      pluginSource,
      contains('''
  if (GTK_IS_CHECK_MENU_ITEM(item) &&
      bool_value_if_present(args, "checked", &checked)) {
    gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(item), checked);
  }'''),
      reason: 'checkbox state updates must preserve the GTK item type',
    );
  });
}

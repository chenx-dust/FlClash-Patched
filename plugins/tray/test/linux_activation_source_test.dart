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
}

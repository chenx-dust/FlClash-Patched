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
}

String _resolveSource(String relativePath) {
  for (final prefix in ['', '..']) {
    final candidate = File(
      prefix.isEmpty ? relativePath : '$prefix/$relativePath',
    );
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }
  throw StateError('Unable to locate $relativePath');
}

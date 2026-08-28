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
  late String trayWindowSource;
  late String cmakeSource;

  setUpAll(() {
    pluginSource = _resolveSource(
      'windows/tray_plugin.cpp',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    trayWindowSource = _resolveSource(
      'windows/tray_window.cpp',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    cmakeSource = _resolveSource(
      'windows/CMakeLists.txt',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('windows menu clicks come from TrackPopupMenu, not WM_COMMAND', () {
    expect(pluginSource, contains('TPM_RETURNCMD'));
    expect(pluginSource, isNot(contains('WM_COMMAND')));
  });

  test('windows tray owns its icon and menu with a hidden window', () {
    expect(pluginSource, contains('tray_window_->hwnd()'));
    expect(pluginSource, contains('SetForegroundWindow(window)'));
    expect(pluginSource, contains('NIM_SETFOCUS'));
    expect(trayWindowSource, contains('WS_EX_TOOLWINDOW'));
    expect(cmakeSource, contains('"tray_window.cpp"'));
  });

  test('windows menu applies the requested brightness', () {
    expect(pluginSource, contains('ApplyMenuBrightness'));
    expect(pluginSource, contains('*brightness == "dark"'));
  });

  test('windows show reports a failed icon load', () {
    expect(
      pluginSource,
      contains('''
  if (loaded == nullptr) {
    return false;
  }'''),
    );
  });

  test('windows rejected show leaves the visible menu untouched', () {
    expect(pluginSource, contains('bool applied = ApplyIcon(!visible_);'));
    expect(
      pluginSource,
      contains('''
  if (!applied) {
    return false;
  }
  visible_ = true;

  const flutter::EncodableList* items'''),
    );
  });
}

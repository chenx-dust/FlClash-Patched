import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  test('Windows keeps one instance and wakes its existing window', () {
    final main = _source('windows/runner/main.cpp');
    final window = _source('windows/runner/win32_window.cpp');

    expect(main, contains('CreateMutexW'));
    expect(main, contains('com.follow.clash.debug.SingleInstance'));
    expect(main, contains('FLCLASH_DEBUG_RUNNER_WIN32_WINDOW'));
    expect(main, contains('FlClash.ActivateWindow'));
    expect(main, contains('PostMessageW'));
    expect(window, contains('FlClash.ActivateWindow'));
    expect(window, contains('FLCLASH_DEBUG_RUNNER_WIN32_WINDOW'));
    expect(window, contains('ShowWindowAsync'));
    expect(window, contains('AddTab'));
    expect(window, contains('SetForegroundWindow'));
  });

  test('Linux activation presents the existing application window', () {
    final source = _source('linux/runner/my_application.cc');

    expect(source, isNot(contains('G_APPLICATION_NON_UNIQUE')));
    expect(source, contains('gtk_application_get_windows'));
    expect(source, contains('gtk_window_present'));
  });

  test('macOS prohibits duplicates and restores a reopened window', () {
    final plist = _source('macos/Runner/Info.plist');
    final delegate = _source('macos/Runner/AppDelegate.swift');

    expect(plist, contains('<key>LSMultipleInstancesProhibited</key>'));
    expect(delegate, contains('window.deminiaturize(self)'));
    expect(delegate, contains('NSApp.activate(ignoringOtherApps: true)'));
  });
}

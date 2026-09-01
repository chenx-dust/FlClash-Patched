import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

File _resolveSource(String relativePath) {
  final direct = File(relativePath);
  if (direct.existsSync()) {
    return direct;
  }
  final inPlugin = File('plugins/tray/$relativePath');
  if (inPlugin.existsSync()) {
    return inPlugin;
  }
  return direct;
}

void main() {
  late String pluginSource;

  setUpAll(() {
    pluginSource = _resolveSource('windows/tray_plugin.cpp').readAsStringSync();
  });

  test('windows menu clicks come from TrackPopupMenu, not WM_COMMAND', () {
    expect(pluginSource, contains('TPM_RETURNCMD'));
    expect(pluginSource, isNot(contains('WM_COMMAND')));
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
    icon_data_.hIcon = previous_icon;'''),
    );
    expect(
      pluginSource.indexOf('visible_ = true;'),
      lessThan(pluginSource.indexOf('menu_items_.clear();\n    RebuildMenu')),
      reason: 'the visible menu may only change after native icon acceptance',
    );
  });

  test('windows recursively indexes keyed items without changing ids', () {
    expect(pluginSource, contains('MenuItemLocation{menu, position'));
    expect(pluginSource, contains('menu_items_.clear();\n    RebuildMenu'));
    expect(pluginSource, contains('SetMenuItemInfoW'));
    expect(pluginSource, contains('location->second.checkbox'));
    expect(
      pluginSource.indexOf('RebuildMenu(submenu, *children)'),
      lessThan(pluginSource.indexOf('menu_items_.try_emplace(')),
      reason: 'nested keys must be indexed by the same recursive rebuild',
    );
    expect(
      pluginSource,
      contains('static_cast<UINT_PTR>(IntAt(*entry, "id", 0))'),
    );
    expect(
      pluginSource,
      contains('flutter::EncodableValue(command)'),
      reason: 'the selected command must round-trip as the original Dart id',
    );
    expect(
      pluginSource,
      isNot(contains('kMenuCommandIdOffset')),
      reason: 'updates must preserve the existing Dart command ids',
    );
  });

  test('windows reports an unknown menu key without mutating the menu', () {
    expect(
      pluginSource,
      contains('''
  const auto location = menu_items_.find(*key);
  if (location == menu_items_.end()) {
    return false;
  }

  const std::string* label'''),
    );
  });

  test('windows can make the Flutter window own the popup menu', () {
    expect(pluginSource, contains('BoolAt(*arguments, "bringAppToFront"'));
    expect(
      pluginSource,
      contains('''
  if (bring_app_to_front) {
    if (registrar_ != nullptr && registrar_->GetView() != nullptr) {
      window = ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT);
    }
  } else if (tray_window_ != nullptr) {
    window = tray_window_->hwnd();
  }'''),
    );
    expect(
      pluginSource,
      contains('''
  if (window == nullptr) {
    return false;
  }'''),
      reason: 'the hidden owner remains the default path',
    );
  });

  test('windows preserves the old icon when native apply fails', () {
    expect(pluginSource, contains('const HICON previous_icon'));
    expect(
      pluginSource,
      contains('''
    icon_data_.hIcon = previous_icon;
    tool_tip_ = previous_tool_tip;
    menu_is_dark_ = previous_menu_is_dark;
    ::DestroyIcon(loaded);
    return false;'''),
    );
  });
}

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
  late String titleViewSource;
  late String statusItemSource;
  late String menuSource;
  late String pluginSource;

  setUpAll(() {
    titleViewSource = _resolveSource(
      'macos/tray/Sources/tray/TrayTitleView.swift',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    statusItemSource = _resolveSource(
      'macos/tray/Sources/tray/TrayStatusItem.swift',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    menuSource = _resolveSource(
      'macos/tray/Sources/tray/TrayMenu.swift',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    pluginSource = _resolveSource(
      'macos/tray/Sources/tray/TrayPlugin.swift',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('macOS tray title is self-drawn instead of using NSTextField', () {
    expect(titleViewSource, contains('final class TrayTitleView: NSView'));
    expect(titleViewSource, isNot(contains('NSTextField')));
  });

  test('macOS tray title text is drawn centered', () {
    expect(titleViewSource, contains('override var isFlipped: Bool'));
    expect(titleViewSource, contains('.alignment = .right'));
    expect(
      titleViewSource,
      contains('(bounds.height - textBounds.height) / 2'),
    );
  });

  test('macOS tray title widens instead of clipping long speeds', () {
    expect(titleViewSource, contains('invalidateIntrinsicContentSize'));
    expect(
      titleViewSource,
      contains('max(TrayTitleView.width, ceil(measure(text).width))'),
    );
    expect(
      statusItemSource,
      contains('greaterThanOrEqualToConstant: TrayTitleView.width'),
    );
  });

  test('macOS status item reports a missing status button', () {
    expect(statusItemSource, contains('init?('));
    expect(
      statusItemSource,
      contains('''
        guard let button = statusItem.button else {
            NSStatusBar.system.removeStatusItem(statusItem)
            return nil
        }'''),
    );
  });

  test('macOS status item only refits the button on visible change', () {
    expect(statusItemSource, contains('if contentView.setImage(image'));
    expect(statusItemSource, contains('if contentView.setTitle(title)'));
    expect(statusItemSource, contains('wasHidden != imageView.isHidden'));
  });

  test('macOS status item preserves its position and compact spacing', () {
    expect(statusItemSource, contains('statusItem.autosaveName'));
    expect(statusItemSource, contains('stack.spacing = 2'));
    expect(
      statusItemSource,
      contains('updateInsets(hasTitle: !title.isEmpty)'),
    );
    expect(
      statusItemSource,
      contains('stackLeadingConstraint.constant = hasTitle ? 4 : 6'),
    );
    expect(
      statusItemSource,
      contains('stackTrailingConstraint.constant = hasTitle ? -8 : -6'),
    );
  });

  test('macOS tray title uses the tuned network speed typography', () {
    expect(titleViewSource, contains('maximumLineHeight = 9.5'));
    expect(
      titleViewSource,
      contains('NSFont.systemFont(ofSize: 9, weight: .medium)'),
    );
    expect(titleViewSource, contains('NSColor.textColor'));
  });

  test('macOS tray icon position reorders image and title views', () {
    expect(statusItemSource, contains('applyPosition'));
    expect(statusItemSource, contains('insertArrangedSubview'));
    expect(statusItemSource, contains('position == "trailing"'));
  });

  test('macOS tray menu applies key equivalents and modifiers', () {
    expect(menuSource, contains('item.keyEquivalent = keyEquivalent'));
    expect(menuSource, contains('item.keyEquivalentModifierMask'));
    expect(menuSource, contains('result.insert(.command)'));
  });

  test('macOS tray menu renders and updates live sublabels', () {
    expect(menuSource, contains('final class TrayMenuItemView: NSView'));
    expect(menuSource, contains('drawSublabel'));
    expect(menuSource, contains('func updateMenuItem'));
    expect(pluginSource, contains('case "updateMenuItem"'));
    expect(menuSource, contains('arguments["label"] as? String'));
    expect(menuSource, contains('arguments["checked"] as? Bool'));
  });

  test('macOS delay tests keep the tracked menu open', () {
    expect(menuSource, contains('if !keepsMenuOpen'));
    expect(menuSource, contains('menuItem.menu?.cancelTracking()'));
  });
}

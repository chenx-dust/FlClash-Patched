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
    expect(menuSource, contains('entry["usesCustomView"]'));
    expect(pluginSource, contains('case "updateMenuItem"'));
    expect(menuSource, contains('arguments["label"] as? String'));
    expect(menuSource, contains('arguments["checked"] as? Bool'));
  });

  test('macOS delay tests keep the tracked menu open', () {
    expect(menuSource, contains('if !keepsMenuOpen'));
    expect(menuSource, contains('menuItem.menu?.cancelTracking()'));
  });

  test('macOS updates an attached menu only after full compatibility', () {
    expect(pluginSource, contains('item.statusItem.menu === \$0'));
    expect(
      menuSource,
      contains('''
    func update(items entries: [[String: Any]]) -> Bool {
        guard isCompatible(with: entries) else {
            return false
        }
        apply(entries)'''),
    );
    expect(
      menuSource,
      contains('nativeItem.trayType == type'),
      reason: 'action, checkbox and submenu transitions must rebuild',
    );
    expect(
      menuSource,
      contains('submenu.isCompatible(with: children)'),
      reason: 'nested incompatibility must be found before any mutation',
    );
    expect(menuSource, contains('guard item.isSeparatorItem else'));
    expect(
      menuSource,
      contains('''
private enum TrayMenuItemType: String {
    case action
    case checkbox
    case submenu
    case separator
}'''),
      reason: 'all non-separator transitions need distinct native identities',
    );

    final compatibilityStart = menuSource.indexOf(
      'private func isCompatible(with entries:',
    );
    final applyStart = menuSource.indexOf(
      'private func apply(_ entries:',
      compatibilityStart,
    );
    final compatibilityBody = menuSource.substring(
      compatibilityStart,
      applyStart,
    );
    expect(compatibilityBody, isNot(contains('item.title =')));
    expect(compatibilityBody, isNot(contains('item.state =')));
    expect(compatibilityBody, isNot(contains('submenu.apply(')));

    expect(
      pluginSource.indexOf('attachedMenu.update(items: items)'),
      lessThan(pluginSource.indexOf('let built = TrayMenu(items: items)')),
      reason: 'a type or recursive mismatch must fall through to a rebuild',
    );
  });

  test('macOS full updates clear state that is no longer present', () {
    expect(
      menuSource,
      contains('item.state = type == .checkbox && checked ? .on : .off'),
    );
    expect(menuSource, contains('item.keyEquivalent = ""'));
    expect(menuSource, contains('item.keyEquivalentModifierMask = []'));
    expect(menuSource, contains('item.view = nil'));
  });

  test('macOS incompatible tracking rebuild replaces the attached menu', () {
    final showStart = pluginSource.indexOf('if let items = arguments["menu"]');
    final showEnd = pluginSource.indexOf('\n        return true', showStart);
    final showBody = pluginSource.substring(showStart, showEnd);

    final assignIndex = showBody.indexOf('menu = built');
    final cancelIndex = showBody.indexOf('attachedMenu.cancelTracking()');
    final reopenIndex = showBody.indexOf('item.openMenu(built)');
    expect(assignIndex, greaterThanOrEqualTo(0));
    expect(cancelIndex, greaterThan(assignIndex));
    expect(reopenIndex, greaterThan(cancelIndex));
    expect(
      showBody.indexOf('attachedMenu.update(items: items)'),
      lessThan(showBody.indexOf('let built = TrayMenu(items: items)')),
      reason: 'compatible attached menus must still update in place',
    );

    expect(
      pluginSource,
      contains('''
    public func menuDidClose(_ closedMenu: NSMenu) {
        guard statusItem?.statusItem.menu === closedMenu else {
            return
        }
        statusItem?.closeMenu()
    }'''),
      reason: 'a delayed close from the old menu must preserve the replacement',
    );
  });

  test('macOS keyed checked updates only affect checkbox items', () {
    final updateStart = menuSource.indexOf('func updateMenuItem(_ arguments:');
    final updateEnd = menuSource.indexOf(
      '\n    private func makeItem',
      updateStart,
    );
    final updateBody = menuSource.substring(updateStart, updateEnd);

    expect(
      updateBody,
      contains('''
                let checked = nativeItem?.trayType == .checkbox
                    ? arguments["checked"] as? Bool
                    : nil'''),
    );
    expect(
      updateBody,
      contains('if let checked {\n                    item.state'),
    );
    expect(updateBody, contains('checked: checked'));
    expect(
      updateBody.indexOf('let checked = nativeItem?.trayType == .checkbox'),
      lessThan(updateBody.indexOf('checked: checked')),
      reason: 'the custom view must receive the type-filtered checked value',
    );
  });

  test('macOS keyed sublabel update creates a missing custom view', () {
    final updateStart = menuSource.indexOf('func updateMenuItem(_ arguments:');
    final updateEnd = menuSource.indexOf(
      '\n    private func makeItem',
      updateStart,
    );
    final updateBody = menuSource.substring(updateStart, updateEnd);
    final createStart = updateBody.indexOf(
      'else if let sublabel, !sublabel.isEmpty',
    );
    final resizeStart = updateBody.indexOf('updateCustomViewWidths(');

    expect(createStart, greaterThanOrEqualTo(0));
    expect(
      updateBody.substring(createStart, resizeStart),
      contains('''item.view = TrayMenuItemView(
                        label: item.title,
                        sublabel: sublabel'''),
    );
    expect(
      updateBody.substring(createStart, resizeStart),
      contains('?? (type == .submenu ? .secondary : .badge)'),
      reason: 'new submenu views default to secondary presentation',
    );
    expect(
      updateBody.substring(createStart, resizeStart),
      contains('checked: type == .checkbox && item.state == .on'),
      reason: 'actions and submenus must not gain a drawn checkmark',
    );
    expect(
      updateBody.substring(createStart, resizeStart),
      contains('hasSubmenu: type == .submenu'),
    );
    expect(
      resizeStart,
      greaterThan(createStart),
      reason: 'the newly inserted view must participate in menu width layout',
    );
  });
}

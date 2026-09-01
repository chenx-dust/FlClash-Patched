import AppKit

private enum TrayMenuItemSublabelStyle: String {
    case badge
    case muted
    case destructive
    case secondary
}

private enum TrayMenuItemType: String {
    case action
    case checkbox
    case submenu
    case separator
}

private final class TrayNativeMenuItem: NSMenuItem {
    let trayType: TrayMenuItemType

    init(type: TrayMenuItemType) {
        trayType = type
        super.init(title: "", action: nil, keyEquivalent: "")
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class TrayMenuItemView: NSView {
    private enum Metrics {
        static let height: CGFloat = 24
        static let minimumWidth: CGFloat = 270
        static let maximumWidth: CGFloat = 520
        static let checkmarkLeading: CGFloat = 7
        static let titleLeading: CGFloat = 25
        static let titleBadgeSpacing: CGFloat = 12
        static let trailing: CGFloat = 9
        static let badgeHeight: CGFloat = 16
        static let badgeHorizontalPadding: CGFloat = 5
        static let submenuIndicatorWidth: CGFloat = 14
        static let minimumTitleWidth: CGFloat = 60
        static let highlightHorizontalInset: CGFloat = 5
        static let highlightVerticalInset: CGFloat = 0
        static let highlightCornerRadius: CGFloat = 6
    }

    private var label: String
    private var sublabel: String?
    private var sublabelStyle: TrayMenuItemSublabelStyle
    private var checked: Bool
    private var keepsMenuOpen: Bool
    private var hasSubmenu: Bool
    private var pointerInside = false
    private var trackingAreaReference: NSTrackingArea?

    private let titleFont = NSFont.menuFont(ofSize: 0)
    private let badgeFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.labelFontSize,
        weight: .medium
    )

    init(
        label: String,
        sublabel: String?,
        sublabelStyle: TrayMenuItemSublabelStyle,
        checked: Bool,
        keepsMenuOpen: Bool,
        hasSubmenu: Bool
    ) {
        self.label = label
        self.sublabel = sublabel
        self.sublabelStyle = sublabelStyle
        self.checked = checked
        self.keepsMenuOpen = keepsMenuOpen
        self.hasSubmenu = hasSubmenu
        super.init(
            frame: NSRect(
                x: 0,
                y: 0,
                width: Metrics.minimumWidth,
                height: Metrics.height
            )
        )
        frame.size.width = preferredWidth
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: preferredWidth, height: Metrics.height)
    }

    var preferredWidth: CGFloat {
        let titleWidth = ceil(
            (label as NSString).size(withAttributes: [.font: titleFont]).width
        )
        let sublabelWidth = sublabelSize.map {
            Metrics.titleBadgeSpacing + $0.width
        } ?? 0
        let submenuWidth = hasSubmenu ? Metrics.submenuIndicatorWidth : 0
        return min(
            Metrics.maximumWidth,
            max(
                Metrics.minimumWidth,
                Metrics.titleLeading
                    + titleWidth
                    + sublabelWidth
                    + submenuWidth
                    + Metrics.trailing
            )
        )
    }

    func update(
        label: String,
        sublabel: String?,
        sublabelStyle: TrayMenuItemSublabelStyle,
        checked: Bool,
        keepsMenuOpen: Bool,
        hasSubmenu: Bool
    ) {
        self.label = label
        self.sublabel = sublabel
        self.sublabelStyle = sublabelStyle
        self.checked = checked
        self.keepsMenuOpen = keepsMenuOpen
        self.hasSubmenu = hasSubmenu
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    func updateMenuItem(
        label: String?,
        sublabel: String?,
        sublabelStyle: TrayMenuItemSublabelStyle?,
        checked: Bool?
    ) {
        if let label {
            self.label = label
        }
        if let sublabel {
            self.sublabel = sublabel
        }
        if let sublabelStyle {
            self.sublabelStyle = sublabelStyle
        }
        if let checked {
            self.checked = checked
        }
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        pointerInside = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        pointerInside = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard
            let menuItem = enclosingMenuItem,
            menuItem.isEnabled,
            let action = menuItem.action
        else {
            return
        }
        if hasSubmenu {
            return
        }
        if !keepsMenuOpen {
            menuItem.menu?.cancelTracking()
        }
        NSApp.sendAction(action, to: menuItem.target, from: menuItem)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let menuItem = enclosingMenuItem else {
            return
        }
        let highlighted = menuItem.isEnabled
            && (pointerInside || menuItem.isHighlighted)
        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            let highlightRect = bounds.insetBy(
                dx: Metrics.highlightHorizontalInset,
                dy: Metrics.highlightVerticalInset
            )
            NSBezierPath(
                roundedRect: highlightRect,
                xRadius: Metrics.highlightCornerRadius,
                yRadius: Metrics.highlightCornerRadius
            ).fill()
        }
        drawCheckmark(highlighted: highlighted, enabled: menuItem.isEnabled)
        drawTitle(highlighted: highlighted, enabled: menuItem.isEnabled)
        drawSublabel(highlighted: highlighted, enabled: menuItem.isEnabled)
        drawSubmenuIndicator(highlighted: highlighted, enabled: menuItem.isEnabled)
    }

    private var sublabelSize: NSSize? {
        guard let sublabel, !sublabel.isEmpty else {
            return nil
        }
        let font = sublabelStyle == .secondary ? titleFont : badgeFont
        let textSize = (sublabel as NSString).size(
            withAttributes: [.font: font]
        )
        if sublabelStyle == .secondary {
            return NSSize(
                width: ceil(textSize.width),
                height: ceil(textSize.height)
            )
        }
        return NSSize(
            width: ceil(textSize.width) + Metrics.badgeHorizontalPadding * 2,
            height: Metrics.badgeHeight
        )
    }

    private func drawCheckmark(highlighted: Bool, enabled: Bool) {
        guard checked else {
            return
        }
        let color: NSColor
        if !enabled {
            color = .tertiaryLabelColor
        } else if highlighted {
            color = .selectedMenuItemTextColor
        } else {
            color = .labelColor
        }
        let font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let text = "✓" as NSString
        let size = text.size(withAttributes: [.font: font])
        text.draw(
            at: NSPoint(
                x: Metrics.checkmarkLeading,
                y: (bounds.height - size.height) / 2
            ),
            withAttributes: [
                .font: font,
                .foregroundColor: color,
            ]
        )
    }

    private func drawTitle(highlighted: Bool, enabled: Bool) {
        let color: NSColor
        if !enabled {
            color = .tertiaryLabelColor
        } else if highlighted {
            color = .selectedMenuItemTextColor
        } else {
            color = .labelColor
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let textHeight = ceil(
            (label as NSString).size(withAttributes: attributes).height
        )
        let titleTrailing = sublabelFrame.map {
            $0.minX - Metrics.titleBadgeSpacing
        } ?? (
            bounds.width
                - Metrics.trailing
                - (hasSubmenu ? Metrics.submenuIndicatorWidth : 0)
        )
        let titleRect = NSRect(
            x: Metrics.titleLeading,
            y: (bounds.height - textHeight) / 2,
            width: max(0, titleTrailing - Metrics.titleLeading),
            height: textHeight
        )
        (label as NSString).draw(in: titleRect, withAttributes: attributes)
    }

    private var sublabelFrame: NSRect? {
        guard let size = sublabelSize else {
            return nil
        }
        let indicatorWidth = hasSubmenu ? Metrics.submenuIndicatorWidth : 0
        let trailing = Metrics.trailing + indicatorWidth
        let maximumWidth = max(
            0,
            bounds.width
                - Metrics.titleLeading
                - Metrics.minimumTitleWidth
                - Metrics.titleBadgeSpacing
                - trailing
        )
        let width = min(size.width, maximumWidth)
        return NSRect(
            x: bounds.width - trailing - width,
            y: (bounds.height - size.height) / 2,
            width: width,
            height: size.height
        )
    }

    private func drawSublabel(highlighted: Bool, enabled: Bool) {
        guard let sublabel, let frame = sublabelFrame else {
            return
        }
        if sublabelStyle == .secondary {
            let color: NSColor
            if !enabled {
                color = .tertiaryLabelColor
            } else if highlighted {
                color = .selectedMenuItemTextColor
            } else {
                color = .secondaryLabelColor
            }
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right
            paragraphStyle.lineBreakMode = .byTruncatingTail
            (sublabel as NSString).draw(
                in: frame,
                withAttributes: [
                    .font: titleFont,
                    .foregroundColor: color,
                    .paragraphStyle: paragraphStyle,
                ]
            )
            return
        }
        let backgroundColor: NSColor
        let foregroundColor: NSColor
        switch sublabelStyle {
        case .badge:
            backgroundColor = NSColor(
                calibratedRed: 0.20,
                green: 0.80,
                blue: 0.04,
                alpha: enabled ? 1 : 0.45
            )
            foregroundColor = .white
        case .muted:
            backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(
                enabled ? 0.18 : 0.10
            )
            foregroundColor = enabled ? .secondaryLabelColor : .tertiaryLabelColor
        case .destructive:
            backgroundColor = NSColor.systemRed.withAlphaComponent(
                enabled ? 1 : 0.45
            )
            foregroundColor = .white
        case .secondary:
            return
        }
        backgroundColor.setFill()
        NSBezierPath(
            roundedRect: frame,
            xRadius: 4,
            yRadius: 4
        ).fill()
        let text = sublabel as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: foregroundColor,
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(
                x: frame.midX - textSize.width / 2,
                y: frame.midY - textSize.height / 2
            ),
            withAttributes: attributes
        )
    }

    private func drawSubmenuIndicator(highlighted: Bool, enabled: Bool) {
        guard hasSubmenu else {
            return
        }
        let color: NSColor
        if !enabled {
            color = .tertiaryLabelColor
        } else if highlighted {
            color = .selectedMenuItemTextColor
        } else {
            color = .labelColor
        }
        let font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        let text = "›" as NSString
        let size = text.size(withAttributes: [.font: font])
        text.draw(
            at: NSPoint(
                x: bounds.width - Metrics.trailing - size.width,
                y: (bounds.height - size.height) / 2
            ),
            withAttributes: [
                .font: font,
                .foregroundColor: color,
            ]
        )
    }
}

final class TrayMenu: NSMenu {
    private let onSelect: (Int) -> Void

    init(items: [[String: Any]], onSelect: @escaping (Int) -> Void) {
        self.onSelect = onSelect
        super.init(title: "")
        autoenablesItems = false
        var customViews: [TrayMenuItemView] = []
        for entry in items {
            let item = makeItem(entry)
            addItem(item)
            if let view = item.view as? TrayMenuItemView {
                customViews.append(view)
            }
        }
        updateCustomViewWidths(customViews)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func update(items entries: [[String: Any]]) -> Bool {
        guard isCompatible(with: entries) else {
            return false
        }
        apply(entries)
        return true
    }

    @discardableResult
    func updateMenuItem(_ arguments: [String: Any]) -> Bool {
        guard let key = arguments["key"] as? String else {
            return false
        }
        for item in items {
            if item.representedObject as? String == key {
                let label = arguments["label"] as? String
                let sublabel = arguments["sublabel"] as? String
                let style = (arguments["sublabelStyle"] as? String).flatMap(
                    TrayMenuItemSublabelStyle.init(rawValue:)
                )
                let nativeItem = item as? TrayNativeMenuItem
                let checked = nativeItem?.trayType == .checkbox
                    ? arguments["checked"] as? Bool
                    : nil
                if let label {
                    item.title = label
                }
                if let enabled = arguments["enabled"] as? Bool {
                    item.isEnabled = enabled
                    if nativeItem?.trayType != .submenu {
                        item.action = enabled ? #selector(didSelectItem(_:)) : nil
                    }
                }
                if let checked {
                    item.state = checked ? .on : .off
                }
                if let view = item.view as? TrayMenuItemView {
                    view.updateMenuItem(
                        label: label,
                        sublabel: sublabel,
                        sublabelStyle: style,
                        checked: checked
                    )
                } else if let sublabel, !sublabel.isEmpty,
                          let type = nativeItem?.trayType {
                    item.view = TrayMenuItemView(
                        label: item.title,
                        sublabel: sublabel,
                        sublabelStyle: style
                            ?? (type == .submenu ? .secondary : .badge),
                        checked: type == .checkbox && item.state == .on,
                        keepsMenuOpen: false,
                        hasSubmenu: type == .submenu
                    )
                }
                updateCustomViewWidths(
                    items.compactMap { $0.view as? TrayMenuItemView }
                )
                return true
            }
            if let submenu = item.submenu as? TrayMenu,
               submenu.updateMenuItem(arguments) {
                return true
            }
        }
        return false
    }

    private func makeItem(_ entry: [String: Any]) -> NSMenuItem {
        guard let typeName = entry["type"] as? String,
              let type = TrayMenuItemType(rawValue: typeName) else {
            return NSMenuItem.separator()
        }
        if type == .separator {
            return NSMenuItem.separator()
        }
        let item = TrayNativeMenuItem(type: type)
        item.title = entry["label"] as? String ?? ""
        item.tag = entry["id"] as? Int ?? 0
        item.representedObject = entry["key"] as? String
        item.isEnabled = entry["enabled"] as? Bool ?? true
        applyKeyboardShortcut(entry, to: item)
        switch type {
        case .checkbox:
            item.state = (entry["checked"] as? Bool ?? false) ? .on : .off
            item.target = self
            item.action = item.isEnabled ? #selector(didSelectItem(_:)) : nil
        case .submenu:
            let children = entry["items"] as? [[String: Any]] ?? []
            setSubmenu(TrayMenu(items: children, onSelect: onSelect), for: item)
        case .action:
            item.target = self
            item.action = item.isEnabled ? #selector(didSelectItem(_:)) : nil
        case .separator:
            break
        }
        let sublabel = entry["sublabel"] as? String
        let keepsMenuOpen = entry["keepsMenuOpen"] as? Bool ?? false
        let usesCustomView = entry["usesCustomView"] as? Bool ?? false
        if usesCustomView || sublabel?.isEmpty == false || keepsMenuOpen {
            let styleName = entry["sublabelStyle"] as? String ?? "badge"
            item.view = TrayMenuItemView(
                label: item.title,
                sublabel: sublabel,
                sublabelStyle: TrayMenuItemSublabelStyle(
                    rawValue: styleName
                ) ?? .badge,
                checked: item.state == .on,
                keepsMenuOpen: keepsMenuOpen,
                hasSubmenu: type == .submenu
            )
        }
        return item
    }

    private func isCompatible(with entries: [[String: Any]]) -> Bool {
        guard entries.count == items.count else {
            return false
        }
        for (entry, item) in zip(entries, items) {
            guard let typeName = entry["type"] as? String,
                  let type = TrayMenuItemType(rawValue: typeName) else {
                return false
            }
            if type == .separator {
                guard item.isSeparatorItem else {
                    return false
                }
                continue
            }
            guard let nativeItem = item as? TrayNativeMenuItem,
                  nativeItem.trayType == type,
                  !item.isSeparatorItem else {
                return false
            }
            if type == .submenu {
                guard let children = entry["items"] as? [[String: Any]],
                      let submenu = item.submenu as? TrayMenu,
                      submenu.isCompatible(with: children) else {
                    return false
                }
            } else if item.submenu != nil {
                return false
            }
        }
        return true
    }

    private func apply(_ entries: [[String: Any]]) {
        var customViews: [TrayMenuItemView] = []
        for (entry, item) in zip(entries, items) {
            guard let typeName = entry["type"] as? String,
                  let type = TrayMenuItemType(rawValue: typeName),
                  type != .separator else {
                continue
            }
            let label = entry["label"] as? String ?? ""
            let sublabel = entry["sublabel"] as? String
            let styleName = entry["sublabelStyle"] as? String ?? "badge"
            let style = TrayMenuItemSublabelStyle(rawValue: styleName) ?? .badge
            let checked = entry["checked"] as? Bool ?? false
            let keepsMenuOpen = entry["keepsMenuOpen"] as? Bool ?? false
            let usesCustomView = entry["usesCustomView"] as? Bool ?? false

            item.title = label
            item.tag = entry["id"] as? Int ?? 0
            item.representedObject = entry["key"] as? String
            item.isEnabled = entry["enabled"] as? Bool ?? true
            item.target = type == .submenu ? nil : self
            item.action = type != .submenu && item.isEnabled
                ? #selector(didSelectItem(_:))
                : nil
            item.state = type == .checkbox && checked ? .on : .off
            applyKeyboardShortcut(entry, to: item)

            if type == .submenu,
               let children = entry["items"] as? [[String: Any]],
               let submenu = item.submenu as? TrayMenu {
                submenu.apply(children)
            }

            if usesCustomView || sublabel?.isEmpty == false || keepsMenuOpen {
                let view: TrayMenuItemView
                if let currentView = item.view as? TrayMenuItemView {
                    view = currentView
                    view.update(
                        label: label,
                        sublabel: sublabel,
                        sublabelStyle: style,
                        checked: checked,
                        keepsMenuOpen: keepsMenuOpen,
                        hasSubmenu: type == .submenu
                    )
                } else {
                    view = TrayMenuItemView(
                        label: label,
                        sublabel: sublabel,
                        sublabelStyle: style,
                        checked: checked,
                        keepsMenuOpen: keepsMenuOpen,
                        hasSubmenu: type == .submenu
                    )
                    item.view = view
                }
                customViews.append(view)
            } else {
                item.view = nil
            }
        }
        updateCustomViewWidths(customViews)
    }

    private func applyKeyboardShortcut(
        _ entry: [String: Any],
        to item: NSMenuItem
    ) {
        item.keyEquivalent = ""
        item.keyEquivalentModifierMask = []
        guard let keyEquivalent = entry["keyEquivalent"] as? String else {
            return
        }
        item.keyEquivalent = keyEquivalent
        var result: NSEvent.ModifierFlags = []
        let modifiers = entry["keyEquivalentModifiers"] as? [String] ?? []
        for modifier in modifiers {
            switch modifier {
            case "option":
                result.insert(.option)
            case "capsLock":
                result.insert(.capsLock)
            case "control":
                result.insert(.control)
            case "function":
                result.insert(.function)
            case "command":
                result.insert(.command)
            case "shift":
                result.insert(.shift)
            default:
                break
            }
        }
        item.keyEquivalentModifierMask = result
    }

    private func updateCustomViewWidths(_ customViews: [TrayMenuItemView]) {
        let width = customViews.map(\.preferredWidth).max() ?? 0
        for view in customViews {
            view.frame.size.width = width
            view.needsDisplay = true
        }
    }

    @objc private func didSelectItem(_ sender: NSMenuItem) {
        onSelect(sender.tag)
    }
}

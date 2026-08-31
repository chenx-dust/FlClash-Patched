import AppKit

final class TrayMenu: NSMenu {
    private let onSelect: (Int, Bool) -> Void

    init(items: [[String: Any]], onSelect: @escaping (Int, Bool) -> Void) {
        self.onSelect = onSelect
        super.init(title: "")
        autoenablesItems = false
        for entry in items {
            addItem(makeItem(entry))
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeItem(_ entry: [String: Any]) -> NSMenuItem {
        let type = entry["type"] as? String ?? ""
        if type == "separator" {
            return NSMenuItem.separator()
        }

        let item = NSMenuItem()
        item.title = entry["label"] as? String ?? ""
        item.tag = entry["id"] as? Int ?? 0
        item.isEnabled = entry["enabled"] as? Bool ?? true
        item.keyEquivalent = entry["keyEquivalent"] as? String ?? ""
        item.keyEquivalentModifierMask = modifierMask(
            entry["keyEquivalentModifiers"] as? [String] ?? []
        )
        applySublabel(entry, to: item)

        switch type {
        case "checkbox":
            item.state = (entry["checked"] as? Bool ?? false) ? .on : .off
            item.target = self
            item.action = #selector(didSelectItem(_:))
        case "submenu":
            let children = entry["items"] as? [[String: Any]] ?? []
            setSubmenu(TrayMenu(items: children, onSelect: onSelect), for: item)
        default:
            item.target = self
            item.action = #selector(didSelectItem(_:))
        }

        return item
    }

    @objc private func didSelectItem(_ sender: NSMenuItem) {
        onSelect(sender.tag, representedKeepsMenuOpen(sender))
    }

    private func applySublabel(_ entry: [String: Any], to item: NSMenuItem) {
        guard let sublabel = entry["sublabel"] as? String, !sublabel.isEmpty else {
            item.representedObject = entry["keepsMenuOpen"] as? Bool ?? false
            return
        }
        let style = entry["sublabelStyle"] as? String ?? "badge"
        let title = entry["label"] as? String ?? ""
        let attributed = NSMutableAttributedString(string: title)
        let suffix = NSAttributedString(
            string: "  \(sublabel)",
            attributes: [.foregroundColor: sublabelColor(style)]
        )
        attributed.append(suffix)
        item.attributedTitle = attributed
        item.representedObject = entry["keepsMenuOpen"] as? Bool ?? false
    }

    private func representedKeepsMenuOpen(_ item: NSMenuItem) -> Bool {
        item.representedObject as? Bool ?? false
    }

    private func sublabelColor(_ style: String) -> NSColor {
        switch style {
        case "destructive":
            return .systemRed
        case "muted", "secondary":
            return .secondaryLabelColor
        default:
            return .controlAccentColor
        }
    }

    private func modifierMask(_ names: [String]) -> NSEvent.ModifierFlags {
        names.reduce(into: NSEvent.ModifierFlags()) { result, name in
            switch name {
            case "option": result.insert(.option)
            case "capsLock": result.insert(.capsLock)
            case "control": result.insert(.control)
            case "function": result.insert(.function)
            case "command": result.insert(.command)
            case "shift": result.insert(.shift)
            default: break
            }
        }
    }
}

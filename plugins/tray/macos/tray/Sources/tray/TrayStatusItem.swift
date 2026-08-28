import AppKit

final class TrayStatusItem {
    let statusItem: NSStatusItem

    private let contentView: TrayContentView

    init?(onActivate: @escaping () -> Void, onMenuRequested: @escaping () -> Void) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "\(Bundle.main.bundleIdentifier ?? "tray").statusItem"
        contentView = TrayContentView(
            onActivate: onActivate,
            onMenuRequested: onMenuRequested
        )

        guard let button = statusItem.button else {
            NSStatusBar.system.removeStatusItem(statusItem)
            return nil
        }
        button.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: button.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            contentView.heightAnchor.constraint(equalToConstant: NSStatusBar.system.thickness),
        ])
    }

    func setImage(_ image: NSImage, position: String) {
        if contentView.setImage(image, position: position) {
            statusItem.button?.sizeToFit()
        }
    }

    func setTitle(_ title: String) {
        if contentView.setTitle(title) {
            statusItem.button?.sizeToFit()
        }
    }

    func setToolTip(_ toolTip: String) {
        statusItem.button?.toolTip = toolTip
    }

    func openMenu(_ menu: NSMenu) {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func closeMenu() {
        statusItem.menu = nil
    }

    func remove() {
        statusItem.menu = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}

private final class TrayContentView: NSView {
    private let onActivate: () -> Void
    private let onMenuRequested: () -> Void

    private let imageView: NSImageView = {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyDown
        view.isHidden = true
        view.setContentHuggingPriority(.required, for: .horizontal)
        return view
    }()

    private let titleView = TrayTitleView()

    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.distribution = .equalSpacing
        return stack
    }()

    private var stackLeadingConstraint: NSLayoutConstraint!
    private var stackTrailingConstraint: NSLayoutConstraint!
    private var stackTopConstraint: NSLayoutConstraint!
    private var stackBottomConstraint: NSLayoutConstraint!

    init(onActivate: @escaping () -> Void, onMenuRequested: @escaping () -> Void) {
        self.onActivate = onActivate
        self.onMenuRequested = onMenuRequested
        super.init(frame: .zero)

        titleView.isHidden = true
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackLeadingConstraint = stackView.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: 6
        )
        stackTrailingConstraint = stackView.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -6
        )
        stackTopConstraint = stackView.topAnchor.constraint(
            equalTo: topAnchor
        )
        stackBottomConstraint = stackView.bottomAnchor.constraint(
            equalTo: bottomAnchor
        )
        NSLayoutConstraint.activate([
            stackLeadingConstraint,
            stackTrailingConstraint,
            stackTopConstraint,
            stackBottomConstraint,
        ])

        applyPosition("leading")
        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.setContentHuggingPriority(.required, for: .horizontal)
        titleView.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            titleView.widthAnchor.constraint(
                greaterThanOrEqualToConstant: TrayTitleView.width
            ),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: NSImage, position: String) -> Bool {
        let wasHidden = imageView.isHidden
        let previousSize = imageView.image?.size ?? .zero
        let sizeChanged = previousSize != image.size
        imageView.image = image
        imageView.isHidden = false
        applyPosition(position)
        return wasHidden != imageView.isHidden || sizeChanged
    }

    func setTitle(_ title: String) -> Bool {
        let changed = titleView.setTitle(title)
        updateInsets(hasTitle: !title.isEmpty)
        return changed
    }

    private func updateInsets(hasTitle: Bool) {
        stackLeadingConstraint.constant = hasTitle ? 4 : 6
        stackTrailingConstraint.constant = hasTitle ? -8 : -6
    }

    private func applyPosition(_ position: String) {
        let views: [NSView] = position == "trailing"
            ? [titleView, imageView]
            : [imageView, titleView]

        if stackView.arrangedSubviews == views {
            return
        }

        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
        }
        for (index, view) in views.enumerated() {
            stackView.insertArrangedSubview(view, at: index)
        }
    }

    override func mouseDown(with event: NSEvent) {
        (superview as? NSButton)?.highlight(true)
        onActivate()
    }

    override func mouseUp(with event: NSEvent) {
        (superview as? NSButton)?.highlight(false)
    }

    override func rightMouseDown(with event: NSEvent) {
        onMenuRequested()
    }
}

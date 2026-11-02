import AppKit

protocol MenuBarViewDelegate: AnyObject {
    func menuBarViewDidTriggerExpand(_ view: MenuBarView)
    func menuBarViewDidTriggerExit(_ view: MenuBarView)
    func menuBarViewDidClickToggle(_ view: MenuBarView)
    func menuBarViewDidRequestQuit(_ view: MenuBarView)
}

final class MenuBarView: NSView {
    weak var delegate: MenuBarViewDelegate?

    private var trackingAreaRef: NSTrackingArea?
    private(set) var isHighlighted: Bool = false

    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "satset")
    private let pillLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 68, height: 22))
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true

        pillLayer.cornerRadius = 5
        pillLayer.masksToBounds = true
        pillLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(pillLayer)

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let icon = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "mini-satset")?
            .withSymbolConfiguration(symbolConfig)
        iconImageView.image = icon
        iconImageView.contentTintColor = .labelColor
        iconImageView.frame = NSRect(x: 6, y: 4, width: 14, height: 14)
        addSubview(iconImageView)

        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.alphaValue = 1.0
        titleLabel.frame = NSRect(x: 23, y: 3, width: 40, height: 16)
        addSubview(titleLabel)
    }

    override func layout() {
        super.layout()
        pillLayer.frame = bounds.insetBy(dx: 2, dy: 1)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    // MARK: - Mouse Events (Instant Response)

    override func mouseEntered(with event: NSEvent) {
        setHighlight(true, animated: true)
        delegate?.menuBarViewDidTriggerExpand(self)
    }

    override func mouseExited(with event: NSEvent) {
        delegate?.menuBarViewDidTriggerExit(self)
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.menuBarViewDidClickToggle(self)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu(title: "mini-satset")
        let titleItem = NSMenuItem(title: "mini-satset v1.0.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Keluar / Quit",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func handleQuit() {
        delegate?.menuBarViewDidRequestQuit(self)
    }

    // MARK: - Highlighting

    func setHighlight(_ highlight: Bool, animated: Bool = true) {
        guard isHighlighted != highlight else { return }
        isHighlighted = highlight

        let targetColor = highlight ? NSColor.quaternaryLabelColor.cgColor : NSColor.clear.cgColor

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.pillLayer.backgroundColor = targetColor
            }
        } else {
            pillLayer.backgroundColor = targetColor
        }
    }
}

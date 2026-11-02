import AppKit

protocol PageIndicatorViewDelegate: AnyObject {
    func pageIndicator(_ indicator: PageIndicatorView, didSelectPageAt index: Int)
}

final class PageIndicatorView: NSView {
    weak var delegate: PageIndicatorViewDelegate?

    private var tabButtons: [NSButton] = []
    private let selectionIndicator = CALayer()
    private(set) var selectedIndex: Int = 0

    private let symbols = ["doc.on.clipboard", "arrow.2.squarepath", "eyedropper.halffull"]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTabs()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTabs() {
        wantsLayer = true

        selectionIndicator.cornerRadius = 6
        selectionIndicator.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        layer?.addSublayer(selectionIndicator)

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)

        for (index, symbol) in symbols.enumerated() {
            let button = NSButton()
            button.isBordered = false
            button.setButtonType(.momentaryChange)
            button.imagePosition = .imageOnly

            let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            button.image = img
            button.contentTintColor = (index == 0) ? .labelColor : .secondaryLabelColor
            button.tag = index
            button.target = self
            button.action = #selector(handleTabClick(_:))

            addSubview(button)
            tabButtons.append(button)
        }
    }

    override func layout() {
        super.layout()
        let buttonWidth: CGFloat = 36
        let buttonHeight: CGFloat = 28
        let spacing: CGFloat = 8
        let totalWidth = CGFloat(tabButtons.count) * buttonWidth + CGFloat(tabButtons.count - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2

        for (index, button) in tabButtons.enumerated() {
            let x = startX + CGFloat(index) * (buttonWidth + spacing)
            button.frame = NSRect(x: x, y: (bounds.height - buttonHeight) / 2, width: buttonWidth, height: buttonHeight)
        }

        updateIndicatorPosition(animated: false)
    }

    @objc private func handleTabClick(_ sender: NSButton) {
        selectTab(at: sender.tag, notify: true)
    }

    func selectTab(at index: Int, notify: Bool) {
        guard index >= 0 && index < tabButtons.count else { return }
        selectedIndex = index

        for (i, button) in tabButtons.enumerated() {
            button.contentTintColor = (i == index) ? .labelColor : .secondaryLabelColor
        }

        updateIndicatorPosition(animated: true)

        if notify {
            delegate?.pageIndicator(self, didSelectPageAt: index)
        }
    }

    private func updateIndicatorPosition(animated: Bool) {
        guard selectedIndex < tabButtons.count else { return }
        let targetFrame = tabButtons[selectedIndex].frame

        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.18)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            selectionIndicator.frame = targetFrame
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            selectionIndicator.frame = targetFrame
            CATransaction.commit()
        }
    }
}

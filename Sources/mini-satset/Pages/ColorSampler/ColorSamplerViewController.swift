import AppKit

final class ColorSamplerViewController: NSViewController {
    var isSamplingColor: Bool = false
    private var recentColors: [(color: NSColor, hex: String)] = []

    private let previewSwatch = NSView()
    private let hexLabel = NSTextField(labelWithString: "#------")
    private let rgbLabel = NSTextField(labelWithString: "rgb(-, -, -)")
    private let hslLabel = NSTextField(labelWithString: "hsl(-, -%, -%)")
    private let defaultToastText = "Click button to sample screen color"
    private lazy var toastLabel = NSTextField(labelWithString: defaultToastText)
    private let recentContainer = NSView()
    private var toastTimer: Timer?

    deinit {
        toastTimer?.invalidate()
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 290))
        setupUI()
    }

    private func setupUI() {
        // Sample Button (Top: 296 x 28, 12pt from top edge)
        let pickBtn = NSButton(frame: NSRect(x: 12, y: 250, width: 296, height: 28))
        pickBtn.title = " Pick Screen Color (Loupe)"
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        pickBtn.image = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        pickBtn.wantsLayer = true
        pickBtn.isBordered = false
        pickBtn.layer?.cornerRadius = 8
        pickBtn.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        pickBtn.contentTintColor = .white
        pickBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        pickBtn.target = self
        pickBtn.action = #selector(handlePickColor)
        view.addSubview(pickBtn)

        // Preview Card (Middle: 296 x 150, 8pt gap, radius 8)
        let card = NSView(frame: NSRect(x: 12, y: 92, width: 296, height: 150))
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        view.addSubview(card)

        previewSwatch.frame = NSRect(x: 14, y: 70, width: 64, height: 64)
        previewSwatch.wantsLayer = true
        previewSwatch.layer?.cornerRadius = 8
        previewSwatch.layer?.borderWidth = 1
        previewSwatch.layer?.borderColor = NSColor.separatorColor.cgColor
        previewSwatch.layer?.backgroundColor = NSColor.darkGray.cgColor
        card.addSubview(previewSwatch)

        // Labels Container
        hexLabel.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        hexLabel.textColor = .labelColor
        hexLabel.frame = NSRect(x: 90, y: 110, width: 192, height: 22)
        card.addSubview(hexLabel)

        rgbLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        rgbLabel.textColor = .secondaryLabelColor
        rgbLabel.frame = NSRect(x: 90, y: 90, width: 192, height: 16)
        card.addSubview(rgbLabel)

        hslLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        hslLabel.textColor = .secondaryLabelColor
        hslLabel.frame = NSRect(x: 90, y: 70, width: 192, height: 16)
        card.addSubview(hslLabel)

        // Symmetrical Clickable Copy Buttons (84 x 26 each, 8pt gap)
        let copyHexBtn = makeMiniCopyButton(title: "Copy HEX", action: #selector(handleCopyHex))
        copyHexBtn.frame = NSRect(x: 14, y: 14, width: 84, height: 26)
        card.addSubview(copyHexBtn)

        let copyRgbBtn = makeMiniCopyButton(title: "Copy RGB", action: #selector(handleCopyRgb))
        copyRgbBtn.frame = NSRect(x: 106, y: 14, width: 84, height: 26)
        card.addSubview(copyRgbBtn)

        let copyHslBtn = makeMiniCopyButton(title: "Copy HSL", action: #selector(handleCopyHsl))
        copyHslBtn.frame = NSRect(x: 198, y: 14, width: 84, height: 26)
        card.addSubview(copyHslBtn)

        // Recent Colors Section (y=60, h=24)
        let recentTitle = NSTextField(labelWithString: "Recent:")
        recentTitle.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        recentTitle.textColor = .tertiaryLabelColor
        recentTitle.frame = NSRect(x: 12, y: 64, width: 48, height: 16)
        view.addSubview(recentTitle)

        recentContainer.frame = NSRect(x: 64, y: 62, width: 244, height: 20)
        view.addSubview(recentContainer)

        // Toast feedback (12pt from bottom edge)
        toastLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        toastLabel.textColor = .secondaryLabelColor
        toastLabel.alignment = .center
        toastLabel.frame = NSRect(x: 12, y: 12, width: 296, height: 18)
        view.addSubview(toastLabel)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        NSCursor.unhide()
    }

    private func makeMiniCopyButton(title: String, action: Selector) -> NSButton {
        let btn = NSButton()
        btn.title = title
        btn.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        btn.wantsLayer = true
        btn.isBordered = false
        btn.layer?.cornerRadius = 6
        btn.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        btn.contentTintColor = .labelColor
        btn.target = self
        btn.action = action
        return btn
    }

    @objc private func handlePickColor() {
        isSamplingColor = true
        let sampler = NSColorSampler()
        sampler.show { [weak self] selectedColor in
            guard let self = self else { return }
            self.isSamplingColor = false
            if let color = selectedColor {
                self.applyColor(color)
            }
        }
    }

    private func applyColor(_ color: NSColor) {
        let formats = ColorFormatHelper.formats(from: color)

        previewSwatch.layer?.backgroundColor = color.cgColor
        hexLabel.stringValue = formats.hex
        rgbLabel.stringValue = formats.rgb
        hslLabel.stringValue = formats.hsl

        // Auto copy HEX to pasteboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formats.hex, forType: .string)
        showToast("Auto-copied \(formats.hex) to clipboard!")

        // Update recents
        if !recentColors.contains(where: { $0.hex == formats.hex }) {
            recentColors.insert((color: color, hex: formats.hex), at: 0)
            if recentColors.count > 5 {
                recentColors.removeLast()
            }
            refreshRecentSwatches()
        }
    }

    private func refreshRecentSwatches() {
        recentContainer.subviews.forEach { $0.removeFromSuperview() }
        let size: CGFloat = 18
        let spacing: CGFloat = 6

        for (index, item) in recentColors.enumerated() {
            let swatch = NSButton()
            swatch.title = ""
            swatch.isBordered = false
            swatch.wantsLayer = true
            swatch.layer?.cornerRadius = 4
            swatch.layer?.backgroundColor = item.color.cgColor
            swatch.layer?.borderWidth = 1
            swatch.layer?.borderColor = NSColor.separatorColor.cgColor
            swatch.target = self
            swatch.action = #selector(handleRecentClick(_:))
            swatch.identifier = NSUserInterfaceItemIdentifier(item.hex)

            let x = CGFloat(index) * (size + spacing)
            swatch.frame = NSRect(x: x, y: 1, width: size, height: size)
            recentContainer.addSubview(swatch)
        }
    }

    @objc private func handleRecentClick(_ sender: NSButton) {
        guard let hex = sender.identifier?.rawValue,
              let matched = recentColors.first(where: { $0.hex == hex })?.color else { return }
        applyColor(matched)
    }

    @objc private func handleCopyHex() {
        guard hexLabel.stringValue != "#------" else { return }
        copyText(hexLabel.stringValue, message: "HEX copied!")
    }

    @objc private func handleCopyRgb() {
        guard rgbLabel.stringValue != "rgb(-, -, -)" else { return }
        copyText(rgbLabel.stringValue, message: "RGB copied!")
    }

    @objc private func handleCopyHsl() {
        guard hslLabel.stringValue != "hsl(-, -%, -%)" else { return }
        copyText(hslLabel.stringValue, message: "HSL copied!")
    }

    private func copyText(_ text: String, message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast(message)
    }

    private func showToast(_ message: String) {
        toastTimer?.invalidate()
        toastLabel.stringValue = message
        toastLabel.textColor = .controlAccentColor

        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.toastLabel.stringValue = self.defaultToastText
            self.toastLabel.textColor = .secondaryLabelColor
        }
    }
}

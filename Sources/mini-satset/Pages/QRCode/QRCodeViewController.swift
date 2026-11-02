import AppKit

// MARK: - Dedicated Input Field for QR Code Page

final class QRCodeInputField: NSTextField {
    var onTextChange: ((String) -> Void)?

    override func becomeFirstResponder() -> Bool {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKey()
        NSCursor.unhide()
        return super.becomeFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKey()
        NSCursor.unhide()
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            let key = event.charactersIgnoringModifiers?.lowercased()
            if key == "v" {
                if let str = NSPasteboard.general.string(forType: .string) {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        if let editor = currentEditor() as? NSTextView {
                            editor.string = trimmed
                        } else {
                            stringValue = trimmed
                        }
                        onTextChange?(trimmed)
                        NSCursor.unhide()
                        return true
                    }
                }
            } else if key == "a" {
                currentEditor()?.selectAll(nil)
                return true
            } else if key == "c" {
                if let editor = currentEditor() as? NSTextView {
                    editor.copy(nil)
                    return true
                }
            } else if key == "x" {
                if let editor = currentEditor() as? NSTextView {
                    editor.cut(nil)
                    onTextChange?(editor.string)
                    return true
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        onTextChange?(stringValue)
    }
}

// MARK: - QR Display & Drag/Drop Card View

final class QRCodeCardView: NSView, NSDraggingSource {
    var onFileDropped: ((URL) -> Void)?
    var currentImage: NSImage?

    private let emptyContainer = NSView()
    private let activeContainer = NSView()
    private let qrImageView = NSImageView()
    private let dashedBorder = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        registerForDraggedTypes([.fileURL])

        dashedBorder.strokeColor = NSColor.separatorColor.cgColor
        dashedBorder.fillColor = nil
        dashedBorder.lineDashPattern = [4, 4]
        dashedBorder.lineWidth = 1.0
        layer?.addSublayer(dashedBorder)

        setupEmptyState()
        setupActiveState()
        showEmpty(true)
    }

    override func layout() {
        super.layout()
        let path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: 10, cornerHeight: 10, transform: nil)
        dashedBorder.path = path
        dashedBorder.frame = bounds
        emptyContainer.frame = bounds
        activeContainer.frame = bounds
    }

    private func setupEmptyState() {
        emptyContainer.wantsLayer = true
        addSubview(emptyContainer)

        let icon = NSImageView()
        let config = NSImage.SymbolConfiguration(pointSize: 34, weight: .light)
        icon.image = NSImage(systemSymbolName: "qrcode", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        icon.contentTintColor = .tertiaryLabelColor
        icon.frame = NSRect(x: (296 - 44) / 2, y: 110, width: 44, height: 44)
        emptyContainer.addSubview(icon)

        let title = NSTextField(labelWithString: "No QR Code")
        title.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        title.textColor = .secondaryLabelColor
        title.alignment = .center
        title.frame = NSRect(x: 12, y: 84, width: 272, height: 18)
        emptyContainer.addSubview(title)

        let sub = NSTextField(labelWithString: "Type text above or drop QR image to scan")
        sub.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        sub.textColor = .tertiaryLabelColor
        sub.alignment = .center
        sub.frame = NSRect(x: 12, y: 64, width: 272, height: 16)
        emptyContainer.addSubview(sub)
    }

    private func setupActiveState() {
        activeContainer.wantsLayer = true
        addSubview(activeContainer)

        // White card background for crisp QR scanning
        let whiteCard = NSView(frame: NSRect(x: (296 - 130) / 2, y: 52, width: 130, height: 130))
        whiteCard.wantsLayer = true
        whiteCard.layer?.cornerRadius = 8
        whiteCard.layer?.backgroundColor = NSColor.white.cgColor
        whiteCard.layer?.borderWidth = 0.5
        whiteCard.layer?.borderColor = NSColor.separatorColor.cgColor
        activeContainer.addSubview(whiteCard)

        qrImageView.frame = whiteCard.bounds.insetBy(dx: 4, dy: 4)
        qrImageView.imageScaling = .scaleAxesIndependently
        whiteCard.addSubview(qrImageView)
    }

    func showEmpty(_ empty: Bool) {
        emptyContainer.isHidden = !empty
        activeContainer.isHidden = empty
        dashedBorder.isHidden = !empty
    }

    func displayQRCode(_ image: NSImage) {
        self.currentImage = image
        self.qrImageView.image = image
        showEmpty(false)
    }

    // Drag Out to Finder / External Apps (Lazy Export on actual drag gesture)
    override func mouseDragged(with event: NSEvent) {
        guard let image = currentImage, !activeContainer.isHidden else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("mini-satset-qr.png")

        let wroteSuccessfully = autoreleasepool { () -> Bool in
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { return false }
            do {
                try png.write(to: tempURL)
                return true
            } catch {
                return false
            }
        }
        guard wroteSuccessfully else { return }

        let dragItem = NSDraggingItem(pasteboardWriter: tempURL as NSURL)
        let dragIcon = NSImage(size: NSSize(width: 48, height: 48), flipped: false) { rect in
            image.draw(in: rect)
            return true
        }
        dragItem.setDraggingFrame(NSRect(origin: event.locationInWindow, size: dragIcon.size), contents: dragIcon)
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    // Drag In (Drop image to scan)
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dashedBorder.strokeColor = NSColor.controlAccentColor.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dashedBorder.strokeColor = NSColor.separatorColor.cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dashedBorder.strokeColor = NSColor.separatorColor.cgColor
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let first = urls.first else { return false }
        onFileDropped?(first)
        return true
    }
}

// MARK: - QR Code View Controller

final class QRCodeViewController: NSViewController, NSTextFieldDelegate {
    private let engine = QRCodeEngine.shared

    private let inputField = QRCodeInputField()
    private let pasteBtn = NSButton()
    private let clearBtn = NSButton()
    private let cardView = QRCodeCardView()

    private let copyImageBtn = NSButton()
    private let copyTextBtn = NSButton()
    private let defaultFooterText = "Drop image to scan • Drag QR to export"
    private lazy var toastLabel = NSTextField(labelWithString: defaultFooterText)

    private var toastResetTimer: Timer?
    private var currentQRImage: NSImage?
    private var lastGeneratedText: String = ""

    deinit {
        toastResetTimer?.invalidate()
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 290))
        setupUI()
    }

    private func setupUI() {
        // Top Input Field Row (296 wide, 12pt from top edge: y=252, h=26)
        inputField.frame = NSRect(x: 12, y: 252, width: 220, height: 26)
        inputField.placeholderString = "Type URL or text..."
        inputField.font = NSFont.systemFont(ofSize: 12)
        inputField.isBezeled = true
        inputField.bezelStyle = .roundedBezel
        inputField.focusRingType = .none
        inputField.delegate = self
        inputField.onTextChange = { [weak self] text in
            self?.generateQR(from: text)
        }
        view.addSubview(inputField)

        // Symmetrical Quick Paste Button (32 x 26)
        pasteBtn.frame = NSRect(x: 238, y: 252, width: 32, height: 26)
        pasteBtn.title = ""
        pasteBtn.toolTip = "Paste text from clipboard"
        pasteBtn.isBordered = false
        pasteBtn.wantsLayer = true
        pasteBtn.layer?.cornerRadius = 6
        pasteBtn.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        let pasteImg = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        pasteBtn.image = pasteImg
        pasteBtn.contentTintColor = .labelColor
        pasteBtn.target = self
        pasteBtn.action = #selector(handlePaste)
        view.addSubview(pasteBtn)

        // Symmetrical Clear Button (32 x 26)
        clearBtn.frame = NSRect(x: 276, y: 252, width: 32, height: 26)
        clearBtn.title = ""
        clearBtn.toolTip = "Clear text"
        clearBtn.isBordered = false
        clearBtn.wantsLayer = true
        clearBtn.layer?.cornerRadius = 6
        clearBtn.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        let clearImg = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Clear")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        clearBtn.image = clearImg
        clearBtn.contentTintColor = .labelColor
        clearBtn.target = self
        clearBtn.action = #selector(handleClear)
        view.addSubview(clearBtn)

        // Center Card & Drop Zone (296 x 198, y=44)
        cardView.frame = NSRect(x: 12, y: 44, width: 296, height: 198)
        cardView.onFileDropped = { [weak self] url in
            self?.readQR(from: url)
        }
        view.addSubview(cardView)

        // Symmetrical Action Buttons inside Card (y=12, h=26, w=128 each)
        copyImageBtn.frame = NSRect(x: 14, y: 12, width: 128, height: 26)
        copyImageBtn.title = " Copy Image"
        copyImageBtn.toolTip = "Copy QR code image to clipboard"
        let imgConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        copyImageBtn.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: nil)?
            .withSymbolConfiguration(imgConfig)
        copyImageBtn.isBordered = false
        copyImageBtn.wantsLayer = true
        copyImageBtn.layer?.cornerRadius = 6
        copyImageBtn.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        copyImageBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        copyImageBtn.contentTintColor = .labelColor
        copyImageBtn.target = self
        copyImageBtn.action = #selector(handleCopyImage)
        copyImageBtn.isHidden = true
        cardView.addSubview(copyImageBtn)

        copyTextBtn.frame = NSRect(x: 154, y: 12, width: 128, height: 26)
        copyTextBtn.title = " Copy Text"
        copyTextBtn.toolTip = "Copy raw text to clipboard"
        copyTextBtn.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)?
            .withSymbolConfiguration(imgConfig)
        copyTextBtn.isBordered = false
        copyTextBtn.wantsLayer = true
        copyTextBtn.layer?.cornerRadius = 6
        copyTextBtn.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        copyTextBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        copyTextBtn.contentTintColor = .labelColor
        copyTextBtn.target = self
        copyTextBtn.action = #selector(handleCopyText)
        copyTextBtn.isHidden = true
        cardView.addSubview(copyTextBtn)

        // Bottom Toast Label (12pt from bottom edge: y=14, h=18)
        toastLabel.frame = NSRect(x: 12, y: 14, width: 296, height: 18)
        toastLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        toastLabel.textColor = .secondaryLabelColor
        toastLabel.alignment = .center
        view.addSubview(toastLabel)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        NSCursor.unhide()
    }

    // MARK: - QR Generation

    private func generateQR(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != lastGeneratedText else { return }
        lastGeneratedText = trimmed

        guard !trimmed.isEmpty else {
            currentQRImage = nil
            cardView.showEmpty(true)
            copyImageBtn.isHidden = true
            copyTextBtn.isHidden = true
            return
        }

        if let qrImage = engine.generateQRCode(from: trimmed, size: 240) {
            currentQRImage = qrImage
            cardView.displayQRCode(qrImage)
            copyImageBtn.isHidden = false
            copyTextBtn.isHidden = false
        }
    }

    // MARK: - QR Decoding

    func readQR(from url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        if let decoded = engine.detectQRCode(from: url) {
            inputField.stringValue = decoded
            inputField.currentEditor()?.string = decoded
            generateQR(from: decoded)

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(decoded, forType: .string)

            showToast("QR decoded & copied to clipboard!")
        } else {
            showToast("No QR code detected in image")
        }
    }

    // MARK: - Actions

    @objc private func handlePaste() {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        view.window?.makeKey()

        if let str = NSPasteboard.general.string(forType: .string) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                inputField.stringValue = trimmed
                inputField.currentEditor()?.string = trimmed
                generateQR(from: trimmed)
                showToast("Pasted to QR!")
                return
            }
        }
        showToast("Clipboard is empty")
    }

    @objc private func handleClear() {
        inputField.stringValue = ""
        inputField.currentEditor()?.string = ""
        generateQR(from: "")
        showToast("Cleared")
    }

    @objc private func handleCopyImage() {
        guard let qr = currentQRImage else { return }
        autoreleasepool {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([qr])
            if let tiff = qr.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                NSPasteboard.general.setData(png, forType: .png)
            }
        }
        showToast("QR image copied to clipboard!")
    }

    @objc private func handleCopyText() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast("Text copied to clipboard!")
    }

    private func showToast(_ msg: String) {
        toastResetTimer?.invalidate()
        toastLabel.stringValue = msg
        toastLabel.textColor = .controlAccentColor

        toastResetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.toastLabel.stringValue = self.defaultFooterText
            self.toastLabel.textColor = .secondaryLabelColor
        }
    }
}

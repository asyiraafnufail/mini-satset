import AppKit

// MARK: - Custom Input Field (Explicit Key Window & Keyboard Handling)

final class ShelfInputField: NSTextField {
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
                            editor.insertText(trimmed, replacementRange: editor.selectedRange())
                        } else {
                            stringValue = trimmed
                        }
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
                    return true
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Shelf View Controller

final class ShelfViewController: NSViewController, NSTextFieldDelegate {
    private let store = ShelfItemStore.shared

    private let fileDropView = FileDropZoneView()
    private let inputField = ShelfInputField()
    private let pasteBtn = NSButton()
    private let addBtn = NSButton()
    private let textContainerView = NSView()
    private let defaultToastText = "Items auto-destruct in 5 minutes"
    private lazy var toastLabel = NSTextField(labelWithString: defaultToastText)
    private var toastTimer: Timer?

    deinit {
        toastTimer?.invalidate()
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 290))
        setupUI()
    }

    private func setupUI() {
        // Files Section (Top: 296 x 84, 12pt from top edge)
        fileDropView.frame = NSRect(x: 12, y: 194, width: 296, height: 84)
        fileDropView.onFilesDropped = { [weak self] urls in
            for url in urls {
                self?.store.addFileURL(url)
            }
            self?.refreshUI()
        }
        fileDropView.onFileRemoved = { [weak self] id in
            self?.store.removeFile(id: id)
            self?.refreshUI()
        }
        view.addSubview(fileDropView)

        // Text Input Field Row (Middle: y=160, h=26, 8pt gap from top section)
        inputField.frame = NSRect(x: 12, y: 160, width: 220, height: 26)
        inputField.placeholderString = "Type or paste text..."
        inputField.font = NSFont.systemFont(ofSize: 12)
        inputField.isBezeled = true
        inputField.bezelStyle = .roundedBezel
        inputField.focusRingType = .none
        inputField.delegate = self
        view.addSubview(inputField)

        // Symmetrical Quick Paste Button (32 x 26)
        pasteBtn.frame = NSRect(x: 238, y: 160, width: 32, height: 26)
        pasteBtn.title = ""
        pasteBtn.toolTip = "Paste directly from clipboard"
        pasteBtn.isBordered = false
        pasteBtn.wantsLayer = true
        pasteBtn.layer?.cornerRadius = 6
        pasteBtn.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        let pasteImg = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste clipboard")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        pasteBtn.image = pasteImg
        pasteBtn.contentTintColor = .labelColor
        pasteBtn.target = self
        pasteBtn.action = #selector(handlePasteFromClipboard)
        view.addSubview(pasteBtn)

        // Symmetrical Add (+) Button (32 x 26)
        addBtn.frame = NSRect(x: 276, y: 160, width: 32, height: 26)
        addBtn.title = ""
        addBtn.toolTip = "Add snippet to shelf"
        addBtn.isBordered = false
        addBtn.wantsLayer = true
        addBtn.layer?.cornerRadius = 6
        addBtn.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        let plusImg = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add snippet")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        addBtn.image = plusImg
        addBtn.contentTintColor = .labelColor
        addBtn.target = self
        addBtn.action = #selector(handleAddText)
        view.addSubview(addBtn)

        // Text Snippets Container (Max 4 Cards, Symmetrical: 296 x 116, 8pt gap)
        textContainerView.frame = NSRect(x: 12, y: 36, width: 296, height: 116)
        textContainerView.wantsLayer = true
        view.addSubview(textContainerView)

        // Bottom Static Notice (12pt from bottom edge)
        toastLabel.frame = NSRect(x: 12, y: 12, width: 296, height: 16)
        toastLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        toastLabel.textColor = .secondaryLabelColor
        toastLabel.alignment = .center
        toastLabel.stringValue = "Items auto-destruct in 5 minutes"
        view.addSubview(toastLabel)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        store.purgeExpired()
        refreshUI()
        NSCursor.unhide()
    }

    // MARK: - Input Actions

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submitText()
            return true
        }
        return false
    }

    @objc private func handleAddText() {
        submitText()
    }

    @objc private func handlePasteFromClipboard() {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        view.window?.makeKey()

        if let str = NSPasteboard.general.string(forType: .string) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                store.addText(trimmed)
                inputField.stringValue = ""
                inputField.currentEditor()?.string = ""
                refreshUI()
                NSCursor.unhide()
                showTemporaryToast("Pasted to shelf!")
                return
            }
        }
        showTemporaryToast("Clipboard is empty")
    }

    private func submitText() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            store.addText(text)
            inputField.stringValue = ""
            inputField.currentEditor()?.string = ""
            refreshUI()
        }
        view.window?.makeFirstResponder(nil)
        NSCursor.unhide()
    }

    // Direct Cmd+V shortcut when hovering over shelf without focusing text field
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            if let editor = inputField.currentEditor(), view.window?.firstResponder == editor {
                return super.performKeyEquivalent(with: event)
            }
            handlePasteFromClipboard()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: - UI Refresh

    func refreshUI() {
        store.purgeExpired()
        fileDropView.updateFiles(store.fileItems)
        refreshTextList()
    }

    private func refreshTextList() {
        textContainerView.subviews.forEach { $0.removeFromSuperview() }

        let items = Array(store.textItems.prefix(4))
        if items.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No temporary text snippets (max 4)")
            emptyLabel.font = NSFont.systemFont(ofSize: 11)
            emptyLabel.textColor = .tertiaryLabelColor
            emptyLabel.alignment = .center
            emptyLabel.frame = NSRect(x: 0, y: 50, width: 296, height: 16)
            textContainerView.addSubview(emptyLabel)
            return
        }

        let cardH: CGFloat = 26
        let spacing: CGFloat = 4
        let totalH = textContainerView.bounds.height // 118

        for (index, item) in items.enumerated() {
            let y = totalH - CGFloat(index + 1) * cardH - CGFloat(index) * spacing
            let frame = NSRect(x: 0, y: y, width: 296, height: cardH)
            let card = makeTextCard(for: item, frame: frame)
            textContainerView.addSubview(card)
        }
    }

    private func makeTextCard(for item: ShelfText, frame: NSRect) -> NSView {
        let card = NSView(frame: frame)
        card.wantsLayer = true
        card.layer?.cornerRadius = 6
        card.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor

        let label = NSTextField(labelWithString: item.content)
        label.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 8, y: 4, width: 228, height: 18)
        card.addSubview(label)

        // Symmetrical rounded Copy button (22 x 22)
        let copyBtn = NSButton(frame: NSRect(x: 242, y: 2, width: 22, height: 22))
        copyBtn.isBordered = false
        copyBtn.wantsLayer = true
        copyBtn.layer?.cornerRadius = 4
        copyBtn.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .regular))
        copyBtn.contentTintColor = .secondaryLabelColor
        copyBtn.target = self
        copyBtn.action = #selector(handleCopyText(_:))
        copyBtn.identifier = NSUserInterfaceItemIdentifier(item.content)
        card.addSubview(copyBtn)

        // Symmetrical rounded Delete button (22 x 22)
        let deleteBtn = NSButton(frame: NSRect(x: 268, y: 2, width: 22, height: 22))
        deleteBtn.isBordered = false
        deleteBtn.wantsLayer = true
        deleteBtn.layer?.cornerRadius = 4
        deleteBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Delete")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
        deleteBtn.contentTintColor = .tertiaryLabelColor
        deleteBtn.target = self
        deleteBtn.action = #selector(handleDeleteText(_:))
        deleteBtn.identifier = NSUserInterfaceItemIdentifier(item.id.uuidString)
        card.addSubview(deleteBtn)

        return card
    }

    @objc private func handleCopyText(_ sender: NSButton) {
        guard let text = sender.identifier?.rawValue else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showTemporaryToast("Text copied to clipboard!")
    }

    @objc private func handleDeleteText(_ sender: NSButton) {
        guard let idString = sender.identifier?.rawValue,
              let id = UUID(uuidString: idString) else { return }
        store.removeText(id: id)
        refreshUI()
    }

    private func showTemporaryToast(_ message: String) {
        toastTimer?.invalidate()
        toastLabel.stringValue = message
        toastLabel.textColor = .controlAccentColor

        toastTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.toastLabel.stringValue = self.defaultToastText
            self.toastLabel.textColor = .secondaryLabelColor
        }
    }
}

// MARK: - Symmetrical File Card View

final class FileCardView: NSView, NSDraggingSource {
    let file: ShelfFile
    var onRemove: (() -> Void)?

    init(file: ShelfFile, frame: NSRect) {
        self.file = file
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor

        let metaString = file.fileSizeFormatted
        let icon = NSWorkspace.shared.icon(forFile: file.url.path)
        let isTall = bounds.height > 50

        if isTall {
            if bounds.width > 200 {
                // 1 File: Full-width spacious card (284 x 78)
                icon.size = NSSize(width: 32, height: 32)
                let iconView = NSImageView(image: icon)
                iconView.frame = NSRect(x: 14, y: 23, width: 32, height: 32)
                addSubview(iconView)

                let nameLabel = NSTextField(labelWithString: file.fileName)
                nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
                nameLabel.lineBreakMode = .byTruncatingMiddle
                nameLabel.frame = NSRect(x: 54, y: 41, width: bounds.width - 90, height: 18)
                addSubview(nameLabel)

                let metaLabel = NSTextField(labelWithString: metaString)
                metaLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                metaLabel.textColor = .secondaryLabelColor
                metaLabel.frame = NSRect(x: 54, y: 20, width: bounds.width - 90, height: 16)
                addSubview(metaLabel)

                let closeBtn = makeCloseButton()
                closeBtn.frame = NSRect(x: bounds.width - 28, y: 31, width: 16, height: 16)
                addSubview(closeBtn)
            } else {
                // 2 Files: Symmetrical side-by-side vertical cards (139 x 78)
                icon.size = NSSize(width: 26, height: 26)
                let iconView = NSImageView(image: icon)
                iconView.frame = NSRect(x: 10, y: 44, width: 26, height: 26)
                addSubview(iconView)

                let closeBtn = makeCloseButton()
                closeBtn.frame = NSRect(x: bounds.width - 24, y: 54, width: 14, height: 14)
                addSubview(closeBtn)

                let nameLabel = NSTextField(labelWithString: file.fileName)
                nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                nameLabel.lineBreakMode = .byTruncatingMiddle
                nameLabel.frame = NSRect(x: 10, y: 24, width: bounds.width - 20, height: 16)
                addSubview(nameLabel)

                let metaLabel = NSTextField(labelWithString: metaString)
                metaLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
                metaLabel.textColor = .secondaryLabelColor
                metaLabel.frame = NSRect(x: 10, y: 8, width: bounds.width - 20, height: 14)
                addSubview(metaLabel)
            }
        } else {
            // 3 or 4 Files: Compact horizontal cards (139 x 36 or 284 x 36)
            icon.size = NSSize(width: 18, height: 18)
            let iconView = NSImageView(image: icon)
            iconView.frame = NSRect(x: 8, y: 9, width: 18, height: 18)
            addSubview(iconView)

            let closeBtn = makeCloseButton()
            closeBtn.frame = NSRect(x: bounds.width - 22, y: 11, width: 14, height: 14)
            addSubview(closeBtn)

            let textWidth = bounds.width - 56
            let nameLabel = NSTextField(labelWithString: file.fileName)
            nameLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
            nameLabel.lineBreakMode = .byTruncatingMiddle
            nameLabel.frame = NSRect(x: 30, y: 18, width: textWidth, height: 14)
            addSubview(nameLabel)

            let metaLabel = NSTextField(labelWithString: metaString)
            metaLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .regular)
            metaLabel.textColor = .secondaryLabelColor
            metaLabel.frame = NSRect(x: 30, y: 4, width: textWidth, height: 12)
            addSubview(metaLabel)
        }
    }

    private func makeCloseButton() -> NSButton {
        let btn = NSButton()
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove")
        btn.contentTintColor = .tertiaryLabelColor
        btn.target = self
        btn.action = #selector(handleClose)
        return btn
    }

    @objc private func handleClose() {
        onRemove?()
    }

    // Drag out to Finder
    override func mouseDragged(with event: NSEvent) {
        let dragItem = NSDraggingItem(pasteboardWriter: file.url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: file.url.path)
        icon.size = NSSize(width: 32, height: 32)
        dragItem.setDraggingFrame(NSRect(origin: event.locationInWindow, size: icon.size), contents: icon)
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

// MARK: - File Drop Zone View (Fills 296x90 container symmetrically)

final class FileDropZoneView: NSView, NSDraggingSource {
    var onFilesDropped: (([URL]) -> Void)?
    var onFileRemoved: ((UUID) -> Void)?

    private var currentFiles: [ShelfFile] = []
    private let titleLabel = NSTextField(labelWithString: "Drop files here (max 4)")
    private let dashedBorder = CAShapeLayer()
    private let cardsContainer = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        registerForDraggedTypes([.fileURL])

        dashedBorder.strokeColor = NSColor.tertiaryLabelColor.cgColor
        dashedBorder.fillColor = nil
        dashedBorder.lineDashPattern = [4, 4]
        dashedBorder.lineWidth = 1.0
        layer?.addSublayer(dashedBorder)

        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        addSubview(titleLabel)

        cardsContainer.frame = NSRect(x: 6, y: 6, width: 284, height: 78)
        cardsContainer.wantsLayer = true
        addSubview(cardsContainer)
    }

    override func layout() {
        super.layout()
        let path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: 8, cornerHeight: 8, transform: nil)
        dashedBorder.path = path
        dashedBorder.frame = bounds
        titleLabel.frame = NSRect(x: 10, y: (bounds.height - 18) / 2, width: bounds.width - 20, height: 18)
        cardsContainer.frame = bounds.insetBy(dx: 6, dy: 6)
    }

    func updateFiles(_ files: [ShelfFile]) {
        let active = Array(files.prefix(4))
        self.currentFiles = active
        cardsContainer.subviews.forEach { $0.removeFromSuperview() }

        if active.isEmpty {
            titleLabel.isHidden = false
            return
        }

        titleLabel.isHidden = true

        let totalW = cardsContainer.bounds.width   // 284
        let totalH = cardsContainer.bounds.height  // 78
        let spacing: CGFloat = 6

        switch active.count {
        case 1:
            let frame = NSRect(x: 0, y: 0, width: totalW, height: totalH)
            addCard(for: active[0], frame: frame)

        case 2:
            let cardW = (totalW - spacing) / 2
            let frame0 = NSRect(x: 0, y: 0, width: cardW, height: totalH)
            let frame1 = NSRect(x: cardW + spacing, y: 0, width: cardW, height: totalH)
            addCard(for: active[0], frame: frame0)
            addCard(for: active[1], frame: frame1)

        case 3:
            let rowH = (totalH - spacing) / 2
            let cardW = (totalW - spacing) / 2
            let topY = rowH + spacing
            addCard(for: active[0], frame: NSRect(x: 0, y: topY, width: cardW, height: rowH))
            addCard(for: active[1], frame: NSRect(x: cardW + spacing, y: topY, width: cardW, height: rowH))
            addCard(for: active[2], frame: NSRect(x: 0, y: 0, width: totalW, height: rowH))

        case 4:
            let rowH = (totalH - spacing) / 2
            let cardW = (totalW - spacing) / 2
            let topY = rowH + spacing
            addCard(for: active[0], frame: NSRect(x: 0, y: topY, width: cardW, height: rowH))
            addCard(for: active[1], frame: NSRect(x: cardW + spacing, y: topY, width: cardW, height: rowH))
            addCard(for: active[2], frame: NSRect(x: 0, y: 0, width: cardW, height: rowH))
            addCard(for: active[3], frame: NSRect(x: cardW + spacing, y: 0, width: cardW, height: rowH))

        default:
            break
        }
    }

    private func addCard(for file: ShelfFile, frame: NSRect) {
        let card = FileCardView(file: file, frame: frame)
        card.onRemove = { [weak self] in
            self?.onFileRemoved?(file.id)
        }
        cardsContainer.addSubview(card)
    }

    // MARK: - Drag and Drop Destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dashedBorder.strokeColor = NSColor.controlAccentColor.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dashedBorder.strokeColor = NSColor.tertiaryLabelColor.cgColor
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dashedBorder.strokeColor = NSColor.tertiaryLabelColor.cgColor
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
            return false
        }
        onFilesDropped?(urls)
        return true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

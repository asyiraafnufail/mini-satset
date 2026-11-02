import AppKit

final class ConverterViewController: NSViewController {
    private let engine = ConverterEngine.shared

    private var inputFileURL: URL?
    private var outputFileURL: URL?
    private var isConverting: Bool = false

    // Views
    private let inputDropZone = ConverterDropZoneView()
    private let optionsCard = NSView()
    private let formatLabel = NSTextField(labelWithString: "Format:")
    private let formatPopup = NSPopUpButton()
    private let qualityLabel = NSTextField(labelWithString: "Quality:")
    private let qualityControl = NSSegmentedControl()
    private let convertButton = NSButton()
    private let spinner = NSProgressIndicator()
    private let outputShelfView = ConverterOutputShelfView()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 290))
        setupUI()
    }

    private func setupUI() {
        // 1. Input Drop Zone (Top: 296 x 70, 12pt from top edge)
        inputDropZone.frame = NSRect(x: 12, y: 208, width: 296, height: 70)
        inputDropZone.onFileDropped = { [weak self] url in
            self?.setInputFile(url)
        }
        inputDropZone.onFileCleared = { [weak self] in
            self?.clearInputFile()
        }
        view.addSubview(inputDropZone)

        // 2. Options Card (Middle: 296 x 74, 8pt gap)
        optionsCard.frame = NSRect(x: 12, y: 126, width: 296, height: 74)
        optionsCard.wantsLayer = true
        optionsCard.layer?.cornerRadius = 8
        optionsCard.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        view.addSubview(optionsCard)

        formatLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        formatLabel.textColor = .secondaryLabelColor
        formatLabel.frame = NSRect(x: 12, y: 44, width: 56, height: 18)
        optionsCard.addSubview(formatLabel)

        formatPopup.frame = NSRect(x: 72, y: 41, width: 212, height: 24)
        formatPopup.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        formatPopup.target = self
        formatPopup.action = #selector(handleFormatChanged)
        optionsCard.addSubview(formatPopup)

        qualityLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        qualityLabel.textColor = .secondaryLabelColor
        qualityLabel.frame = NSRect(x: 12, y: 14, width: 56, height: 18)
        optionsCard.addSubview(qualityLabel)

        qualityControl.frame = NSRect(x: 72, y: 12, width: 212, height: 22)
        qualityControl.segmentCount = 3
        qualityControl.setLabel("High", forSegment: 0)
        qualityControl.setLabel("Medium", forSegment: 1)
        qualityControl.setLabel("Compressed", forSegment: 2)
        qualityControl.selectedSegment = 0
        qualityControl.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        optionsCard.addSubview(qualityControl)

        // 3. Symmetrical Convert Action Button (296 x 28, 8pt gap, radius 8)
        convertButton.frame = NSRect(x: 12, y: 90, width: 296, height: 28)
        convertButton.title = "Convert File"
        convertButton.wantsLayer = true
        convertButton.isBordered = false
        convertButton.layer?.cornerRadius = 8
        convertButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        convertButton.target = self
        convertButton.action = #selector(handleConvertClick)
        convertButton.isEnabled = false
        view.addSubview(convertButton)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.frame = NSRect(x: 268, y: 6, width: 16, height: 16)
        spinner.isDisplayedWhenStopped = false
        convertButton.addSubview(spinner)

        // 4. Temporary Output Shelf (Bottom: 296 x 70, 8pt gap, 12pt from bottom edge)
        outputShelfView.frame = NSRect(x: 12, y: 12, width: 296, height: 70)
        outputShelfView.onClear = { [weak self] in
            self?.clearOutputFile()
        }
        view.addSubview(outputShelfView)

        updateState()
    }

    func setInputFile(_ url: URL) {
        guard outputFileURL == nil else { return }
        self.inputFileURL = url
        inputDropZone.displayFile(url)

        let formats = engine.availableTargetFormats(for: url)
        formatPopup.removeAllItems()
        for fmt in formats {
            formatPopup.addItem(withTitle: fmt.uppercased())
        }

        let cat = engine.category(for: url)
        if cat == .audio {
            qualityControl.setLabel("Original", forSegment: 0)
            qualityControl.setLabel("256 kbps", forSegment: 1)
            qualityControl.setLabel("128 kbps", forSegment: 2)
        } else {
            qualityControl.setLabel("High", forSegment: 0)
            qualityControl.setLabel("Medium", forSegment: 1)
            qualityControl.setLabel("Compressed", forSegment: 2)
        }

        updateState()
    }

    private func clearInputFile() {
        self.inputFileURL = nil
        inputDropZone.reset()
        formatPopup.removeAllItems()
        updateState()
    }

    private func clearOutputFile() {
        if let out = outputFileURL {
            try? FileManager.default.removeItem(at: out)
        }
        self.outputFileURL = nil
        outputShelfView.reset()
        updateState()
    }

    @objc private func handleFormatChanged() {
        updateState()
    }

    @objc private func handleConvertClick() {
        guard let source = inputFileURL,
              let targetFmt = formatPopup.titleOfSelectedItem?.lowercased(),
              outputFileURL == nil,
              !isConverting else { return }

        isConverting = true
        spinner.startAnimation(nil)
        updateState()

        let cat = engine.category(for: source)

        if cat == .image {
            let quality = ImageQuality(rawValue: qualityControl.selectedSegment) ?? .high
            engine.convertImage(sourceURL: source, targetExt: targetFmt, quality: quality) { [weak self] result in
                guard let self = self else { return }
                self.isConverting = false
                self.spinner.stopAnimation(nil)

                switch result {
                case .success(let outURL):
                    self.outputFileURL = outURL
                    self.outputShelfView.displayFile(outURL, originalURL: source)
                    self.clearInputFile()
                case .failure(let error):
                    self.showErrorAlert(error.localizedDescription)
                    self.updateState()
                }
            }
        } else if cat == .audio {
            let quality = AudioQuality(rawValue: qualityControl.selectedSegment) ?? .original
            engine.convertAudio(sourceURL: source, targetExt: targetFmt, quality: quality) { [weak self] result in
                guard let self = self else { return }
                self.isConverting = false
                self.spinner.stopAnimation(nil)

                switch result {
                case .success(let outURL):
                    self.outputFileURL = outURL
                    self.outputShelfView.displayFile(outURL, originalURL: source)
                    self.clearInputFile()
                case .failure(let error):
                    self.showErrorAlert(error.localizedDescription)
                    self.updateState()
                }
            }
        }
    }

    private func updateState() {
        let hasOutput = (outputFileURL != nil)

        // Strict lock: input & convert are disabled if output shelf has an item
        inputDropZone.isLocked = hasOutput
        optionsCard.alphaValue = hasOutput ? 0.4 : 1.0
        formatPopup.isEnabled = !hasOutput && (inputFileURL != nil)
        qualityControl.isEnabled = !hasOutput && (inputFileURL != nil)

        let canConvert = (!hasOutput && inputFileURL != nil && formatPopup.numberOfItems > 0 && !isConverting)
        convertButton.isEnabled = canConvert

        if isConverting {
            convertButton.title = "Converting..."
            convertButton.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
            convertButton.contentTintColor = .white
        } else if canConvert {
            convertButton.title = "Convert File"
            convertButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            convertButton.contentTintColor = .white
        } else {
            convertButton.title = "Convert File"
            convertButton.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
            convertButton.contentTintColor = .tertiaryLabelColor
        }
    }

    private func showErrorAlert(_ msg: String) {
        let alert = NSAlert()
        alert.messageText = "Conversion Error"
        alert.informativeText = msg
        alert.alertStyle = .warning
        alert.runModal()
    }
}

// MARK: - Input Drop Zone View

final class ConverterDropZoneView: NSView {
    var onFileDropped: ((URL) -> Void)?
    var onFileCleared: (() -> Void)?

    var isLocked: Bool = false {
        didSet {
            updateLockedState()
        }
    }

    private let titleLabel = NSTextField(labelWithString: "Drop 1 file here (Image or Audio)")
    private let dashedBorder = CAShapeLayer()
    private let contentContainer = NSView()

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

        contentContainer.wantsLayer = true
        contentContainer.isHidden = true
        addSubview(contentContainer)
    }

    override func layout() {
        super.layout()
        let path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: 8, cornerHeight: 8, transform: nil)
        dashedBorder.path = path
        dashedBorder.frame = bounds
        titleLabel.frame = NSRect(x: 10, y: (bounds.height - 18) / 2, width: bounds.width - 20, height: 18)
        contentContainer.frame = bounds.insetBy(dx: 4, dy: 4)
    }

    private func updateLockedState() {
        if isLocked {
            titleLabel.stringValue = "Output slot full • clear below to convert"
            titleLabel.textColor = .tertiaryLabelColor
            dashedBorder.strokeColor = NSColor.separatorColor.cgColor
        } else {
            titleLabel.stringValue = "Drop 1 file here (Image or Audio)"
            titleLabel.textColor = .secondaryLabelColor
            dashedBorder.strokeColor = NSColor.tertiaryLabelColor.cgColor
        }
    }

    func displayFile(_ url: URL) {
        titleLabel.isHidden = true
        contentContainer.isHidden = false
        contentContainer.subviews.forEach { $0.removeFromSuperview() }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        let iconView = NSImageView(image: icon)
        iconView.frame = NSRect(x: 10, y: 17, width: 32, height: 32)
        contentContainer.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: url.lastPathComponent)
        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.frame = NSRect(x: 50, y: 34, width: bounds.width - 86, height: 16)
        contentContainer.addSubview(nameLabel)

        var sizeString = "File"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB, .useBytes]
            formatter.countStyle = .file
            sizeString = formatter.string(fromByteCount: size)
        }

        let metaLabel = NSTextField(labelWithString: "\(url.pathExtension.uppercased()) • \(sizeString)")
        metaLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .regular)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.frame = NSRect(x: 50, y: 16, width: bounds.width - 86, height: 14)
        contentContainer.addSubview(metaLabel)

        let clearBtn = NSButton()
        clearBtn.isBordered = false
        clearBtn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear")
        clearBtn.contentTintColor = .tertiaryLabelColor
        clearBtn.frame = NSRect(x: bounds.width - 32, y: 25, width: 16, height: 16)
        clearBtn.target = self
        clearBtn.action = #selector(handleClear)
        contentContainer.addSubview(clearBtn)
    }

    func reset() {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        contentContainer.isHidden = true
        titleLabel.isHidden = false
        updateLockedState()
    }

    @objc private func handleClear() {
        reset()
        onFileCleared?()
    }

    // MARK: - Drag and Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !isLocked else { return [] }
        dashedBorder.strokeColor = NSColor.controlAccentColor.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        updateLockedState()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard !isLocked else { return false }
        updateLockedState()
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let first = urls.first else { return false }

        let cat = ConverterEngine.shared.category(for: first)
        guard cat != .unsupported else { return false }

        onFileDropped?(first)
        return true
    }
}

// MARK: - Output Temporary Shelf View (Max 1 File, Draggable Out)

final class ConverterOutputShelfView: NSView, NSDraggingSource {
    var onClear: (() -> Void)?
    private var currentFileURL: URL?
    private let placeholderLabel = NSTextField(labelWithString: "Converted file will appear here")
    private let contentCard = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor

        placeholderLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        placeholderLabel.textColor = .tertiaryLabelColor
        placeholderLabel.alignment = .center
        addSubview(placeholderLabel)

        contentCard.wantsLayer = true
        contentCard.isHidden = true
        addSubview(contentCard)
    }

    override func layout() {
        super.layout()
        placeholderLabel.frame = NSRect(x: 10, y: (bounds.height - 18) / 2, width: max(0, bounds.width - 20), height: 18)
        contentCard.frame = bounds
    }

    func displayFile(_ url: URL, originalURL: URL) {
        self.currentFileURL = url
        placeholderLabel.isHidden = true
        contentCard.isHidden = false
        contentCard.subviews.forEach { $0.removeFromSuperview() }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        let iconView = NSImageView(image: icon)
        iconView.frame = NSRect(x: 12, y: 21, width: 32, height: 32)
        contentCard.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: url.lastPathComponent)
        nameLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.frame = NSRect(x: 52, y: 38, width: bounds.width - 92, height: 18)
        contentCard.addSubview(nameLabel)

        var newSizeStr = "File"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB, .useBytes]
            formatter.countStyle = .file
            newSizeStr = formatter.string(fromByteCount: size)
        }

        let metaLabel = NSTextField(labelWithString: "Ready • \(newSizeStr) • Drag out")
        metaLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium)
        metaLabel.textColor = .controlAccentColor
        metaLabel.frame = NSRect(x: 52, y: 18, width: bounds.width - 92, height: 16)
        contentCard.addSubview(metaLabel)

        let removeBtn = NSButton()
        removeBtn.isBordered = false
        removeBtn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear output")
        removeBtn.contentTintColor = .tertiaryLabelColor
        removeBtn.frame = NSRect(x: bounds.width - 32, y: 29, width: 16, height: 16)
        removeBtn.target = self
        removeBtn.action = #selector(handleRemove)
        contentCard.addSubview(removeBtn)
    }

    func reset() {
        self.currentFileURL = nil
        contentCard.subviews.forEach { $0.removeFromSuperview() }
        contentCard.isHidden = true
        placeholderLabel.isHidden = false
    }

    @objc private func handleRemove() {
        reset()
        onClear?()
    }

    // Drag out to Finder
    override func mouseDragged(with event: NSEvent) {
        guard let url = currentFileURL else { return }
        let dragItem = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        dragItem.setDraggingFrame(NSRect(origin: event.locationInWindow, size: icon.size), contents: icon)
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

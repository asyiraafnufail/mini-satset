import AppKit

protocol OCRViewControllerDelegate: AnyObject {
    func ocrViewControllerDidRequestSnip(_ controller: OCRViewController)
}

final class OCRCardView: NSView {
    var onFileDropped: ((URL) -> Void)?
    var onCopyClicked: (() -> Void)?
    var onClearClicked: (() -> Void)?

    private let emptyContainer = NSView()
    private let activeContainer = NSView()
    private let dashedBorder = CAShapeLayer()

    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let copyBtn = NSButton()
    private let clearBtn = NSButton()

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
        let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .light)
        icon.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        icon.contentTintColor = .tertiaryLabelColor
        icon.frame = NSRect(x: (296 - 44) / 2, y: 108, width: 44, height: 44)
        emptyContainer.addSubview(icon)

        let title = NSTextField(labelWithString: "No Text Snipped")
        title.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        title.textColor = .secondaryLabelColor
        title.alignment = .center
        title.frame = NSRect(x: 12, y: 82, width: 272, height: 18)
        emptyContainer.addSubview(title)

        let sub = NSTextField(labelWithString: "Click 'Snip' above or drop image here")
        sub.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        sub.textColor = .tertiaryLabelColor
        sub.alignment = .center
        sub.frame = NSRect(x: 12, y: 62, width: 272, height: 16)
        emptyContainer.addSubview(sub)
    }

    private func setupActiveState() {
        activeContainer.wantsLayer = true
        addSubview(activeContainer)

        // Text Scroll View (276 x 136, y=46)
        scrollView.frame = NSRect(x: 10, y: 46, width: 276, height: 138)
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        textView.frame = NSRect(x: 0, y: 0, width: 276, height: 138)
        textView.minSize = NSSize(width: 0.0, height: 138)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 276, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = true

        scrollView.documentView = textView
        activeContainer.addSubview(scrollView)

        // Action Buttons (y=10, h=26, w=132 each)
        copyBtn.frame = NSRect(x: 12, y: 10, width: 132, height: 26)
        copyBtn.title = " Copy Text"
        let imgConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        copyBtn.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)?
            .withSymbolConfiguration(imgConfig)
        copyBtn.isBordered = false
        copyBtn.wantsLayer = true
        copyBtn.layer?.cornerRadius = 6
        copyBtn.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        copyBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        copyBtn.contentTintColor = .labelColor
        copyBtn.target = self
        copyBtn.action = #selector(handleCopyClick)
        activeContainer.addSubview(copyBtn)

        clearBtn.frame = NSRect(x: 152, y: 10, width: 132, height: 26)
        clearBtn.title = " Clear"
        clearBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(imgConfig)
        clearBtn.isBordered = false
        clearBtn.wantsLayer = true
        clearBtn.layer?.cornerRadius = 6
        clearBtn.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        clearBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        clearBtn.contentTintColor = .labelColor
        clearBtn.target = self
        clearBtn.action = #selector(handleClearClick)
        activeContainer.addSubview(clearBtn)
    }

    func showEmpty(_ empty: Bool) {
        emptyContainer.isHidden = !empty
        activeContainer.isHidden = empty
        dashedBorder.isHidden = !empty
    }

    func displayText(_ text: String) {
        textView.string = text
        showEmpty(false)
    }

    var currentText: String {
        return textView.string
    }

    @objc private func handleCopyClick() {
        onCopyClicked?()
    }

    @objc private func handleClearClick() {
        showEmpty(true)
        textView.string = ""
        onClearClicked?()
    }

    // Drag and Drop (Image to OCR)
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

final class OCRViewController: NSViewController {
    weak var delegate: OCRViewControllerDelegate?
    private let engine = OCREngine.shared

    private let snipButton = NSButton()
    private let cardView = OCRCardView()
    private let defaultFooterText = "Select screen area to extract text • 100% offline"
    private lazy var toastLabel = NSTextField(labelWithString: defaultFooterText)
    private var toastTimer: Timer?

    var isSnipping: Bool = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 290))
        setupUI()
    }

    deinit {
        toastTimer?.invalidate()
    }

    private func setupUI() {
        // Top Primary Action Button (296 x 28, y=250, radius 8)
        snipButton.frame = NSRect(x: 12, y: 250, width: 296, height: 28)
        snipButton.title = " Snip Screen Text (Area)"
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        snipButton.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        snipButton.wantsLayer = true
        snipButton.isBordered = false
        snipButton.layer?.cornerRadius = 8
        snipButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        snipButton.contentTintColor = .white
        snipButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        snipButton.target = self
        snipButton.action = #selector(handleSnipClick)
        view.addSubview(snipButton)

        // Center Card & Drop Zone (296 x 194, y=46)
        cardView.frame = NSRect(x: 12, y: 46, width: 296, height: 194)
        cardView.onFileDropped = { [weak self] url in
            self?.processImageFile(url)
        }
        cardView.onCopyClicked = { [weak self] in
            self?.copyCurrentText()
        }
        cardView.onClearClicked = { [weak self] in
            self?.showToast("Cleared")
        }
        view.addSubview(cardView)

        // Bottom Footer Label (y=14, h=18)
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

    @objc private func handleSnipClick() {
        delegate?.ocrViewControllerDidRequestSnip(self)
    }

    func processImageFile(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        showToast("Recognizing text...")
        engine.recognizeText(from: url) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let text):
                if !text.isEmpty {
                    self.cardView.displayText(text)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    self.showToast("Extracted & copied to clipboard!")
                } else {
                    self.showToast("No readable text found in image")
                }
            case .failure:
                self.showToast("Failed to process image")
            }
        }
    }

    func handleSnippedResult(_ text: String?) {
        guard let text = text, !text.isEmpty else {
            showToast("Snip canceled or no text found")
            return
        }

        cardView.displayText(text)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast("Text copied to clipboard!")
    }

    private func copyCurrentText() {
        let text = cardView.currentText
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast("Copied to clipboard!")
    }

    private func showToast(_ msg: String) {
        toastTimer?.invalidate()
        toastLabel.stringValue = msg
        toastLabel.textColor = .controlAccentColor

        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.toastLabel.stringValue = self.defaultFooterText
            self.toastLabel.textColor = .secondaryLabelColor
        }
    }
}

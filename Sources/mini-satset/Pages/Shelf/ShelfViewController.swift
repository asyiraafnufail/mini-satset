import AppKit

final class ShelfViewController: NSViewController, NSTextFieldDelegate {
    private let store = ShelfItemStore.shared
    private var countdownTimer: Timer?

    private let fileDropView = FileDropZoneView()
    private let inputField = NSTextField()
    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()
    private let toastLabel = NSTextField(labelWithString: "")

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 290))
        setupUI()
    }

    private func setupUI() {
        fileDropView.frame = NSRect(x: 12, y: 190, width: 296, height: 90)
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

        inputField.frame = NSRect(x: 12, y: 154, width: 296, height: 26)
        inputField.placeholderString = "Simpan teks cepat (tekan Enter)..."
        inputField.font = NSFont.systemFont(ofSize: 12)
        inputField.isBezeled = true
        inputField.bezelStyle = .roundedBezel
        inputField.focusRingType = .none
        inputField.delegate = self
        view.addSubview(inputField)

        scrollView.frame = NSRect(x: 12, y: 30, width: 296, height: 118)
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 4
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let clipView = NSClipView()
        clipView.drawsBackground = false
        clipView.documentView = contentStack
        scrollView.contentView = clipView
        view.addSubview(scrollView)

        // Set width constraint for stack inside scroll view
        NSLayoutConstraint.activate([
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -12),
            contentStack.topAnchor.constraint(equalTo: clipView.topAnchor)
        ])

        toastLabel.frame = NSRect(x: 12, y: 6, width: 296, height: 18)
        toastLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        toastLabel.textColor = .secondaryLabelColor
        toastLabel.alignment = .center
        toastLabel.stringValue = "Item otomatis terhapus dalam 5 menit"
        view.addSubview(toastLabel)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        store.purgeExpired()
        refreshUI()
        startCountdownTimer()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        stopCountdownTimer()
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let text = inputField.stringValue
            if !text.isEmpty {
                store.addText(text)
                inputField.stringValue = ""
                refreshUI()
            }
            return true
        }
        return false
    }

    // MARK: - Refresh & Timer

    func refreshUI() {
        fileDropView.updateFiles(store.fileItems)

        contentStack.subviews.forEach { $0.removeFromSuperview() }

        if store.textItems.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "Belum ada teks sementara.")
            emptyLabel.font = NSFont.systemFont(ofSize: 11)
            emptyLabel.textColor = .tertiaryLabelColor
            contentStack.addArrangedSubview(emptyLabel)
        } else {
            for item in store.textItems {
                let row = makeTextRow(for: item)
                contentStack.addArrangedSubview(row)
            }
        }
    }

    private func makeTextRow(for item: ShelfText) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 6
        container.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        let mins = item.remainingSeconds / 60
        let secs = item.remainingSeconds % 60
        let timeString = String(format: "%d:%02d", mins, secs)

        let label = NSTextField(labelWithString: item.content)
        label.font = NSFont.systemFont(ofSize: 11)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false

        let timerLabel = NSTextField(labelWithString: timeString)
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        timerLabel.textColor = .secondaryLabelColor
        timerLabel.translatesAutoresizingMaskIntoConstraints = false

        let copyBtn = NSButton()
        copyBtn.isBordered = false
        copyBtn.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Salin")
        copyBtn.contentTintColor = .secondaryLabelColor
        copyBtn.translatesAutoresizingMaskIntoConstraints = false
        copyBtn.target = self
        copyBtn.action = #selector(handleCopyText(_:))
        copyBtn.identifier = NSUserInterfaceItemIdentifier(item.content)

        container.addSubview(label)
        container.addSubview(timerLabel)
        container.addSubview(copyBtn)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 26),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: timerLabel.leadingAnchor, constant: -6),

            timerLabel.trailingAnchor.constraint(equalTo: copyBtn.leadingAnchor, constant: -4),
            timerLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            copyBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            copyBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            copyBtn.widthAnchor.constraint(equalToConstant: 20),
            copyBtn.heightAnchor.constraint(equalToConstant: 20)
        ])

        return container
    }

    @objc private func handleCopyText(_ sender: NSButton) {
        guard let text = sender.identifier?.rawValue else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        toastLabel.stringValue = "Teks disalin ke clipboard!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.toastLabel.stringValue = "Item otomatis terhapus dalam 5 menit"
        }
    }

    private func startCountdownTimer() {
        stopCountdownTimer()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.store.purgeExpired()
            self.refreshUI()
        }
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}

// MARK: - File Drop Zone View

final class FileDropZoneView: NSView, NSDraggingSource {
    var onFilesDropped: (([URL]) -> Void)?
    var onFileRemoved: ((UUID) -> Void)?

    private var currentFiles: [ShelfFile] = []
    private let titleLabel = NSTextField(labelWithString: "Tarik file ke sini (Shelf 5m)")
    private let filesStack = NSStackView()
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
        registerForDraggedTypes([.fileURL])

        dashedBorder.strokeColor = NSColor.tertiaryLabelColor.cgColor
        dashedBorder.fillColor = nil
        dashedBorder.lineDashPattern = [4, 4]
        dashedBorder.lineWidth = 1.0
        layer?.addSublayer(dashedBorder)

        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        filesStack.orientation = .horizontal
        filesStack.spacing = 6
        filesStack.alignment = .centerY
        filesStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(filesStack)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            filesStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            filesStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            filesStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            filesStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    override func layout() {
        super.layout()
        let path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: 8, cornerHeight: 8, transform: nil)
        dashedBorder.path = path
        dashedBorder.frame = bounds
    }

    func updateFiles(_ files: [ShelfFile]) {
        self.currentFiles = files
        filesStack.subviews.forEach { $0.removeFromSuperview() }

        if files.isEmpty {
            titleLabel.isHidden = false
            filesStack.isHidden = true
        } else {
            titleLabel.isHidden = true
            filesStack.isHidden = false

            for file in files.prefix(4) {
                let chip = makeFileChip(for: file)
                filesStack.addArrangedSubview(chip)
            }
        }
    }

    private func makeFileChip(for file: ShelfFile) -> NSView {
        let chip = NSView()
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 6
        chip.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor

        let icon = NSWorkspace.shared.icon(forFile: file.url.path)
        icon.size = NSSize(width: 16, height: 16)
        let imgView = NSImageView(image: icon)
        imgView.frame = NSRect(x: 4, y: 6, width: 16, height: 16)
        chip.addSubview(imgView)

        let label = NSTextField(labelWithString: file.fileName)
        label.font = NSFont.systemFont(ofSize: 10)
        label.lineBreakMode = .byTruncatingMiddle
        label.frame = NSRect(x: 22, y: 14, width: 80, height: 14)
        chip.addSubview(label)

        let mins = file.remainingSeconds / 60
        let secs = file.remainingSeconds % 60
        let timeLabel = NSTextField(labelWithString: "\(file.fileSizeFormatted) • \(mins):\(String(format: "%02d", secs))")
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.frame = NSRect(x: 22, y: 2, width: 80, height: 12)
        chip.addSubview(timeLabel)

        let closeBtn = NSButton()
        closeBtn.isBordered = false
        closeBtn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Hapus")
        closeBtn.contentTintColor = .tertiaryLabelColor
        closeBtn.frame = NSRect(x: 104, y: 7, width: 14, height: 14)
        closeBtn.identifier = NSUserInterfaceItemIdentifier(file.id.uuidString)
        closeBtn.target = self
        closeBtn.action = #selector(handleRemoveFile(_:))
        chip.addSubview(closeBtn)

        chip.frame = NSRect(x: 0, y: 0, width: 122, height: 28)
        chip.widthAnchor.constraint(equalToConstant: 122).isActive = true
        chip.heightAnchor.constraint(equalToConstant: 28).isActive = true

        return chip
    }

    @objc private func handleRemoveFile(_ sender: NSButton) {
        guard let idString = sender.identifier?.rawValue,
              let id = UUID(uuidString: idString) else { return }
        onFileRemoved?(id)
    }

    // MARK: - Drag and Drop Destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dashedBorder.strokeColor = NSColor.controlAccentColor.cgColor
        dashedBorder.lineWidth = 2.0
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dashedBorder.strokeColor = NSColor.tertiaryLabelColor.cgColor
        dashedBorder.lineWidth = 1.0
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        draggingExited(nil)
        guard let pasteboard = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        onFilesDropped?(pasteboard)
        return true
    }

    // MARK: - Dragging Source (Drag out)

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

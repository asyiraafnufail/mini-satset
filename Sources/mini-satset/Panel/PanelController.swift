import AppKit
import QuartzCore

protocol PanelControllerDelegate: AnyObject {
    func panelControllerMouseEnter(_ controller: PanelController)
    func panelControllerMouseExit(_ controller: PanelController)
    func panelControllerDidRequestClose(_ controller: PanelController)
    func panelControllerDidRequestSnip(_ controller: PanelController)
}

final class TrackingVisualEffectView: NSVisualEffectView {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onFilesDropped: (([URL]) -> Void)?
    private var trackingAreaRef: NSTrackingArea?
    private var lastMaskSize: NSSize = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        registerForDraggedTypes([.fileURL])
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        guard let types = pasteboard.types, types.contains(.fileURL) else {
            return []
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
            return false
        }
        onFilesDropped?(urls)
        return true
    }

    override func layout() {
        super.layout()
        if bounds.size != lastMaskSize && bounds.width > 0 && bounds.height > 0 {
            lastMaskSize = bounds.size
            updateMask()
        }
    }

    private func updateMask() {
        let cornerRadius: CGFloat = 16
        let mask = NSImage(size: bounds.size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.black.setFill()
            path.fill()
            return true
        }
        self.maskImage = mask
        self.window?.invalidateShadow()
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

    override func mouseEntered(with event: NSEvent) {
        onMouseEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExit?()
    }
}

final class PanelController: NSObject, FloatingPanelDelegate, PageIndicatorViewDelegate, OCRViewControllerDelegate {
    weak var delegate: PanelControllerDelegate?

    private let panel: FloatingPanel
    private let visualEffectView = TrackingVisualEffectView()
    private let pageIndicator = PageIndicatorView(frame: NSRect(x: 0, y: 294, width: 320, height: 38))
    private let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 292))

    private let shelfVC = ShelfViewController()
    private let converterVC = ConverterViewController()
    private let colorSamplerVC = ColorSamplerViewController()
    private let qrCodeVC = QRCodeViewController()
    let ocrVC = OCRViewController()

    private lazy var pages: [NSViewController] = [shelfVC, converterVC, colorSamplerVC, qrCodeVC, ocrVC]
    private(set) var activePageIndex: Int = 0
    private(set) var isPinned: Bool = false
    var onPinStateChanged: ((Bool) -> Void)?
    private let pinButton = NSButton()

    // MARK: - Animation State Machine & Dedicated Timer Animator

    private enum PanelState {
        case closed
        case opening
        case open
        case closing
    }

    private var state: PanelState = .closed
    private var transitionTimer: Timer?

    var isVisible: Bool {
        return state == .open || state == .opening
    }

    var isSamplingColor: Bool {
        return colorSamplerVC.isSamplingColor
    }

    var isSnippingText: Bool {
        return ocrVC.isSnipping
    }

    var hasActiveSheet: Bool {
        return panel.attachedSheet != nil
    }

    private var targetFrame: NSRect = .zero

    var currentFrame: NSRect {
        return targetFrame != .zero ? targetFrame : panel.frame
    }

    deinit {
        transitionTimer?.invalidate()
    }

    override init() {
        let contentRect = NSRect(x: 0, y: 0, width: 320, height: 332)
        self.panel = FloatingPanel(contentRect: contentRect)
        super.init()

        panel.panelDelegate = self
        ocrVC.delegate = self
        setupViews()
        pageIndicator.delegate = self
        displayPage(at: activePageIndex, animated: false)
    }

    private func setupViews() {
        visualEffectView.frame = NSRect(x: 0, y: 0, width: 320, height: 332)
        containerView.wantsLayer = true

        visualEffectView.onMouseEnter = { [weak self] in
            guard let self = self else { return }
            self.delegate?.panelControllerMouseEnter(self)
        }
        visualEffectView.onMouseExit = { [weak self] in
            guard let self = self else { return }
            self.delegate?.panelControllerMouseExit(self)
        }
        visualEffectView.onFilesDropped = { [weak self] urls in
            guard let self = self else { return }
            if self.activePageIndex == 1, let first = urls.first {
                self.addFileToConverter(first)
            } else if self.activePageIndex == 3, let first = urls.first {
                self.readQRCode(first)
            } else if self.activePageIndex == 4, let first = urls.first {
                self.processOCRImage(first)
            } else {
                self.addFilesToShelf(urls)
            }
        }

        let separator = NSBox(frame: NSRect(x: 0, y: 293, width: 320, height: 1))
        separator.boxType = .separator

        setupPinButton()

        visualEffectView.addSubview(pageIndicator)
        visualEffectView.addSubview(pinButton)
        visualEffectView.addSubview(separator)
        visualEffectView.addSubview(containerView)

        panel.contentView = visualEffectView
    }

    private func setupPinButton() {
        pinButton.frame = NSRect(x: 282, y: 300, width: 26, height: 26)
        pinButton.isBordered = false
        pinButton.wantsLayer = true
        pinButton.layer?.cornerRadius = 6
        pinButton.target = self
        pinButton.action = #selector(handlePinToggle)
        updatePinUI()
    }

    @objc private func handlePinToggle() {
        isPinned.toggle()
        updatePinUI()
        onPinStateChanged?(isPinned)
    }

    private func updatePinUI() {
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        if isPinned {
            pinButton.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Unpin panel")?
                .withSymbolConfiguration(config)
            pinButton.contentTintColor = .controlAccentColor
            pinButton.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
            pinButton.toolTip = "Pinned: Panel stays open. Click to unpin."
        } else {
            pinButton.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin panel")?
                .withSymbolConfiguration(config)
            pinButton.contentTintColor = .secondaryLabelColor
            pinButton.layer?.backgroundColor = NSColor.clear.cgColor
            pinButton.toolTip = "Unpinned: Panel closes on mouse exit. Click to pin."
        }
    }

    // MARK: - FloatingPanelDelegate

    func floatingPanelDidRequestClose(_ panel: FloatingPanel) {
        delegate?.panelControllerDidRequestClose(self)
    }

    // MARK: - Page Indicator Delegate

    func pageIndicator(_ indicator: PageIndicatorView, didSelectPageAt index: Int) {
        guard index != activePageIndex else { return }
        switchPage(to: index)
    }

    private func switchPage(to newIndex: Int) {
        guard newIndex >= 0 && newIndex < pages.count, newIndex != activePageIndex else { return }

        let oldVC = pages[activePageIndex]
        let newVC = pages[newIndex]
        activePageIndex = newIndex

        oldVC.view.removeFromSuperview()
        newVC.view.frame = containerView.bounds
        newVC.view.alphaValue = 1.0
        containerView.addSubview(newVC.view)
        newVC.viewWillAppear()

        if newIndex == 0 {
            shelfVC.refreshUI()
        }
    }

    func displayPage(at index: Int, animated: Bool) {
        activePageIndex = index
        pageIndicator.selectTab(at: index, notify: false)
        containerView.subviews.forEach { $0.removeFromSuperview() }
        let currentVC = pages[index]
        currentVC.view.frame = containerView.bounds
        containerView.addSubview(currentVC.view)
        currentVC.viewWillAppear()
    }

    func switchToShelfPage() {
        guard activePageIndex != 0 else { return }
        displayPage(at: 0, animated: false)
    }

    func addFileToConverter(_ url: URL) {
        converterVC.setInputFile(url)
    }

    func readQRCode(_ url: URL) {
        displayPage(at: 3, animated: false)
        qrCodeVC.readQR(from: url)
    }

    func processOCRImage(_ url: URL) {
        displayPage(at: 4, animated: false)
        ocrVC.processImageFile(url)
    }

    func handleOCRResult(_ text: String?) {
        ocrVC.handleSnippedResult(text)
    }

    func ocrViewControllerDidRequestSnip(_ controller: OCRViewController) {
        delegate?.panelControllerDidRequestSnip(self)
    }

    func addFilesToShelf(_ urls: [URL]) {
        for url in urls {
            ShelfItemStore.shared.addFileURL(url)
        }
        switchToShelfPage()
        shelfVC.refreshUI()
    }

    // MARK: - Show & Hide (Deterministic Hardware-Timed Interpolation)

    func show(relativeTo statusButton: NSView) {
        guard state != .open && state != .opening else { return }
        state = .opening

        transitionTimer?.invalidate()
        transitionTimer = nil

        guard let buttonWindow = statusButton.window,
              let screen = buttonWindow.screen ?? NSScreen.main else {
            state = .closed
            return
        }

        let buttonBounds = statusButton.bounds
        let buttonScreenRect = buttonWindow.convertToScreen(statusButton.convert(buttonBounds, to: nil))

        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 332

        var originX = buttonScreenRect.midX - (panelWidth / 2)
        originX = max(screen.visibleFrame.minX + 8, min(originX, screen.visibleFrame.maxX - panelWidth - 8))
        let targetY = screen.visibleFrame.maxY - panelHeight - 2

        let finalFrame = NSRect(x: originX, y: targetY, width: panelWidth, height: panelHeight)
        let startY = targetY + 6.0
        targetFrame = finalFrame

        panel.setFrame(NSRect(x: originX, y: startY, width: panelWidth, height: panelHeight), display: false)
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()

        pages[activePageIndex].viewWillAppear()
        if activePageIndex == 0 {
            shelfVC.refreshUI()
        }

        let duration: Double = 0.20
        let startTime = CACurrentMediaTime()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(1.0, max(0.0, elapsed / duration))
            let eased = self.easeInOutCubic(CGFloat(progress))

            let currentY = startY - (6.0 * eased)
            self.panel.setFrame(NSRect(x: originX, y: currentY, width: panelWidth, height: panelHeight), display: false)
            self.panel.alphaValue = eased

            if progress >= 1.0 {
                timer.invalidate()
                self.transitionTimer = nil
                self.panel.setFrame(finalFrame, display: false)
                self.panel.alphaValue = 1.0
                self.state = .open
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        transitionTimer = timer
    }

    func hide(completion: (() -> Void)? = nil) {
        guard state != .closed && state != .closing else {
            completion?()
            return
        }
        state = .closing

        transitionTimer?.invalidate()
        transitionTimer = nil

        let currentFrame = panel.frame
        let startY = currentFrame.origin.y
        let startAlpha = panel.alphaValue

        let duration: Double = 0.20
        let startTime = CACurrentMediaTime()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(1.0, max(0.0, elapsed / duration))
            let eased = self.easeInOutCubic(CGFloat(progress))

            let currentY = startY + (6.0 * eased)
            self.panel.setFrame(NSRect(x: currentFrame.origin.x, y: currentY, width: currentFrame.width, height: currentFrame.height), display: false)
            self.panel.alphaValue = startAlpha * (1.0 - eased)

            if progress >= 1.0 {
                timer.invalidate()
                self.transitionTimer = nil
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1.0
                self.targetFrame = .zero
                self.state = .closed
                completion?()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        transitionTimer = timer
    }

    func hideInstantly() {
        transitionTimer?.invalidate()
        transitionTimer = nil
        targetFrame = .zero
        panel.orderOut(nil)
        panel.alphaValue = 1.0
        state = .closed
    }

    // Apple Cubic Ease-In-Out: smooth acceleration and deceleration
    private func easeInOutCubic(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 4.0 * t * t * t
        } else {
            let f = (2.0 * t) - 2.0
            return 0.5 * f * f * f + 1.0
        }
    }
}

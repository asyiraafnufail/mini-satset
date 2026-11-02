import AppKit
import QuartzCore

protocol PanelControllerDelegate: AnyObject {
    func panelControllerMouseEnter(_ controller: PanelController)
    func panelControllerMouseExit(_ controller: PanelController)
    func panelControllerDidRequestClose(_ controller: PanelController)
}

final class TrackingVisualEffectView: NSVisualEffectView {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
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
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.cgColor
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

final class PanelController: NSObject, FloatingPanelDelegate, PageIndicatorViewDelegate {
    weak var delegate: PanelControllerDelegate?

    private let panel: FloatingPanel
    private let visualEffectView = TrackingVisualEffectView()
    private let pageIndicator = PageIndicatorView(frame: NSRect(x: 0, y: 294, width: 320, height: 38))
    private let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 292))

    private let shelfVC = ShelfViewController()
    private let networkVC = NetworkViewController()
    private let colorSamplerVC = ColorSamplerViewController()

    private lazy var pages: [NSViewController] = [shelfVC, networkVC, colorSamplerVC]
    private(set) var activePageIndex: Int = 0
    private var isSwitchingPage: Bool = false

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

    var currentFrame: NSRect {
        return panel.frame
    }

    override init() {
        let contentRect = NSRect(x: 0, y: 0, width: 320, height: 332)
        self.panel = FloatingPanel(contentRect: contentRect)
        super.init()

        panel.panelDelegate = self
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

        let separator = NSBox(frame: NSRect(x: 0, y: 293, width: 320, height: 1))
        separator.boxType = .separator

        visualEffectView.addSubview(pageIndicator)
        visualEffectView.addSubview(separator)
        visualEffectView.addSubview(containerView)

        panel.contentView = visualEffectView
    }

    // MARK: - FloatingPanelDelegate

    func floatingPanelDidRequestClose(_ panel: FloatingPanel) {
        delegate?.panelControllerDidRequestClose(self)
    }

    // MARK: - Page Indicator Delegate

    func pageIndicator(_ indicator: PageIndicatorView, didSelectPageAt index: Int) {
        guard index != activePageIndex, !isSwitchingPage else { return }
        switchPage(to: index)
    }

    private func switchPage(to newIndex: Int) {
        guard newIndex >= 0 && newIndex < pages.count, !isSwitchingPage else { return }
        isSwitchingPage = true

        let oldVC = pages[activePageIndex]
        let newVC = pages[newIndex]
        let isMovingRight = newIndex > activePageIndex
        activePageIndex = newIndex

        newVC.view.frame = containerView.bounds
        containerView.addSubview(newVC.view)

        let offset: CGFloat = isMovingRight ? 24 : -24
        newVC.view.frame.origin.x = offset
        newVC.view.alphaValue = 0.0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
            oldVC.view.animator().alphaValue = 0.0
            oldVC.view.animator().frame.origin.x = -offset
            newVC.view.animator().alphaValue = 1.0
            newVC.view.animator().frame.origin.x = 0
        } completionHandler: { [weak self] in
            oldVC.view.removeFromSuperview()
            oldVC.view.frame.origin.x = 0
            oldVC.view.alphaValue = 1.0
            self?.isSwitchingPage = false
        }
    }

    private func displayPage(at index: Int, animated: Bool) {
        activePageIndex = index
        pageIndicator.selectTab(at: index, notify: false)
        containerView.subviews.forEach { $0.removeFromSuperview() }
        let currentVC = pages[index]
        currentVC.view.frame = containerView.bounds
        containerView.addSubview(currentVC.view)
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
        let targetY = screen.visibleFrame.maxY - panelHeight - 6

        let finalFrame = NSRect(x: originX, y: targetY, width: panelWidth, height: panelHeight)
        let startY = targetY + 8.0

        panel.setFrame(NSRect(x: originX, y: startY, width: panelWidth, height: panelHeight), display: false)
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()

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

            let currentY = startY - (8.0 * eased)
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

            let currentY = startY + (8.0 * eased)
            self.panel.setFrame(NSRect(x: currentFrame.origin.x, y: currentY, width: currentFrame.width, height: currentFrame.height), display: false)
            self.panel.alphaValue = startAlpha * (1.0 - eased)

            if progress >= 1.0 {
                timer.invalidate()
                self.transitionTimer = nil
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1.0
                self.state = .closed
                completion?()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        transitionTimer = timer
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

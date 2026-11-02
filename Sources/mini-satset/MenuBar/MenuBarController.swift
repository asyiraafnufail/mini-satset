import AppKit

final class MenuBarController: NSObject, MenuBarViewDelegate, PanelControllerDelegate {
    private var statusItem: NSStatusItem!
    private let menuBarView = MenuBarView()
    private let panelController = PanelController()

    private var hoverCheckTimer: Timer?

    override init() {
        super.init()
        setupStatusItem()
        menuBarView.delegate = self
        panelController.delegate = self
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 68)

        if let button = statusItem.button {
            button.title = ""
            button.image = nil
            menuBarView.frame = NSRect(x: 0, y: 0, width: 68, height: button.bounds.height)
            menuBarView.autoresizingMask = [.width, .height]
            button.addSubview(menuBarView)
        }
    }

    // MARK: - MenuBarViewDelegate

    func menuBarViewDidTriggerExpand(_ view: MenuBarView) {
        openPanel()
    }

    func menuBarViewDidTriggerExit(_ view: MenuBarView) {
        // Position checking handled by active hover monitor
    }

    func menuBarViewDidClickToggle(_ view: MenuBarView) {
        if panelController.isVisible {
            dismissAll()
        } else {
            openPanel()
        }
    }

    func menuBarViewDidRequestQuit(_ view: MenuBarView) {
        NSApplication.shared.terminate(nil)
    }

    func menuBarViewDidTriggerDragExpand(_ view: MenuBarView) {
        openPanel()
    }

    func menuBarView(_ view: MenuBarView, didDropFiles urls: [URL]) {
        if panelController.activePageIndex == 1, let first = urls.first {
            panelController.addFileToConverter(first)
        } else {
            panelController.addFilesToShelf(urls)
        }
        openPanel()
    }

    // MARK: - PanelControllerDelegate

    func panelControllerMouseEnter(_ controller: PanelController) {}
    func panelControllerMouseExit(_ controller: PanelController) {}

    func panelControllerDidRequestClose(_ controller: PanelController) {
        dismissAll()
    }

    // MARK: - Open / Dismiss Coordination

    private func openPanel() {
        guard !panelController.isVisible else { return }
        menuBarView.setHighlight(true, animated: true)
        panelController.show(relativeTo: menuBarView)
        startHoverCheck()
    }

    private func dismissAll() {
        stopHoverCheck()
        menuBarView.setHighlight(false, animated: true)
        panelController.hide()
    }

    // MARK: - Active Hover Monitor (Zero Delay on Exit, Zero CPU when Idle)

    private func startHoverCheck() {
        hoverCheckTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkMouseZone()
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverCheckTimer = timer
    }

    private func stopHoverCheck() {
        hoverCheckTimer?.invalidate()
        hoverCheckTimer = nil
    }

    private func checkMouseZone() {
        guard panelController.isVisible else {
            stopHoverCheck()
            return
        }

        let mousePos = NSEvent.mouseLocation

        guard let buttonWindow = menuBarView.window else {
            dismissAll()
            return
        }

        let buttonBounds = menuBarView.bounds
        let buttonScreenRect = buttonWindow.convertToScreen(menuBarView.convert(buttonBounds, to: nil))
        let panelFrame = panelController.currentFrame

        // Combined bounding area bridging menu bar icon down to the panel with 8pt margin
        let minX = min(buttonScreenRect.minX, panelFrame.minX) - 8
        let maxX = max(buttonScreenRect.maxX, panelFrame.maxX) + 8
        let minY = min(buttonScreenRect.minY, panelFrame.minY) - 8
        let maxY = max(buttonScreenRect.maxY, panelFrame.maxY) + 8

        let activeZone = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        if !activeZone.contains(mousePos) {
            dismissAll()
        }
    }
}

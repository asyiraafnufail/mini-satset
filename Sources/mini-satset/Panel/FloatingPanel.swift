import AppKit

protocol FloatingPanelDelegate: AnyObject {
    func floatingPanelDidRequestClose(_ panel: FloatingPanel)
}

final class FloatingPanel: NSPanel {
    weak var panelDelegate: FloatingPanelDelegate?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return false
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            if !isKeyWindow {
                makeKey()
            }
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        panelDelegate?.floatingPanelDidRequestClose(self)
    }
}

import AppKit
import SwiftUI

// NotchPanel: NSPanel subclass so .nonactivatingPanel styleMask is valid.
class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class NotchWindowController: NSWindowController {
    static let shared = NotchWindowController()

    private let windowWidth: CGFloat = 900
    private let windowHeight: CGFloat = 400

    var isExpanded: Bool = false

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let x = (screen.frame.width - windowWidth) / 2
        let y = screen.frame.maxY - windowHeight

        let window = NotchPanel(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.worksWhenModal = false
        window.becomesKeyOnlyIfNeeded = true

        // Base level: screenSaver ensures we stay on top of everything.
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false // We handle click-through via hitTest
        window.sharingType = .none // Prevents appearing in screenshots/screen recordings

        super.init(window: window)
        window.orderFrontRegardless()

        // Register with CGSSpace for multi-desktop support
        NotchSpaceManager.shared.space.windows.insert(window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

import AppKit
import SwiftUI

// NotchPanel: NSPanel subclass so .nonactivatingPanel styleMask is valid.
// NSWindow rejects 0x80 at runtime — NSPanel is the correct base class.
class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class NotchWindowController: NSWindowController {
    static let shared = NotchWindowController()

    private let windowWidth: CGFloat = 740
    private let windowHeight: CGFloat = 240

    var isExpanded: Bool = false

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let x = (screen.frame.width - windowWidth) / 2
        let y = screen.frame.maxY - windowHeight

        // .nonactivatingPanel requires NSPanel (not NSWindow) — valid here.
        // Prevents the overlay from stealing keyboard focus when the user hovers it.
        let window = NotchPanel(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.worksWhenModal = false
        window.becomesKeyOnlyIfNeeded = true

        // Base level: screenSaver keeps us above normal apps.
        // The CGSSpace (added below) composites at Int32.max ABOVE this,
        // so the window is always drawn over the space-switching animation.
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        // .stationary prevents Exposé/Mission Control from moving the window.
        // We deliberately omit .canJoinAllSpaces — the CGSSpace handles
        // making the window appear on all spaces without the duplicate-render bug.
        window.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false

        super.init(window: window)
        window.orderFrontRegardless()

        // Register with CGSSpace AFTER the window has a valid windowNumber.
        NotchSpaceManager.shared.space.windows.insert(window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

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
    private let windowHeight: CGFloat = 800

    var isExpanded: Bool = false

    init() {
        let window = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        reposition()
        
        window.worksWhenModal = false
        window.becomesKeyOnlyIfNeeded = true

        // Base level: screenSaver ensures we stay on top of everything.
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false // We handle click-through via hitTest
        window.sharingType = .none // Prevents appearing in screenshots/screen recordings

        window.orderFrontRegardless()

        NotificationCenter.default.addObserver(self, selector: #selector(reposition), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        
        // Register with CGSSpace for multi-desktop support
        NotchSpaceManager.shared.space.windows.insert(window)
    }

    @objc func reposition() {
        guard let window = window else { return }
        // Find the screen with the menu bar (the one with origin 0,0 usually, or use NSScreen.screens[0])
        // Or use the one where the window currently is, but for a notch app, screen 0 is best.
        let screen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main ?? NSScreen.screens[0]
        
        let x = screen.frame.origin.x + (screen.frame.width - windowWidth) / 2
        let y = screen.frame.origin.y + screen.frame.height - windowHeight
        
        window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

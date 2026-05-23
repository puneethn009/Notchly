import AppKit
import SwiftUI
import SwiftData

class NotchlyHubWindowController: NSWindowController {
    static let shared = NotchlyHubWindowController()
    
    func show() {
        if let window = self.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let container = PersistenceController.shared.container
        let view = NotchlyHubView()
            .modelContainer(container)
        
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Notchly Hub"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 900, height: 620)
        
        // Assign hosting controller directly — the VisualEffectView backing
        // lives inside SwiftUI (ZStack root layer) where it auto-sizes correctly.
        // This avoids the 0×0 frame bug from using visualEffectView.bounds before layout.
        window.contentViewController = hostingController
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

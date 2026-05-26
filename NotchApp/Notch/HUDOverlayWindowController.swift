import AppKit
import SwiftUI

class HUDOverlayWindowController {
    static let shared = HUDOverlayWindowController()
    private var window: NSWindow?
    
    private init() {
        setupWindow()
    }
    
    private func setupWindow() {
        let view = HUDExpandedView()
        let hostingController = NSHostingController(rootView: view)
        
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let windowHeight: CGFloat = 60
        let windowRect = NSRect(x: screenRect.midX - 150, y: screenRect.maxY - windowHeight, width: 300, height: windowHeight)
        
        let overlayWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.hasShadow = false
        overlayWindow.level = .screenSaver // High level, above menu bar
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        overlayWindow.contentViewController = hostingController
        
        self.window = overlayWindow
        overlayWindow.orderFront(nil)
    }
    
    func start() {
        // Just ensuring it's initialized
        _ = window
    }
}

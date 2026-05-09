import AppKit
import SwiftUI


// Intercepts clicks ONLY inside the actual notch UI bounds.
// Everything outside passes through to the macOS menu bar below.
class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    private var hoverTimer: Timer?

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        startHoverTracking()
    }

    @MainActor required init(rootView: Content) {
        super.init(rootView: rootView)
        startHoverTracking()
    }

    private func startHoverTracking() {
        // Run at 60fps (0.016s) to ensure smooth detection
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }
        RunLoop.current.add(hoverTimer!, forMode: .common)
    }

    private func checkMousePosition() {
        if let delegate = NSApp.delegate as? AppDelegate,
           let settings = delegate.settingsWindow, 
           settings.isKeyWindow { return }

        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.main ?? NSScreen.screens[0]
        
        let notchH = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 37.0
        let notchW = NotchOverlayView.hardwareNotchWidth(for: screen)
        
        // The screen origin is bottom-left
        let screenMidX = screen.frame.midX
        let screenMaxY = screen.frame.maxY
        
        // Define the global rect for the hardware notch
        let notchRect = NSRect(
            x: screenMidX - (notchW / 2.0),
            y: screenMaxY - notchH,
            width: notchW,
            height: notchH
        )
        
        let isExpanded = NotchState.shared.isExpanded
        
        if isExpanded {
            // When expanded, keep it open as long as the mouse is within the expanded area
            let expandedRect = NSRect(
                x: screenMidX - (680.0 / 2.0),
                y: screenMaxY - 180.0,
                width: 680.0,
                height: 180.0
            )
            if !expandedRect.contains(mouseLoc) {
                updateExpansion(false)
            }
        } else {
            // When collapsed, expand only if hitting the hardware notch
            if notchRect.contains(mouseLoc) {
                updateExpansion(true)
            }
        }
    }

    private func updateExpansion(_ expanded: Bool) {
        if NotchState.shared.isExpanded != expanded {
            print("[Hover] Changing expansion to: \(expanded)")
            DispatchQueue.main.async {
                NotchState.shared.isExpanded = expanded
                NotchWindowController.shared.isExpanded = expanded
            }
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let isExpanded = NotchWindowController.shared.isExpanded
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let notchH = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 37.0
        let notchW = NotchOverlayView.hardwareNotchWidth(for: screen)

        let hitWidth: CGFloat  = isExpanded ? 680 : notchW
        let hitHeight: CGFloat = isExpanded ? 180 : notchH

        let x = (740.0 - hitWidth) / 2.0
        let y = 240.0 - hitHeight
        let hitRect = NSRect(x: x, y: y, width: hitWidth, height: hitHeight)

        return hitRect.contains(point) ? super.hitTest(point) : nil
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupMenuBar()

        NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenSettings"), object: nil, queue: .main) { [weak self] _ in
            self?.openSettings(nil)
        }

        _ = NotchWindowController.shared

        if let window = NotchWindowController.shared.window {
            let hostingView = PassThroughHostingView(rootView: NotchOverlayView())
            hostingView.frame = NSRect(x: 0, y: 0, width: 740, height: 240)
            // Prevent NSHostingView from resizing itself and triggering layout recursion
            hostingView.autoresizingMask = [] 
            window.contentView = hostingView
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotchSpaceManager.shared.tearDown()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "menubar.rectangle",
                                   accessibilityDescription: "NotchApp")
        }

        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit NotchApp",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    var settingsWindow: NSWindow? {
        // Find the SwiftUI settings window if it exists
        return NSApp.windows.first(where: { $0.title == "NotchApp Settings" || $0.title == "Settings" })
    }

    @objc func openSettings(_ sender: Any?) {
        print("[AppDelegate] openSettings() called")
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            
            // Try macOS 13+ Settings Window
            if #available(macOS 13.0, *) {
                NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)
            } else {
                // Try macOS 12 and older Preferences Window
                NSApp.sendAction(Selector("showPreferencesWindow:"), to: nil, from: nil)
            }
        }
    }
}

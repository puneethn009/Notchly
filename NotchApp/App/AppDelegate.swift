import SwiftUI
import AppKit

class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    private var timer: Timer?

    required init(rootView: Content) {
        super.init(rootView: rootView)
        startHoverTimer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        startHoverTimer()
    }

    private func startHoverTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }
    }

    private func checkMousePosition() {
        if let delegate = NSApp.delegate as? AppDelegate,
           let settings = delegate.settingsWindow, 
           settings.isKeyWindow { 
            delegate.syncWindowLevel()
            return 
        }
        
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.syncWindowLevel()
        }

        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.main ?? NSScreen.screens[0]
        
        let notchH = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 37.0
        let notchW = NotchOverlayView.hardwareNotchWidth(for: screen)
        let screenMidX = screen.frame.midX
        let screenMaxY = screen.frame.maxY
        
        let collapsedRect = NSRect(
            x: screenMidX - (220.0 / 2.0),
            y: screenMaxY - 45.0,
            width: 220.0,
            height: 50.0
        )
        
        let isExpanded = NotchState.shared.isExpanded
        
        if isExpanded {
            let expandedRect = NSRect(
                x: screenMidX - (700.0 / 2.0),
                y: screenMaxY - 200.0,
                width: 700.0,
                height: 200.0
            )
            if !expandedRect.contains(mouseLoc) && !TimerManager.shared.isAlarmPlaying {
                updateExpansion(false)
            }
        } else {
            if collapsedRect.contains(mouseLoc) {
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
        let isExpanded = NotchState.shared.isExpanded
        let isSticky = NotchState.shared.isSticky
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let notchH = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 37.0
        let notchW = NotchOverlayView.hardwareNotchWidth(for: screen)

        // Calculate hit area in the 900x400 view (bottom-left origin)
        var hitWidth: CGFloat = notchW
        var hitHeight: CGFloat = notchH
        
        if isExpanded {
            hitWidth = 700
            hitHeight = 200
        } else if isSticky {
            hitWidth = 340
            hitHeight = 44
        } else {
            hitWidth = 200
            hitHeight = 37
        }

        let x = (900.0 - hitWidth) / 2.0
        let y = 400.0 - hitHeight
        
        // Add a small 2px buffer to the hit area to make it easier to click
        let hitRect = NSRect(x: x - 2, y: y - 2, width: hitWidth + 4, height: hitHeight + 4)

        // Bypass if settings is active to allow moving the window
        let delegate = NSApp.delegate as? AppDelegate
        if let settings = delegate?.settingsWindow, settings.isVisible && settings.isKeyWindow {
            return nil
        }
        
        if hitRect.contains(point) {
            return super.hitTest(point)
        }
        return nil
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupMenuBar()
        
        if let window = NotchWindowController.shared.window {
            let hostingView = PassThroughHostingView(rootView: NotchOverlayView())
            hostingView.frame = NSRect(x: 0, y: 0, width: 900, height: 400)
            hostingView.autoresizingMask = [] // Stay at 900x400
            window.contentView = hostingView
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotchSpaceManager.shared.tearDown()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: "Notchly")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Notchly", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    var settingsWindow: NSWindow? {
        return NSApp.windows.first(where: { 
            $0.title.contains("Settings") || $0.title.contains("Notchly") || $0.title.contains("NotchApp") 
        })
    }

    func syncWindowLevel() {
        DispatchQueue.main.async {
            let window = NotchWindowController.shared.window
            if let settings = self.settingsWindow, settings.isVisible && settings.isKeyWindow {
                window?.level = .normal
                window?.ignoresMouseEvents = true
            } else {
                window?.level = .screenSaver
                window?.ignoresMouseEvents = false
            }
        }
    }

    @objc func openSettings(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        let appMenu = NSApp.mainMenu?.item(at: 0)?.submenu
        let settingsItem = appMenu?.items.first(where: { 
            $0.action == Selector(("showSettingsWindow:")) || $0.title.contains("Settings")
        })
        
        if let item = settingsItem {
            item.target?.perform(item.action, with: item)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        self.syncWindowLevel()
    }
}

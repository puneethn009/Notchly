import SwiftUI
import AppKit
import SwiftData

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
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main ?? NSScreen.screens[0]
        let screenMidX = screen.frame.midX
        let screenMaxY = screen.frame.maxY
        
        let isExpanded = NotchState.shared.isExpanded
        let isSticky = NotchState.shared.isSticky
        
        // Match the hitTest logic for consistency
        let collapsedW: CGFloat = 192
        let expandedW: CGFloat = 700
        let stickyW: CGFloat = 300
        let flareSize: CGFloat = 8
        
        var currentWidth = isExpanded ? expandedW : (isSticky ? stickyW : collapsedW)
        currentWidth += (flareSize * 2)
        
        let isRunning = MediaPlayerManager.shared.isPlaying || TimerManager.shared.isRunning || TimerManager.shared.isStopwatchRunning
        let currentHeight = isExpanded ? 200.0 : (isSticky ? 34.0 : (isRunning ? 32.0 : 31.0))
        
        let notchRect = NSRect(
            x: screenMidX - (currentWidth / 2.0),
            y: screenMaxY - currentHeight,
            width: currentWidth,
            height: currentHeight
        )
        
        // Dynamic Interactivity Toggle
        // We add a small buffer (5px) to make the re-activation feel smoother
        let interactionRect = notchRect.insetBy(dx: -5, dy: -5)
        let isInside = interactionRect.contains(mouseLoc)
        let window = NotchWindowController.shared.window
        
        // If settings is active, we must allow interaction to move the window
        let settingsActive = (NSApp.delegate as? AppDelegate)?.settingsWindow?.isVisible ?? false
        
        if isInside || settingsActive {
            window?.ignoresMouseEvents = false
        } else {
            window?.ignoresMouseEvents = true
        }
        
        if isExpanded {
            // Prevent auto-collapse if mouse is outside AND NO screenshot is pending
            if !isInside && !TimerManager.shared.isAlarmPlaying && NotchState.shared.pendingScreenshotURL == nil {
                updateExpansion(false)
            }
        } else {
            if isInside {
                updateExpansion(true)
            }
        }
    }

    private func updateExpansion(_ expanded: Bool) {
        let state = NotchState.shared
        
        if expanded {
            if !state.isHovering && !state.isExpanded {
                print("[Hover] Stage 1: Shadow")
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.15)) {
                        state.isHovering = true
                    }
                }
                
                // Stage 2: Expand after snappy delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if state.isHovering && !state.isExpanded {
                        print("[Hover] Stage 2: Expand")
                        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45)) {
                            state.isExpanded = true
                            NotchWindowController.shared.isExpanded = true
                        }
                    }
                }
            }
        } else {
            if state.isHovering || state.isExpanded {
                print("[Hover] Collapse")
                DispatchQueue.main.async {
                    withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.4)) {
                        state.isHovering = false
                        state.isExpanded = false
                        NotchWindowController.shared.isExpanded = false
                    }
                }
            }
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Since we now use window.ignoresMouseEvents for global click-through,
        // we can simplify hitTest to just return super if we are interactive.
        return super.hitTest(point)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupMenuBar()
        
        if let window = NotchWindowController.shared.window {
            let rootView = NotchOverlayView()
                .modelContainer(PersistenceController.shared.container)
            
            let hostingView = PassThroughHostingView(rootView: rootView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 900, height: 400)
            hostingView.autoresizingMask = []
            window.contentView = hostingView
            
            // Initialize Capture Manager
            CaptureManager.shared.setup()
            CaptureManager.shared.disableNativeThumbnails()
            
            // Start screenshot monitoring with persistence
            ScreenshotMonitor.shared.start(container: PersistenceController.shared.container)
            
            // Start Media Manager with a slight delay to ensure UI stability
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MediaPlayerManager.shared.start()
            }
            
            // Open the Notchly Hub as the main app window
            NotchlyHubWindowController.shared.show()
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
        // Window level management is now handled dynamically in checkMousePosition
    }

    @objc func openSettings(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        let appMenu = NSApp.mainMenu?.item(at: 0)?.submenu
        let settingsItem = appMenu?.items.first(where: { 
            $0.action == Selector(("showSettingsWindow:")) || $0.title.contains("Settings")
        })
        
        if let item = settingsItem {
            _ = item.target?.perform(item.action, with: item)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotchlyHubWindowController.shared.show()
        }
        return true
    }

    private func openEditorCanvas() {
        let container = PersistenceController.shared.container
        let context = container.mainContext
        
        var targetURL = URL(fileURLWithPath: "/dev/null") // fallback
        
        let descriptor = FetchDescriptor<ScreenshotItem>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        if let latestItem = try? context.fetch(descriptor).first {
            targetURL = URL(fileURLWithPath: latestItem.filePath)
        }
        
        ScreenshotEditorWindowController.shared.open(with: targetURL)
    }
}

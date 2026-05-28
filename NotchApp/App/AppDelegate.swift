import SwiftUI
import SwiftData
import AppKit
import Sparkle

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
    
    deinit {
        timer?.invalidate()
        timer = nil
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
        let currentHeight = isExpanded ? (200.0 + NotchState.shared.extraHeight) : (isSticky ? 34.0 : (isRunning ? 32.0 : 31.0))
        
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
            // Don't auto-collapse when a game is actively playing — player needs the notch to stay open.
            // The game provides its own explicit X button to close.
            let gameIsActive = NotchState.shared.selectedPage == .game && NotchState.shared.activeGame != nil
            if !isInside && !TimerManager.shared.isAlarmPlaying && NotchState.shared.pendingScreenshotURL == nil && !gameIsActive {
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
    var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        AppDelegate.shared = self
        setupMenuBar()
        
        if let window = NotchWindowController.shared.window {
            let rootView = NotchOverlayView()
                .modelContainer(PersistenceController.shared.container)
            
            let hostingView = PassThroughHostingView(rootView: rootView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 900, height: 800)
            hostingView.autoresizingMask = []
            window.contentView = hostingView
            
            // Initialize Capture Manager
            CaptureManager.shared.setup()
            CaptureManager.shared.disableNativeThumbnails()
            
            // Start monitors
            ScreenshotMonitor.shared.start(container: PersistenceController.shared.container)
            ClipboardMonitor.shared.start()
            // Start Media Manager with a slight delay to ensure UI stability
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MediaPlayerManager.shared.start()
            }
            
            // Check Accessibility permission for global hotkeys
            checkAccessibilityPermission()
            
            // Open the Notchly Hub window automatically on launch
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
        menu.addItem(NSMenuItem(title: "Open Notchly Hub", action: #selector(openHub), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        
        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)
        
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

    @objc func openHub() {
        NotchlyHubWindowController.shared.show()
    }

    @objc func openSettings(_ sender: Any?) {
        NotchlyHubWindowController.shared.show()
    }

    /// Check Accessibility permission needed for global hotkeys.
    /// If not granted, prompt user once and show a non-blocking alert.
    private func checkAccessibilityPermission() {
        // Use the Options dictionary to prompt the system to add the app to the list
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        guard !isTrusted else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let alert = NSAlert()
            alert.messageText = "Accessibility Access Needed"
            alert.informativeText = "Notchly needs Accessibility permission to enable global screenshot hotkeys (⌥⇧3 / ⌥⇧4).\n\nGo to System Settings → Privacy & Security → Accessibility and enable Notchly."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
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

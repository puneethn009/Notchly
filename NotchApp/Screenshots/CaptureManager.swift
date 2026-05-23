import Foundation
import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let takeFullScreen = Self("takeFullScreen", default: .init(.three, modifiers: [.option, .shift]))
    static let takeSelection = Self("takeSelection", default: .init(.four, modifiers: [.option, .shift]))
}

class CaptureManager {
    static let shared = CaptureManager()
    
    func setup() {
        KeyboardShortcuts.onKeyUp(for: .takeFullScreen) { [weak self] in
            self?.capture(type: .fullScreen)
        }
        
        KeyboardShortcuts.onKeyUp(for: .takeSelection) { [weak self] in
            self?.capture(type: .selection)
        }
    }
    
    enum CaptureType {
        case fullScreen, selection
    }
    
    private func capture(type: CaptureType) {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "Notchly_Capture_\(Int(Date().timeIntervalSince1970)).png"
        let tempURL = tempDir.appendingPathComponent(filename)
        
        // Use screencapture CLI
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        var arguments: [String] = []
        if type == .selection {
            arguments.append("-i") // Interactive / Selection
        }
        arguments.append("-x") // No sound (optional, keeps it premium/silent)
        arguments.append(tempURL.path)
        
        task.arguments = arguments
        
        task.terminationHandler = { process in
            if process.terminationStatus == 0 {
                // Success!
                DispatchQueue.main.async {
                    // Move to pending dir so it's consistent with our monitor
                    self.moveToPendingAndShow(url: tempURL)
                }
            }
        }
        
        // Hide notch window before capture if full screen
        if type == .fullScreen {
            NotchWindowController.shared.window?.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                task.launch()
            }
        } else {
            task.launch()
        }
    }
    
    private func moveToPendingAndShow(url: URL) {
        let docs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        let pendingDir = docs.appendingPathComponent("Notchly/Screenshots/.pending", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)
        let destinationURL = pendingDir.appendingPathComponent(url.lastPathComponent)
        
        do {
            try FileManager.default.moveItem(at: url, to: destinationURL)
            ScreenshotPreviewController.shared.showPreview(for: destinationURL)
            
            // Show notch window back
            NotchWindowController.shared.window?.orderFrontRegardless()
        } catch {
            print("[CaptureManager] Error moving capture: \(error)")
        }
    }
    
    func disableNativeThumbnails() {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["write", "com.apple.screencapture", "show-thumbnail", "-bool", "FALSE"]
        task.launch()
        
        let locTask = Process()
        locTask.launchPath = "/usr/bin/defaults"
        let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
        locTask.arguments = ["write", "com.apple.screencapture", "location", desktopPath]
        locTask.launch()
        
        // Restart SystemUIServer to apply (optional, but recommended)
        let killTask = Process()
        killTask.launchPath = "/usr/bin/killall"
        killTask.arguments = ["SystemUIServer"]
        killTask.launch()
    }
}

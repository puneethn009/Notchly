import SwiftUI
import AppKit
import Combine

class LauncherManager: ObservableObject {
    private let defaultsKey = "pinned_launcher_apps"
    
    init() {
        // We now use SettingsManager for source of truth
    }
    
    var apps: [DockApp] {
        return SettingsManager.shared.dockApps
    }
    
    func loadApps() {
        // No-op, managed by SettingsManager
    }
    
    func saveApps() {
        // No-op, managed by SettingsManager
    }
    
    func launch(bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        }
    }
    
    func icon(for bundleID: String) -> NSImage? {
        if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }
}

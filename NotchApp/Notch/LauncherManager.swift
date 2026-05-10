import SwiftUI
import AppKit
import Combine

struct LauncherApp: Identifiable, Codable {
    let id: String // Bundle ID
    let name: String
}

class LauncherManager: ObservableObject {
    @Published var apps: [LauncherApp] = []
    
    private let defaultsKey = "pinned_launcher_apps"
    
    init() {
        loadApps()
        if apps.isEmpty {
            // Default apps
            apps = [
                LauncherApp(id: "com.apple.Safari", name: "Safari"),
                LauncherApp(id: "com.apple.mail", name: "Mail"),
                LauncherApp(id: "com.apple.iCal", name: "Calendar"),
                LauncherApp(id: "com.apple.Music", name: "Music"),
                LauncherApp(id: "com.apple.Terminal", name: "Terminal")
            ]
            saveApps()
        }
    }
    
    func loadApps() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([LauncherApp].self, from: data) {
            apps = decoded
        }
    }
    
    func saveApps() {
        if let encoded = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
    
    func launch(bundleID: String) {
        NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleID, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil)
    }
    
    func icon(for bundleID: String) -> NSImage? {
        if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }
}

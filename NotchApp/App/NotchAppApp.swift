import SwiftUI

@main
struct NotchAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        UserDefaults.standard.register(defaults: [
            "enableAppleMusic": true,
            "enableSpotify": true,
            "showNowPlaying": true
        ])
    }

    var body: some Scene {
        // SwiftUI's built-in Settings scene.
        // Opened via: NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)
        Settings {
            SettingsView()
        }
    }
}

import SwiftUI
import SwiftData

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
        Settings {
            SettingsView()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}

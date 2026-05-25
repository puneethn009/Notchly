import SwiftUI
import SwiftData

@main
struct NotchAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate


    var body: some Scene {
        Settings {
            SettingsView()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}

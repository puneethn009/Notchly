import SwiftUI
import SwiftData

@main
struct NotchAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate


    var body: some Scene {
        Settings {
            EmptyView()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}

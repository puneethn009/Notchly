import SwiftUI

struct SettingsView: View {
    @AppStorage("enableMedia") private var enableMedia: Bool = true
    @AppStorage("enableTimer") private var enableTimer: Bool = true
    @AppStorage("enableSystem") private var enableSystem: Bool = true
    @AppStorage("enableCalendar") private var enableCalendar: Bool = true
    @AppStorage("enableLauncher") private var enableLauncher: Bool = true

    var body: some View {
        TabView {
            Form {
                Section(header: Text("Productivity Modules")) {
                    Toggle("Media Dashboard", isOn: $enableMedia)
                    Toggle("Quick Timer / Pomodoro", isOn: $enableTimer)
                    Toggle("System Monitor", isOn: $enableSystem)
                    Toggle("Calendar & Events", isOn: $enableCalendar)
                    Toggle("App Launcher (Dock)", isOn: $enableLauncher)
                }
            }
            .padding()
            .tabItem { Label("Modules", systemImage: "square.grid.2x2") }

            Form {
                Section(header: Text("Media Sources")) {
                    Toggle("Apple Music", isOn: .constant(true))
                    Toggle("Spotify", isOn: .constant(true))
                }
            }
            .padding()
            .tabItem { Label("Media", systemImage: "play.circle") }

            VStack(spacing: 12) {
                Image(systemName: "n.square.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                Text("Notchly Productivity Hub").font(.title.bold())
                Text("Version 1.2.0").foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 350)
    }
}

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

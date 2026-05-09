import SwiftUI

struct SettingsView: View {
    @AppStorage("enableAppleMusic") private var enableAppleMusic: Bool = true
    @AppStorage("enableSpotify") private var enableSpotify: Bool = true
    @AppStorage("showNowPlaying") private var showNowPlaying: Bool = true

    var body: some View {
        TabView {
            Form {
                Section(header: Text("Startup")) {
                    Toggle("Launch at login", isOn: .constant(true))
                        .disabled(true)
                }
            }
            .padding()
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section(header: Text("Media Sources")) {
                    Text("Select which applications NotchApp should monitor for Now Playing data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    Toggle("Apple Music", isOn: $enableAppleMusic)
                    Toggle("Spotify", isOn: $enableSpotify)
                }
                Section(header: Text("Notch UI")) {
                    Toggle("Show Now Playing in Notch", isOn: $showNowPlaying)
                }
            }
            .padding()
            .tabItem { Label("Media", systemImage: "play.circle") }

            VStack(spacing: 12) {
                Image(systemName: "n.square.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                Text("NotchApp").font(.title.bold())
                Text("Version 1.0.0").foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 300)
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

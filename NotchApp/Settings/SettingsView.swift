import SwiftUI
import KeyboardShortcuts
import EventKit

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @AppStorage("selectedSettingsTab") private var selection: String = "Music"
    
    var body: some View {
        TabView(selection: $selection) {
            MusicSettingsPage(settings: settings)
                .tabItem {
                    Label("Music", systemImage: "music.note")
                }
                .tag("Music")
            
            TimerSettingsPage(settings: settings)
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
                .tag("Timer")
                
            PerformanceSettingsPage(settings: settings)
                .tabItem {
                    Label("Performance", systemImage: "cpu")
                }
                .tag("Performance")
                
            DockSettingsPage(settings: settings)
                .tabItem {
                    Label("Dock", systemImage: "dock.rectangle")
                }
                .tag("Dock")
                
            ScreenshotSettingsPage()
                .tabItem {
                    Label("Screenshots", systemImage: "camera.viewfinder")
                }
                .tag("Screenshots")

            PermissionsSettingsPage()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
                .tag("Permissions")
        }
        .frame(width: 700, height: 500)
    }
}

struct MusicSettingsPage: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        Form {
            Section("Music Streams") {
                Toggle("Apple Music", isOn: $settings.useAppleMusic)
                Toggle("Spotify", isOn: $settings.useSpotify)
            }
            
            Section("Interface") {
                Toggle("Show Music Indicator in Closed Notch", isOn: $settings.showClosedNotchMusicIndicator)
                Toggle("Show Mute Button", isOn: $settings.showMuteButton)
            }
            
            Text("Select which apps Notchly should monitor for media playback.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .formStyle(.grouped)
        .navigationTitle("Music Settings")
    }
}

struct TimerSettingsPage: View {
    @ObservedObject var settings: SettingsManager
    @State private var newTimerName: String = ""
    @State private var newTimerMinutes: Int = 5
    
    var body: some View {
        VStack {
            Form {
                Section("Preferences") {
                    Toggle("Enable Stopwatch", isOn: $settings.enableStopwatch)
                    Toggle("Show Timer in Closed Notch", isOn: $settings.showClosedNotchTimerIndicator)
                    
                    Picker("Alarm Sound", selection: $settings.selectedAlarmSound) {
                        Text("Glass").tag("Glass")
                        Text("Basso").tag("Basso")
                        Text("Bottle").tag("Bottle")
                        Text("Frog").tag("Frog")
                        Text("Funk").tag("Funk")
                        Text("Hero").tag("Hero")
                        Text("Morse").tag("Morse")
                        Text("Ping").tag("Ping")
                        Text("Pop").tag("Pop")
                        Text("Purr").tag("Purr")
                        Text("Sosumi").tag("Sosumi")
                        Text("Submarine").tag("Submarine")
                        Text("Tink").tag("Tink")
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: 150)
            
            List {
                Section(header: Text("My Timers (\(settings.customTimers.count)/5)")) {
                    ForEach(settings.customTimers) { timer in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(timer.name).font(.headline)
                                Text("\(timer.minutes)m \(timer.seconds)s").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete(perform: settings.customTimers.count > 1 ? { offsets in settings.customTimers.remove(atOffsets: offsets) } : nil)
                }
                if settings.customTimers.count < 5 {
                    Section(header: Text("Add New Timer")) {
                        HStack {
                            TextField("Name (e.g. Tea)", text: $newTimerName)
                            Stepper("\(newTimerMinutes) min", value: $newTimerMinutes, in: 1...120)
                            Button("Add") {
                                let timer = CustomTimer(name: newTimerName.isEmpty ? "Timer" : newTimerName, minutes: newTimerMinutes, seconds: 0)
                                settings.customTimers.append(timer)
                                newTimerName = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newTimerName.isEmpty)
                        }
                    }
                }
            }
        }
        .navigationTitle("Timer Settings")
    }
}

struct PerformanceSettingsPage: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        Form {
            Section("Visible Metrics") {
                Toggle("CPU Usage", isOn: $settings.showCPU)
                Toggle("RAM Usage", isOn: $settings.showRAM)
                Toggle("GPU Usage", isOn: $settings.showGPU)
                Toggle("Disk Usage", isOn: $settings.showDisk)
                Toggle("Network Speed", isOn: $settings.showNetwork)
                Toggle("Thermal Pressure", isOn: $settings.showThermal)
                Toggle("Battery Cycles", isOn: $settings.showBattery)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Performance Settings")
    }
}

struct DockSettingsPage: View {
    @ObservedObject var settings: SettingsManager
    @State private var allApps: [DockApp] = []
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Selected Apps
            List {
                Section("Dock Apps (Drag to reorder - Max 9)") {
                    ForEach(settings.dockApps) { app in
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(app.name)
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: settings.removeApp)
                    .onMove(perform: settings.moveApp)
                }
            }
            .listStyle(.inset)
            .frame(height: 200)
            
            Divider()
            
            // App Picker
            VStack(alignment: .leading) {
                HStack {
                    Text("Add Apps").font(.headline)
                    Spacer()
                    TextField("Search Applications...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                .padding()
                
                ScrollView {
                    LazyVStack {
                        ForEach(filteredApps) { app in
                            HStack {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                Text(app.name)
                                Spacer()
                                Button("Add") {
                                    settings.addApp(app)
                                }
                                .buttonStyle(.bordered)
                                .disabled(settings.dockApps.count >= 9 || settings.dockApps.contains(where: { $0.bundleId == app.bundleId }))
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Dock Settings")
        .onAppear(perform: scanApps)
    }
    
    var filteredApps: [DockApp] {
        if searchText.isEmpty {
            return allApps
        } else {
            return allApps.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    func scanApps() {
        let appDirs = ["/Applications", "/System/Applications"]
        var foundApps: [DockApp] = []
        
        let fileManager = FileManager.default
        for dir in appDirs {
            do {
                let content = try fileManager.contentsOfDirectory(atPath: dir)
                for item in content where item.hasSuffix(".app") {
                    let fullPath = (dir as NSString).appendingPathComponent(item)
                    if let bundle = Bundle(path: fullPath),
                       let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
                       let bundleId = bundle.bundleIdentifier {
                        foundApps.append(DockApp(name: name, bundleId: bundleId, path: fullPath))
                    }
                }
            } catch {
                print("Error scanning \(dir): \(error)")
            }
        }
        allApps = foundApps.sorted { $0.name < $1.name }
    }
}

struct ScreenshotSettingsPage: View {
    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                HStack {
                    Text("Capture Full Screen")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .takeFullScreen)
                }
                HStack {
                    Text("Capture Selection")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .takeSelection)
                }
            }
            
            Text("These shortcuts trigger Notchly's native screenshot capture tool.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .formStyle(.grouped)
        .navigationTitle("Screenshot Settings")
    }
}

// MARK: - Permissions Page

struct PermissionsSettingsPage: View {
    @State private var accessibilityGranted: Bool = false
    @State private var screenRecordingGranted: Bool = false
    @State private var calendarGranted: Bool = false
    @State private var remindersGranted: Bool = false

    var body: some View {
        Form {
            Section("Required Permissions") {
                PermissionRow(
                    title: "Accessibility",
                    subtitle: "Enables global screenshot hotkeys (⌥⇧3 / ⌥⇧4)",
                    icon: "figure.arms.open",
                    granted: accessibilityGranted,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
                PermissionRow(
                    title: "Screen Recording",
                    subtitle: "Required for screenshot capture",
                    icon: "camera.viewfinder",
                    granted: screenRecordingGranted,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                )
            }

            Section("Optional Permissions") {
                PermissionRow(
                    title: "Calendar",
                    subtitle: "Show upcoming events in the notch",
                    icon: "calendar",
                    granted: calendarGranted,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
                )
                PermissionRow(
                    title: "Reminders",
                    subtitle: "Show reminders in the notch calendar view",
                    icon: "checklist",
                    granted: remindersGranted,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Permissions")
        .onAppear(perform: checkPermissions)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions() // Refresh when user returns from System Settings
        }
    }

    private func checkPermissions() {
        accessibilityGranted = AXIsProcessTrusted()
        screenRecordingGranted = CGPreflightScreenCaptureAccess()

        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        calendarGranted = calendarStatus == .fullAccess || calendarStatus.rawValue == 3

        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        remindersGranted = reminderStatus == .fullAccess || reminderStatus.rawValue == 3
    }
}

struct PermissionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let granted: Bool
    let settingsURL: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(granted ? .green : .orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Button("Enable") {
                    if let url = URL(string: settingsURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}

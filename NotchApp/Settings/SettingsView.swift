import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var selection: String? = "Music"
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: "Music") {
                    Label("Music", systemImage: "music.note")
                }
                NavigationLink(value: "Timer") {
                    Label("Timer", systemImage: "timer")
                }
                NavigationLink(value: "Performance") {
                    Label("Performance", systemImage: "cpu")
                }
                NavigationLink(value: "Calendar") {
                    Label("Calendar", systemImage: "calendar")
                }
                NavigationLink(value: "Dock") {
                    Label("Dock", systemImage: "apps.ipad.desktop")
                }
            }
            .navigationTitle("Settings")
        } detail: {
            Group {
                switch selection {
                case "Music":
                    MusicSettingsPage(settings: settings)
                case "Timer":
                    TimerSettingsPage(settings: settings)
                case "Performance":
                    PerformanceSettingsPage(settings: settings)
                case "Calendar":
                    Text("Calendar settings coming soon...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                case "Dock":
                    DockSettingsPage(settings: settings)
                default:
                    Text("Select a page")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
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
            List {
                Section(header: Text("My Timers (\(settings.customTimers.count)/7)")) {
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
                
                if settings.customTimers.count < 7 {
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

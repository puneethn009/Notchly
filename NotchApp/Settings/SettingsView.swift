import SwiftUI
import KeyboardShortcuts
import EventKit
// MARK: - Reusable UI Components

struct SettingsCard<Content: View>: View {
    let title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.leading, 4)
            }
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal, 40)
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    @Binding var isOn: Bool
    var isLast: Bool = false
    
    init(title: String, subtitle: String? = nil, icon: String? = nil, isOn: Binding<Bool>, isLast: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._isOn = isOn
        self.isLast = isLast
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, icon == nil ? 20 : 60)
            }
        }
    }
}

struct SettingsActionRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let buttonTitle: String?
    let buttonIcon: String?
    let action: () -> Void
    var isLast: Bool = false
    var customContent: AnyView? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if let customContent = customContent {
                    customContent
                } else if let buttonTitle = buttonTitle {
                    Button(action: action) {
                        HStack(spacing: 6) {
                            if let buttonIcon = buttonIcon {
                                Image(systemName: buttonIcon)
                            }
                            Text(buttonTitle)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, icon == nil ? 20 : 60)
            }
        }
    }
}


struct MusicSettingsPage: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Music Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 10)
                
                SettingsCard(title: "Music Streams") {
                    SettingsToggleRow(
                        title: "Apple Music",
                        subtitle: "Monitor Apple Music for playback",
                        icon: "music.note",
                        isOn: $settings.useAppleMusic
                    )
                    
                    SettingsToggleRow(
                        title: "Spotify",
                        subtitle: "Monitor Spotify for playback",
                        icon: "play.circle.fill",
                        isOn: $settings.useSpotify,
                        isLast: true
                    )
                }
                
                SettingsCard(title: "Interface") {
                    SettingsToggleRow(
                        title: "Show Music Indicator in Closed Notch",
                        subtitle: "Display a small equalizer animation when music is playing",
                        icon: "waveform",
                        isOn: $settings.showClosedNotchMusicIndicator
                    )
                    
                    SettingsToggleRow(
                        title: "Show Mute Button",
                        subtitle: "Add a quick mute button to the expanded media controls",
                        icon: "speaker.slash.fill",
                        isOn: $settings.showMuteButton,
                        isLast: true
                    )
                }
                
                Text("Select which apps Notchly should monitor for media playback.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                
                Spacer(minLength: 40)
            }
        }
    }
}

struct TimerSettingsPage: View {
    @ObservedObject var settings: SettingsManager
    @State private var newTimerName: String = ""
    @State private var newTimerMinutes: Int = 5
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Timer Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 10)
                
                SettingsCard(title: "Preferences") {
                    SettingsToggleRow(
                        title: "Enable Stopwatch",
                        subtitle: "Allow timing upwards from zero",
                        icon: "stopwatch",
                        isOn: $settings.enableStopwatch
                    )
                    
                    SettingsToggleRow(
                        title: "Show Timer in Closed Notch",
                        subtitle: "Display a small countdown indicator",
                        icon: "timer",
                        isOn: $settings.showClosedNotchTimerIndicator
                    )
                    
                    SettingsActionRow(
                        title: "Alarm Sound",
                        subtitle: "Sound played when timer completes",
                        icon: "speaker.wave.3",
                        buttonTitle: nil,
                        buttonIcon: nil,
                        action: {},
                        isLast: true,
                        customContent: AnyView(
                            Picker("", selection: $settings.selectedAlarmSound) {
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
                            .frame(width: 120)
                        )
                    )
                }
                
                // Custom Timers
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("MY TIMERS (\(settings.customTimers.count)/5)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.leading, 4)
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                    
                    VStack(spacing: 0) {
                        ForEach(settings.customTimers.indices, id: \.self) { index in
                            let timer = settings.customTimers[index]
                            HStack(spacing: 16) {
                                Image(systemName: "timer")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(timer.name)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text("\(timer.minutes)m \(timer.seconds)s")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if settings.customTimers.count > 1 {
                                        settings.customTimers.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.7))
                                        .padding(8)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .disabled(settings.customTimers.count <= 1)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            
                            if index < settings.customTimers.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 40)
                }
                
                if settings.customTimers.count < 5 {
                    SettingsCard(title: "Add New Timer") {
                        HStack(spacing: 16) {
                            TextField("Name (e.g. Tea)", text: $newTimerName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                            
                            HStack(spacing: 8) {
                                Stepper("", value: $newTimerMinutes, in: 1...120)
                                    .labelsHidden()
                                Text("\(newTimerMinutes) min")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 50, alignment: .leading)
                            }
                            
                            Button(action: {
                                let timer = CustomTimer(name: newTimerName.isEmpty ? "Timer" : newTimerName, minutes: newTimerMinutes, seconds: 0)
                                settings.customTimers.append(timer)
                                newTimerName = ""
                            }) {
                                Text("Add")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(newTimerName.isEmpty ? Color.white.opacity(0.1) : Color.blue)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(newTimerName.isEmpty)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
    }
}

struct PerformanceSettingsPage: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Performance Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 10)
                
                SettingsCard(title: "Visible Metrics") {
                    SettingsToggleRow(title: "CPU Usage", icon: "cpu", isOn: $settings.showCPU)
                    SettingsToggleRow(title: "RAM Usage", icon: "memorychip", isOn: $settings.showRAM)
                    SettingsToggleRow(title: "GPU Usage", icon: "display", isOn: $settings.showGPU)
                    SettingsToggleRow(title: "Disk Usage", icon: "internaldrive", isOn: $settings.showDisk)
                    SettingsToggleRow(title: "Network Speed", icon: "network", isOn: $settings.showNetwork)
                    SettingsToggleRow(title: "Thermal Pressure", icon: "thermometer", isOn: $settings.showThermal)
                    SettingsToggleRow(title: "Battery Cycles", icon: "battery.100", isOn: $settings.showBattery, isLast: true)
                }
                
                Spacer(minLength: 40)
            }
        }
    }
}

struct DockSettingsPage: View {
    @ObservedObject var settings: SettingsManager
    @State private var allApps: [DockApp] = []
    @State private var searchText: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Dock Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 10)
                
                // Selected Apps
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("DOCK APPS (Drag to reorder - \(settings.dockApps.count)/9)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.leading, 4)
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                    
                    List {
                        ForEach(settings.dockApps.indices, id: \.self) { index in
                            let app = settings.dockApps[index]
                            HStack(spacing: 16) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                
                                Text(app.name)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    settings.removeApp(at: IndexSet(integer: index))
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.7))
                                        .padding(8)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.white.opacity(0.3))
                                    .padding(.leading, 8)
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .listRowSeparator(.visible)
                            .listRowSeparatorTint(Color.white.opacity(0.1))
                        }
                        .onMove { source, destination in
                            settings.moveApp(from: source, to: destination)
                        }
                        
                        if settings.dockApps.isEmpty {
                            Text("No apps added to Dock")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.vertical, 30)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(height: max(CGFloat(settings.dockApps.count * 50), 100))
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 40)
                }
                
                // Add Apps
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("ADD APPS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.leading, 4)
                        
                        Spacer()
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.4))
                            TextField("Search...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .frame(width: 200)
                    }
                    .padding(.horizontal, 40)
                    
                    VStack(spacing: 0) {
                        ForEach(filteredApps.prefix(20)) { app in
                            HStack(spacing: 16) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                
                                Text(app.name)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    settings.addApp(app)
                                }) {
                                    Text("Add")
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(6)
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                .disabled(settings.dockApps.count >= 9 || settings.dockApps.contains(where: { $0.bundleId == app.bundleId }))
                                .opacity((settings.dockApps.count >= 9 || settings.dockApps.contains(where: { $0.bundleId == app.bundleId })) ? 0.3 : 1.0)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 60)
                        }
                    }
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 40)
                }
                
                Spacer(minLength: 40)
            }
        }
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
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Screenshot Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 10)
                
                SettingsCard(title: "Keyboard Shortcuts") {
                    SettingsActionRow(
                        title: "Capture Full Screen",
                        subtitle: "Triggers Notchly's full screen capture",
                        icon: "macwindow",
                        buttonTitle: nil,
                        buttonIcon: nil,
                        action: {},
                        customContent: AnyView(
                            KeyboardShortcuts.Recorder(for: .takeFullScreen)
                        )
                    )
                    
                    SettingsActionRow(
                        title: "Capture Selection",
                        subtitle: "Triggers Notchly's region capture",
                        icon: "viewfinder",
                        buttonTitle: nil,
                        buttonIcon: nil,
                        action: {},
                        isLast: true,
                        customContent: AnyView(
                            KeyboardShortcuts.Recorder(for: .takeSelection)
                        )
                    )
                }
                
                Text("These shortcuts trigger Notchly's native screenshot capture tool.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Permissions Page

struct PermissionsSettingsPage: View {
    @State private var accessibilityGranted: Bool = false
    @State private var screenRecordingGranted: Bool = false
    @State private var calendarGranted: Bool = false
    @State private var remindersGranted: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Permissions")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 10)
                
                SettingsCard(title: "Required Permissions") {
                    PermissionRow(
                        title: "Accessibility",
                        subtitle: "Enables global screenshot hotkeys (⌥⇧3 / ⌥⇧4)",
                        icon: "figure.arms.open",
                        granted: accessibilityGranted,
                        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                        onEnable: {
                            // This prompt option is what adds the app to the Accessibility list in System Settings!
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                            AXIsProcessTrustedWithOptions(options as CFDictionary)
                        }
                    )
                    
                    PermissionRow(
                        title: "Screen Recording",
                        subtitle: "Required for screenshot capture",
                        icon: "camera.viewfinder",
                        granted: screenRecordingGranted,
                        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
                        isLast: true,
                        onEnable: {
                            // This is what adds the app to the Screen Recording list in System Settings!
                            CGRequestScreenCaptureAccess()
                        }
                    )
                }
                
                SettingsCard(title: "Optional Permissions") {
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
                        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders",
                        isLast: true
                    )
                }
                
                Spacer(minLength: 40)
            }
        }
        .onAppear(perform: checkPermissions)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
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
    var isLast: Bool = false
    var onEnable: (() -> Void)? = nil

    var body: some View {
        SettingsActionRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            buttonTitle: granted ? nil : "Enable",
            buttonIcon: nil,
            action: {
                // Trigger the system prompt FIRST so the app gets added to the list
                onEnable?()
                
                // Then open the settings page so the user can flip the toggle
                if let url = URL(string: settingsURL) {
                    NSWorkspace.shared.open(url)
                }
            },
            isLast: isLast,
            customContent: granted ? AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Granted")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.green)
            ) : nil
        )
    }
}

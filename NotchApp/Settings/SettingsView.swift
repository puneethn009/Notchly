import SwiftUI
import KeyboardShortcuts
import EventKit
import Combine
import ScreenCaptureKit

class SharedEventStore {
    static let shared = EKEventStore()
}
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

/// Keys used to persist automation permission grants across launches.
/// Once the user grants, we save true here. We only clear it if TCC
/// explicitly returns -1743 (denied) — meaning the user revoked it.
private enum AutomationGrantKey {
    static let spotify = "notchly.automation.spotify.granted"
    static let music   = "notchly.automation.music.granted"
}

struct PermissionsSettingsPage: View {
    @State private var accessibilityGranted: Bool = false
    @State private var screenRecordingGranted: Bool = false
    @State private var calendarGranted: Bool = false
    @State private var remindersGranted: Bool = false
    @State private var spotifyGranted: Bool = false
    @State private var musicGranted: Bool = false
    @State private var timerFired: Bool = false

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
                        onEnable: {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                            AXIsProcessTrustedWithOptions(options as CFDictionary)
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )

                    PermissionRow(
                        title: "Screen Recording",
                        subtitle: "Required for screenshot capture",
                        icon: "camera.viewfinder",
                        granted: screenRecordingGranted,
                        isLast: true,
                        onEnable: {
                            CGRequestScreenCaptureAccess()
                            // On macOS 14+, SCShareableContent reliably forces the prompt if CG fails
                            if #available(macOS 12.3, *) {
                                SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { _, _ in }
                            }
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                }

                SettingsCard(title: "Optional Permissions") {
                    PermissionRow(
                        title: "Calendar",
                        subtitle: "Show upcoming events in the notch",
                        icon: "calendar",
                        granted: calendarGranted,
                        onEnable: {
                            if #available(macOS 14.0, *) {
                                SharedEventStore.shared.requestFullAccessToEvents { _, _ in
                                    DispatchQueue.main.async { refreshFastChecks() }
                                }
                            } else {
                                SharedEventStore.shared.requestAccess(to: .event) { _, _ in
                                    DispatchQueue.main.async { refreshFastChecks() }
                                }
                            }
                        }
                    )

                    PermissionRow(
                        title: "Reminders",
                        subtitle: "Show reminders in the notch calendar view",
                        icon: "checklist",
                        granted: remindersGranted,
                        isLast: true,
                        onEnable: {
                            if #available(macOS 14.0, *) {
                                SharedEventStore.shared.requestFullAccessToReminders { _, _ in
                                    DispatchQueue.main.async { refreshFastChecks() }
                                }
                            } else {
                                SharedEventStore.shared.requestAccess(to: .reminder) { _, _ in
                                    DispatchQueue.main.async { refreshFastChecks() }
                                }
                            }
                        }
                    )
                }

                SettingsCard(title: "Music Integrations (Automation)") {
                    PermissionRow(
                        title: "Spotify",
                        subtitle: spotifyGranted
                            ? "Notchly can control Spotify"
                            : "Tap Enable — Spotify will launch and ask for permission",
                        icon: "music.note",
                        granted: spotifyGranted,
                        onEnable: {
                            launchAndPromptAutomation(bundleID: "com.spotify.client",
                                                     persistKey: AutomationGrantKey.spotify) {
                                loadAutomationState()
                            }
                        }
                    )

                    PermissionRow(
                        title: "Apple Music",
                        subtitle: musicGranted
                            ? "Notchly can control Apple Music"
                            : "Tap Enable — Music will launch and ask for permission",
                        icon: "music.note.list",
                        granted: musicGranted,
                        isLast: true,
                        onEnable: {
                            launchAndPromptAutomation(bundleID: "com.apple.Music",
                                                     persistKey: AutomationGrantKey.music) {
                                loadAutomationState()
                            }
                        }
                    )
                }

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            refreshFastChecks()
            loadAutomationState()
            // Also do a live check in case app is already running
            refreshAutomationChecks()
            startPollingTimer()
        }
        .onChange(of: timerFired) { _ in
            refreshFastChecks()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshFastChecks()
            loadAutomationState()
            refreshAutomationChecks()
        }
    }

    // MARK: - State Loaders

    /// Fast O(1) checks — safe on main thread
    private func refreshFastChecks() {
        accessibilityGranted = AXIsProcessTrusted()
        screenRecordingGranted = CGPreflightScreenCaptureAccess()

        let calStatus = EKEventStore.authorizationStatus(for: .event)
        calendarGranted = calStatus == .fullAccess || calStatus.rawValue == 3

        let remStatus = EKEventStore.authorizationStatus(for: .reminder)
        remindersGranted = remStatus == .fullAccess || remStatus.rawValue == 3
    }

    /// Load persisted automation state from UserDefaults (instant, no blocking).
    /// This is the PRIMARY source of truth for automation grants.
    private func loadAutomationState() {
        spotifyGranted = UserDefaults.standard.bool(forKey: AutomationGrantKey.spotify)
        musicGranted   = UserDefaults.standard.bool(forKey: AutomationGrantKey.music)
    }

    /// Live check — only used to detect if user REVOKED access in System Settings.
    /// Runs on background thread. If the app is running and TCC says denied (-1743),
    /// we clear the persisted grant. If noErr, we confirm (re-persist) the grant.
    private func refreshAutomationChecks() {
        DispatchQueue.global(qos: .utility).async {
            let sResult = liveAutomationCheck(for: "com.spotify.client")
            let mResult = liveAutomationCheck(for: "com.apple.Music")

            DispatchQueue.main.async {
                if let s = sResult {
                    UserDefaults.standard.set(s, forKey: AutomationGrantKey.spotify)
                    spotifyGranted = s
                }
                if let m = mResult {
                    UserDefaults.standard.set(m, forKey: AutomationGrantKey.music)
                    musicGranted = m
                }
            }
        }
    }

    /// Returns `true` if granted, `false` if explicitly denied, `nil` if app not running (unknown).
    private func liveAutomationCheck(for bundleID: String) -> Bool? {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, false)
        switch status {
        case noErr:        return true    // Explicitly granted
        case OSStatus(-1743): return false // Explicitly denied — user revoked
        default:           return nil     // App not running — don't change stored state
        }
    }

    // MARK: - Enable Flow

    /// Launch app → wait for it to be ready → trigger macOS prompt → persist result.
    private func launchAndPromptAutomation(bundleID: String, persistKey: String, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let isRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == bundleID
            }

            if !isRunning {
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                    // App not installed — open System Settings Automation pane
                    DispatchQueue.main.async {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
                        completion()
                    }
                    return
                }
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                // Wait up to 5s for app to appear in running list
                for _ in 0..<10 {
                    Thread.sleep(forTimeInterval: 0.5)
                    if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleID }) {
                        break
                    }
                }
                // Extra half-second for app to finish launching
                Thread.sleep(forTimeInterval: 0.5)
            }

            // Trigger the native macOS automation permission dialog
            let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
            let result = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)

            // Wait for TCC to write the grant
            Thread.sleep(forTimeInterval: 0.8)

            // Verify the result
            let verifyTarget = NSAppleEventDescriptor(bundleIdentifier: bundleID)
            let verifyResult = AEDeterminePermissionToAutomateTarget(verifyTarget.aeDesc, typeWildCard, typeWildCard, false)
            let granted = (result == noErr || verifyResult == noErr)

            DispatchQueue.main.async {
                if granted {
                    // Persist so we remember it even when app is closed
                    UserDefaults.standard.set(true, forKey: persistKey)
                }
                completion()
            }
        }
    }

    private func startPollingTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            timerFired.toggle()
            refreshFastChecks()
            startPollingTimer()
        }
    }
}


struct PermissionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let granted: Bool
    var isLast: Bool = false
    var onEnable: (() -> Void)? = nil

    var body: some View {
        SettingsActionRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            buttonTitle: granted ? nil : "Enable",
            buttonIcon: nil,
            action: { onEnable?() },
            isLast: isLast,
            customContent: granted ? AnyView(
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Granted")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.green)
            ) : nil
        )
    }
}


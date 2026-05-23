import SwiftUI
import Combine

struct CustomTimer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var minutes: Int
    var seconds: Int
    
    var totalSeconds: Int {
        return (minutes * 60) + seconds
    }
}

struct DockApp: Identifiable, Codable, Equatable {
    var id: String { bundleId }
    var name: String
    var bundleId: String
    var path: String
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Media Settings
    @AppStorage("useAppleMusic") var useAppleMusic: Bool = true
    @AppStorage("useSpotify") var useSpotify: Bool = true
    @AppStorage("showClosedNotchMusicIndicator") var showClosedNotchMusicIndicator: Bool = true
    @AppStorage("showClosedNotchTimerIndicator") var showClosedNotchTimerIndicator: Bool = true
    @AppStorage("showMuteButton") var showMuteButton: Bool = true
    
    // Calendar Settings
    @AppStorage("calendarSource") var calendarSource: String = "local" // local, notion, both
    @AppStorage("notionToken") var notionToken: String = ""
    @AppStorage("notionDatabaseID") var notionDatabaseID: String = ""
    @AppStorage("notionDateProperty") var notionDateProperty: String = "Date"
    @AppStorage("notionTitleProperty") var notionTitleProperty: String = "Name"
    
    // Module Toggles
    @AppStorage("enableStopwatch") var enableStopwatch: Bool = true
    @AppStorage("selectedAlarmSound") var selectedAlarmSound: String = "Glass"
    
    // Notch Pages Module Toggles
    @AppStorage("showNotchMusic") var showNotchMusic: Bool = true
    @AppStorage("showNotchTimer") var showNotchTimer: Bool = true
    @AppStorage("showNotchSystem") var showNotchSystem: Bool = true
    @AppStorage("showNotchCalendar") var showNotchCalendar: Bool = true
    @AppStorage("showNotchLauncher") var showNotchLauncher: Bool = true
    @AppStorage("showNotchScreenshots") var showNotchScreenshots: Bool = true
    
    var activeNotchPages: [NotchPage] {
        var pages: [NotchPage] = []
        if showNotchMusic { pages.append(.media) }
        if showNotchTimer { pages.append(.timer) }
        if showNotchSystem { pages.append(.system) }
        if showNotchCalendar { pages.append(.calendar) }
        if showNotchLauncher { pages.append(.launcher) }
        if showNotchScreenshots { pages.append(.screenshots) }
        return pages.isEmpty ? [.media] : pages
    }
    
    // Performance Settings
    @AppStorage("showCPU") var showCPU: Bool = true
    @AppStorage("showRAM") var showRAM: Bool = true
    @AppStorage("showGPU") var showGPU: Bool = true
    @AppStorage("showDisk") var showDisk: Bool = true
    @AppStorage("showNetwork") var showNetwork: Bool = true
    @AppStorage("showThermal") var showThermal: Bool = true
    @AppStorage("showBattery") var showBattery: Bool = true
    
    // Timer Settings
    @AppStorage("customTimersData") private var customTimersData: Data = Data()
    @Published var customTimers: [CustomTimer] = [] {
        didSet {
            saveTimers()
        }
    }
    
    // Dock Settings
    @AppStorage("dockAppsData") private var dockAppsData: Data = Data()
    @Published var dockApps: [DockApp] = [] {
        didSet {
            saveDock()
        }
    }
    
    private init() {
        loadTimers()
        loadDock()
    }
    
    private func loadTimers() {
        if let decoded = try? JSONDecoder().decode([CustomTimer].self, from: customTimersData) {
            customTimers = decoded
        } else {
            // Default timers
            customTimers = [
                CustomTimer(name: "Pomodoro", minutes: 25, seconds: 0),
                CustomTimer(name: "Short Break", minutes: 5, seconds: 0)
            ]
        }
    }
    
    private func saveTimers() {
        if let encoded = try? JSONEncoder().encode(customTimers) {
            customTimersData = encoded
        }
    }
    
    private func loadDock() {
        if let decoded = try? JSONDecoder().decode([DockApp].self, from: dockAppsData) {
            dockApps = decoded
        } else {
            // Default apps
            dockApps = [
                DockApp(name: "Safari", bundleId: "com.apple.Safari", path: "/Applications/Safari.app"),
                DockApp(name: "Music", bundleId: "com.apple.Music", path: "/System/Applications/Music.app"),
                DockApp(name: "Messages", bundleId: "com.apple.MobileSMS", path: "/System/Applications/Messages.app")
            ]
        }
    }
    
    private func saveDock() {
        if let encoded = try? JSONEncoder().encode(dockApps) {
            dockAppsData = encoded
        }
    }
    
    func addApp(_ app: DockApp) {
        if dockApps.count < 9 && !dockApps.contains(where: { $0.bundleId == app.bundleId }) {
            dockApps.append(app)
        }
    }
    
    func removeApp(at offsets: IndexSet) {
        dockApps.remove(atOffsets: offsets)
    }
    
    func moveApp(from source: IndexSet, to destination: Int) {
        dockApps.move(fromOffsets: source, toOffset: destination)
    }
}

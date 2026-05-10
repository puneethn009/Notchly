import SwiftUI
import EventKit
import Combine
import AppKit
import IOKit.ps

enum BatteryState {
    case battery
    case charging
    case pluggedIn
}

@Observable
class BatteryManager {
    var batteryPercentage: Int = 100
    var state: BatteryState = .battery
    private var timer: Timer?
    
    init() {
        updateBattery()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBattery()
        }
    }
    
    func updateBattery() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        var foundPercentage = 100
        var foundState: BatteryState = .battery
        
        for ps in sources {
            let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as! [String: Any]
            if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
                foundPercentage = capacity
            }
            
            let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            let powerState = info[kIOPSPowerSourceStateKey] as? String
            
            if powerState == kIOPSACPowerValue {
                if isCharging {
                    foundState = .charging
                } else {
                    foundState = .pluggedIn
                }
            }
        }
        
        DispatchQueue.main.async {
            self.batteryPercentage = foundPercentage
            self.state = foundState
        }
    }
}

struct NotchExpandedView: View {
    @Environment(\.openSettings) private var openSettings
    @StateObject private var notchState = NotchState.shared
    @State private var batteryManager = BatteryManager()
    @StateObject private var mediaManager = MediaPlayerManager.shared
    @ObservedObject private var timerManager = TimerManager.shared
    @StateObject private var systemManager = SystemMonitorManager()
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var launcherManager = LauncherManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar (Now with Navigation + Settings/Battery)
            HStack(alignment: .center) {
                // Top-Left: Module Navigation
                HStack(spacing: 12) {
                    ForEach(NotchPage.allCases, id: \.self) { page in
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                notchState.selectedPage = page 
                            }
                        }) {
                            Image(systemName: page.rawValue)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(notchState.selectedPage == page ? .white : .white.opacity(0.4))
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(notchState.selectedPage == page ? Color.white.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Top-Right: Settings & Battery
                HStack(spacing: 16) {
                    if #available(macOS 14.0, *) {
                        SettingsLink {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(batteryManager.batteryPercentage)%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        MacBatteryIcon(percentage: batteryManager.batteryPercentage, state: batteryManager.state)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
            Spacer()
            
            // Content Switcher
            ZStack {
                Group {
                    switch NotchState.shared.selectedPage {
                    case .media:
                        MediaModuleView(mediaManager: mediaManager)
                    case .timer:
                        TimerModuleView(timerManager: timerManager)
                    case .system:
                        SystemModuleView(systemManager: systemManager)
                    case .calendar:
                        CalendarModuleView(calendarManager: calendarManager)
                    case .launcher:
                        LauncherModuleView(launcherManager: launcherManager)
                    }
                }
                .id(NotchState.shared.selectedPage)
                .transition(.asymmetric(
                    insertion: .move(edge: slideDirection == .trailing ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                ))
            }
            .offset(x: shakeOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 16)
            
            Spacer()
        }
        .background(Color.clear)
        .contentShape(Rectangle()) 
        .onAppear {
            setupSwipeMonitor()
        }
        .onDisappear {
            if let monitor = swipeMonitor {
                NSEvent.removeMonitor(monitor)
                swipeMonitor = nil
            }
        }
    }
    
    @State private var slideDirection: Edge = .trailing
    @State private var shakeOffset: CGFloat = 0
    @State private var swipeMonitor: Any?
    @State private var hasTriggeredInCurrentGesture = false

    private func setupSwipeMonitor() {
        swipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            // Only handle if we are the expanded notch window
            guard let window = NotchWindowController.shared.window, window.isKeyWindow || window.isVisible else { return event }
            
            // Detect swipe phases
            if event.phase == .began || event.momentumPhase == .began {
                hasTriggeredInCurrentGesture = false
            }
            if event.phase == .ended || event.phase == .cancelled {
                hasTriggeredInCurrentGesture = false
            }

            if !hasTriggeredInCurrentGesture && abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
                let threshold: CGFloat = 20.0
                
                if event.scrollingDeltaX > threshold {
                    // Swipe Right -> Previous
                    let prev = notchState.selectedPage.previous()
                    if prev != notchState.selectedPage {
                        slideDirection = .leading
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            notchState.selectedPage = prev
                        }
                    } else {
                        shake(direction: 1)
                    }
                    hasTriggeredInCurrentGesture = true
                } else if event.scrollingDeltaX < -threshold {
                    // Swipe Left -> Next
                    let next = notchState.selectedPage.next()
                    if next != notchState.selectedPage {
                        slideDirection = .trailing
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            notchState.selectedPage = next
                        }
                    } else {
                        shake(direction: -1)
                    }
                    hasTriggeredInCurrentGesture = true
                }
            }
            return event
        }
    }

    private func shake(direction: CGFloat) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.2, blendDuration: 0)) {
            shakeOffset = direction * 20
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.2, blendDuration: 0)) {
                shakeOffset = 0
            }
        }
    }
}

// MARK: - Modules

struct MediaModuleView: View {
    @ObservedObject var mediaManager: MediaPlayerManager
    
    var body: some View {
        Group {
            if mediaManager.isRunning || !mediaManager.title.isEmpty {
                HStack(alignment: .top, spacing: 20) {
                    // Album Art
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.purple, .black, .gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Group {
                                    if let img = mediaManager.artworkImage {
                                        Image(nsImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button(action: { mediaManager.toggleMute() }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: mediaManager.isSystemMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .foregroundColor(mediaManager.isSystemMuted ? .gray : .pink)
                                    .font(.system(size: 12))
                                )
                        }
                        .buttonStyle(.plain)
                        .offset(x: 8, y: 8)
                    }
                    
                    // Track Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mediaManager.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(mediaManager.artist)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Progress Bar
                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: max(0, geo.size.width * CGFloat(mediaManager.progress)), height: 4)
                                }
                            }
                            .frame(height: 4)
                            
                            HStack {
                                Text(mediaManager.positionStr)
                                Spacer()
                                Text(mediaManager.durationStr)
                            }
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Controls
                        HStack(spacing: 24) {
                            Spacer()
                            Button(action: { mediaManager.prevTrack() }) {
                                Image(systemName: "backward.fill")
                            }.buttonStyle(.plain)
                            
                            Button(action: { mediaManager.playPause() }) {
                                Image(systemName: mediaManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24))
                            }.buttonStyle(.plain)
                            
                            Button(action: { mediaManager.nextTrack() }) {
                                Image(systemName: "forward.fill")
                            }.buttonStyle(.plain)
                            
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                    }
                    .frame(width: 200, height: 100)
                }
                .padding(.bottom, 20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("No Media Playing")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 30)
            }
        }
    }
}

struct TimerModuleView: View {
    @ObservedObject var timerManager: TimerManager
    
    var body: some View {
        VStack(spacing: 20) {
            if timerManager.isAlarmPlaying {
                VStack(spacing: 20) {
                    Text("TIME'S UP!")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.red)
                    
                    Button(action: { timerManager.stopAlarm() }) {
                        Text("STOP ALARM")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.red))
                            .shadow(color: .red.opacity(0.4), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                }
            } else if timerManager.isRunning {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(timerManager.progress))
                            .stroke(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: timerManager.timeRemaining)
                        
                        Text(timerManager.timeString)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { timerManager.stop() }) {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.red.opacity(0.8)))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 16) {
                    Text("Quick Start")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        TimerButton(label: "1m", color: .gray) { timerManager.start(minutes: 1) }
                        TimerButton(label: "5m", color: .blue) { timerManager.start(minutes: 5) }
                        TimerButton(label: "10m", color: .cyan) { timerManager.start(minutes: 10) }
                        TimerButton(label: "15m", color: .teal) { timerManager.start(minutes: 15) }
                        TimerButton(label: "25m", color: .indigo) { timerManager.start(minutes: 25) }
                        TimerButton(label: "60m", color: .purple) { timerManager.start(minutes: 60) }
                        TimerButton(label: "90m", color: .pink) { timerManager.start(minutes: 90) }
                    }
                }
            }
        }
    }
}

struct TimerButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(color.opacity(0.2))
                        .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 2))
                )
        }
        .buttonStyle(.plain)
    }
}

struct SystemModuleView: View {
    @ObservedObject var systemManager: SystemMonitorManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Top Row: Core Gauges
            HStack(spacing: 30) {
                CircularGauge(label: "CPU", value: systemManager.cpuUsage, color: .green)
                CircularGauge(label: "RAM", value: systemManager.ramUsage, color: .blue)
                CircularGauge(label: "GPU", value: systemManager.gpuUsage, color: .orange)
                CircularGauge(label: "DISK", value: systemManager.diskUsage, color: .purple)
            }
            
            // Bottom Row: Status Strip
            HStack(spacing: 30) {
                // Network
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.cyan)
                        Text(systemManager.downloadSpeed)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                        Text(systemManager.uploadSpeed)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.05)))
                
                // Thermal
                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium")
                        .foregroundColor(thermalColor(systemManager.thermalPressure))
                    Text(systemManager.thermalPressure.uppercased())
                        .font(.system(size: 10, weight: .black))
                }
                
                // Battery Cycles
                HStack(spacing: 6) {
                    Image(systemName: "battery.100.bolt")
                        .foregroundColor(.green)
                    Text("\(systemManager.batteryCycles) CYCLES")
                        .font(.system(size: 10, weight: .black))
                }
                .opacity(systemManager.batteryCycles > 0 ? 1 : 0)
            }
            .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private func thermalColor(_ pressure: String) -> Color {
        switch pressure {
        case "Nominal": return .green
        case "Fair": return .yellow
        case "Serious": return .orange
        case "Critical": return .red
        default: return .gray
        }
    }
}

struct CircularGauge: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(value))
                    .stroke(
                        LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.3), radius: 4)
                
                VStack(spacing: 0) {
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text(label)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 64, height: 64)
        }
    }
}

struct NetworkSpeedRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(value))
                }
            }
            .frame(height: 6)
        }
    }
}

struct SpeedStat: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.6))
        }
    }
}

struct CalendarModuleView: View {
    @ObservedObject var calendarManager: CalendarManager
    
    var body: some View {
        VStack(spacing: 20) {
            if calendarManager.permissionStatus == .notDetermined {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    Text("Calendar Access Required")
                        .font(.headline)
                    Button(action: { calendarManager.requestAccess() }) {
                        Text("Grant Access")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.blue))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // TOP: Horizontal Date Strip
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(-30..<30, id: \.self) { offset in
                                let date = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
                                DatePill(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: calendarManager.selectedDate)) {
                                    withAnimation(.spring(response: 0.3)) {
                                        calendarManager.fetchEvents(for: date)
                                    }
                                }
                                .id(offset)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 4)
                    }
                    .onAppear {
                        proxy.scrollTo(0, anchor: .center)
                    }
                }
                
                // BOTTOM: Events Agenda
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        if calendarManager.eventsForSelectedDate.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.2))
                                Text("No Events")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.top, 20)
                        } else {
                            ForEach(calendarManager.eventsForSelectedDate, id: \.eventIdentifier) { event in
                                CalendarEventRow(event: event)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .padding(.top, 12)
    }
}

struct CalendarEventRow: View {
    let event: EKEvent
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: event.calendar.color))
                .frame(width: 3, height: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(event.startDate.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            if event.startDate < Date() && event.endDate > Date() {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }
}

struct DatePill: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.3))
                    .tracking(0.5)
                
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(Color.blue)
                                    .shadow(color: .blue.opacity(0.4), radius: 4)
                            } else if Calendar.current.isDate(date, inSameDayAs: Date()) {
                                Circle()
                                    .stroke(Color.blue, lineWidth: 1)
                            }
                        }
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

struct LauncherModuleView: View {
    @ObservedObject var launcherManager: LauncherManager
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Dock")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(2)
                .textCase(.uppercase)
            
            HStack(spacing: 16) {
                ForEach(launcherManager.apps) { app in
                    LauncherIcon(app: app, launcherManager: launcherManager)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            )
        }
    }
}

struct LauncherIcon: View {
    let app: LauncherApp
    let launcherManager: LauncherManager
    @State private var isHovering = false
    
    var body: some View {
        Button(action: { launcherManager.launch(bundleID: app.id) }) {
            VStack(spacing: 8) {
                ZStack {
                    if let icon = launcherManager.icon(for: app.id) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 48, height: 48)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(isHovering ? 0.4 : 0.2), radius: isHovering ? 10 : 5, y: isHovering ? 5 : 2)
                    }
                }
                .scaleEffect(isHovering ? 1.25 : 1.0)
                .offset(y: isHovering ? -10 : 0)
                
                Text(app.name)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(isHovering ? 1.0 : 0.4)
                    .scaleEffect(isHovering ? 1.1 : 0.9)
            }
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.65, blendDuration: 0), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { h in isHovering = h }
    }
}

struct MacBatteryIcon: View {
    var percentage: Int
    var state: BatteryState
    
    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .center) {
                // Outer shell
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .frame(width: 22, height: 11)
                
                // Inner fill (aligned left)
                HStack {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(percentage <= 20 && state != .charging ? Color.red : Color.white)
                        .frame(width: max(0, min(19, (CGFloat(percentage) / 100.0) * 19)), height: 7)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 1.5)
                
                // Overlay icons
                if state == .charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(Color.black)
                } else if state == .pluggedIn {
                    Image(systemName: "powerplug.fill")
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(Color.black)
                }
            }
            .frame(width: 22, height: 11)
            
            // Battery tip
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.5))
                .frame(width: 1.5, height: 4)
        }
    }
}

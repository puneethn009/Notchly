import SwiftUI
import Combine

class TimerManager: ObservableObject {
    // Timer State
    @Published var timeRemaining: TimeInterval = 0
    @Published var isRunning: Bool = false
    @Published var totalTime: TimeInterval = 0
    @Published var isCompleted: Bool = false
    @Published var isAlarmPlaying: Bool = false
    @Published var currentTimerName: String = ""
    
    // Stopwatch State
    @Published var stopwatchTime: TimeInterval = 0
    @Published var isStopwatchRunning: Bool = false
    
    static let shared = TimerManager()
    
    private var timer: AnyCancellable?
    private var alarmSound: NSSound?
    
    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var stopwatchString: String {
        let hours = Int(stopwatchTime) / 3600
        let minutes = (Int(stopwatchTime) % 3600) / 60
        let seconds = Int(stopwatchTime) % 60
        let milliseconds = Int((stopwatchTime.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, milliseconds)
    }
    
    var stopwatchShortString: String {
        let hours = Int(stopwatchTime) / 3600
        let minutes = (Int(stopwatchTime) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalTime)
    }
    
    // MARK: - Timer Actions
    func start(minutes: Int, name: String = "Timer") {
        stop()
        stopAlarm()
        stopStopwatch()
        
        currentTimerName = name
        totalTime = TimeInterval(minutes * 60)
        timeRemaining = totalTime
        isRunning = true
        isCompleted = false
        
        NotchState.shared.stickyType = .timer
        NotchState.shared.isSticky = true
        
        startGlobalTimer()
    }
    
    func stop() {
        if isRunning {
            isRunning = false
            timer?.cancel()
            timer = nil
            if !isCompleted {
                NotchState.shared.isSticky = false
            }
        }
    }
    
    func stopAlarm() {
        isAlarmPlaying = false
        isCompleted = false
        alarmSound?.stop()
        NotchState.shared.isExpanded = false
        NotchState.shared.isSticky = false
    }
    
    // MARK: - Stopwatch Actions
    func startStopwatch() {
        stop()
        stopAlarm()
        
        isStopwatchRunning = true
        NotchState.shared.stickyType = .timer // Reuse timer sticky for now or add .stopwatch
        NotchState.shared.isSticky = true
        
        startGlobalTimer()
    }
    
    func stopStopwatch() {
        if isStopwatchRunning {
            isStopwatchRunning = false
            timer?.cancel()
            timer = nil
            NotchState.shared.isSticky = false
        }
    }
    
    func resetStopwatch() {
        stopStopwatch()
        stopwatchTime = 0
    }
    
    // MARK: - Core Timer
    private func startGlobalTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 0.01, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        if isRunning {
            if timeRemaining > 0 {
                timeRemaining -= 0.01
            } else {
                stop()
                isCompleted = true
                triggerAlarm()
            }
        } else if isStopwatchRunning {
            stopwatchTime += 0.01
        }
    }
    
    private func triggerAlarm() {
        isAlarmPlaying = true
        withAnimation(.spring()) {
            NotchState.shared.isExpanded = true
            NotchState.shared.selectedPage = .timer
        }
        
        let soundName = SettingsManager.shared.selectedAlarmSound
        alarmSound = NSSound(named: soundName)
        alarmSound?.loops = true
        alarmSound?.play()
    }
}

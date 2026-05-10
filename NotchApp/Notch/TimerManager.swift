import SwiftUI
import Combine

class TimerManager: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var isRunning: Bool = false
    @Published var totalTime: TimeInterval = 0
    @Published var isCompleted: Bool = false
    @Published var isAlarmPlaying: Bool = false
    @Published var currentTimerName: String = ""
    
    static let shared = TimerManager()
    
    private var timer: AnyCancellable?
    private var alarmSound: NSSound?
    
    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalTime)
    }
    
    func start(minutes: Int, name: String = "Timer") {
        stop()
        stopAlarm()
        currentTimerName = name
        totalTime = TimeInterval(minutes * 60)
        timeRemaining = totalTime
        isRunning = true
        isCompleted = false
        
        NotchState.shared.stickyType = .timer
        NotchState.shared.isSticky = true
        
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        if !isCompleted {
            NotchState.shared.isSticky = false
        }
    }
    
    func stopAlarm() {
        isAlarmPlaying = false
        isCompleted = false
        alarmSound?.stop()
        NotchState.shared.isExpanded = false
        NotchState.shared.isSticky = false
    }
    
    private func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            stop()
            isCompleted = true
            triggerAlarm()
        }
    }
    
    private func triggerAlarm() {
        isAlarmPlaying = true
        
        // Expand the notch automatically
        withAnimation(.spring()) {
            NotchState.shared.isExpanded = true
            NotchState.shared.selectedPage = .timer
        }
        
        // Loop a bell sound
        alarmSound = NSSound(named: "Glass") // Will use a better one if possible, system sounds are limited
        alarmSound?.loops = true
        alarmSound?.play()
    }
}

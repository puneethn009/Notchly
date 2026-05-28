import SwiftUI
import Combine

enum NotchPage: String, CaseIterable, Codable {
    case media = "music.note"
    case timer = "timer"
    case system = "cpu"
    case calendar = "calendar"
    case launcher = "square.grid.2x2"
    case screenshots = "camera.viewfinder"
    case game = "gamecontroller"
    case clipboard = "doc.on.clipboard"
    case todo = "checklist"
    
    func next() -> NotchPage {
        let all = NotchPage.allCases
        let idx = all.firstIndex(of: self) ?? 0
        let nextIdx = min(idx + 1, all.count - 1)
        return all[nextIdx]
    }
    
    func previous() -> NotchPage {
        let all = NotchPage.allCases
        let idx = all.firstIndex(of: self) ?? 0
        let prevIdx = max(idx - 1, 0)
        return all[prevIdx]
    }
}

enum StickyType {
    case none
    case timer
    case media
    case todo
    case clipboard
}

class NotchState: NSObject, ObservableObject {
    static let shared = NotchState()
    
    @Published var isExpanded: Bool = false {
        didSet {
            if !isExpanded && extraHeight > 0 {
                extraHeight = 0
            }
        }
    }
    @Published var isHovering: Bool = false
    
    // Priority State Flags
    @Published var isOverdueReminderActive: Bool = false
    
    @Published var stickyType: StickyType = .none
    @Published var isSticky: Bool = false {
        didSet { if !isSticky { stickyType = .none } }
    }
    @Published var selectedPage: NotchPage = .media {
        didSet {
            if extraHeight > 0 {
                extraHeight = 0
            }
        }
    }
    
    var clipboardDisplayTimer: Timer? = nil
    
    @Published var lastCapturedScreenshotURL: URL?
    @Published var pendingScreenshotURL: URL?
    @Published var isShowingScreenshotPopup: Bool = false
    @Published var activeGame: String? = nil
    @Published var extraHeight: CGFloat = 0
    
    // Task Reminder Alarm State
    @Published var activeTaskReminderId: UUID? = nil
    @Published var activeTaskReminderTitle: String = ""
    @Published var activeTaskReminderTags: [String] = []
    
    @Published var hasOverdueTodo: Bool = false
    
    // The current active timer for 5s overdue reminder display
    var overdueDisplayTimer: Timer? = nil
    
    func transitionTo(stickyType newType: StickyType) {
        guard self.stickyType != newType || !self.isSticky else { return }
        
        if self.isSticky {
            self.isSticky = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.stickyType = newType
                if newType != .none {
                    self.isSticky = true
                }
            }
        } else {
            self.stickyType = newType
            if newType != .none {
                self.isSticky = true
            }
        }
    }
    
    func evaluateStickyPriority() {
        // 1. Clipboard has highest priority
        if stickyType == .clipboard { return }
        
        var targetType: StickyType = .none
        
        // 2. Overdue Reminder (5-second pulse)
        if isOverdueReminderActive {
            targetType = .todo
        }
        // 3. Timer / Stopwatch
        else if TimerManager.shared.isRunning || TimerManager.shared.isStopwatchRunning {
            targetType = .timer
        }
        // 4. Media
        else if MediaPlayerManager.shared.isPlaying {
            targetType = .media
        }
        
        if targetType == .none {
            isSticky = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !self.isSticky { self.stickyType = .none }
            }
        } else {
            transitionTo(stickyType: targetType)
        }
    }
}

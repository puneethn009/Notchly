import SwiftUI
import Combine

enum NotchPage: String, CaseIterable {
    case media = "music.note"
    case timer = "timer"
    case system = "cpu"
    case calendar = "calendar"
    case launcher = "square.grid.2x2"
    
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
}

class NotchState: NSObject, ObservableObject {
    static let shared = NotchState()
    
    @Published var isExpanded: Bool = false
    @Published var stickyType: StickyType = .none
    @Published var isSticky: Bool = false {
        didSet { if !isSticky { stickyType = .none } }
    }
    @Published var selectedPage: NotchPage = .media
}

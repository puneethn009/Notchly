import SwiftUI
import Combine

enum NotchPage: String, CaseIterable {
    case media = "music.note"
    case timer = "timer"
    case system = "cpu"
    case calendar = "calendar"
    case launcher = "square.grid.2x2"
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

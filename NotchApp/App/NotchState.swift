import SwiftUI
import Combine

class NotchState: NSObject, ObservableObject {
    static let shared = NotchState()
    @Published var isExpanded: Bool = false
}

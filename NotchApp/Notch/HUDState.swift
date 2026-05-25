import Foundation
import SwiftUI
import Combine

enum HUDType {
    case volume
    case brightness
}

class HUDState: ObservableObject {
    static let shared = HUDState()
    
    @Published var isVisible: Bool = true
    @Published var hudType: HUDType = .volume
    @Published var value: Float = 0.5
    
    private var hideTimer: Timer?
    
    private init() {}
    
    func showHUD(type: HUDType, value: Float) {
        // Ensure UI updates on main thread
        DispatchQueue.main.async {
            self.hudType = type
            self.value = value
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.isVisible = true
            }
            
            self.hideTimer?.invalidate()
            self.hideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    self.isVisible = false
                }
            }
        }
    }
}

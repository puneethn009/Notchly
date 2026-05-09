import SwiftUI

@Observable
class AppState {
    static let shared = AppState()
    
    var isSettingsPresented: Bool = false
    
    private init() {}
}

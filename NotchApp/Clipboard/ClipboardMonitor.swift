import Foundation
import AppKit
import SwiftData

class ClipboardMonitor {
    static let shared = ClipboardMonitor()
    
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    
    @MainActor
    private var modelContext: ModelContext {
        PersistenceController.shared.container.mainContext
    }
    
    init() {
        self.lastChangeCount = pasteboard.changeCount
    }
    
    func start() {
        guard timer == nil else { return }
        // Poll every 0.5s because NSPasteboard doesn't support push notifications
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        // Ensure it's text
        guard let items = pasteboard.pasteboardItems else { return }
        
        for item in items {
            if let text = item.string(forType: .string) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Task { @MainActor in
                        saveToHistory(text: trimmed)
                    }
                    break // Only save the first text item found
                }
            }
        }
    }
    
    @MainActor
    private func saveToHistory(text: String) {
        let fetchDescriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.copiedAt, order: .reverse)])
        do {
            let items = try modelContext.fetch(fetchDescriptor)
            if let first = items.first, first.content == text {
                return // Duplicate of immediately preceding item
            }
            
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let appName = frontmostApp?.localizedName ?? "Unknown"
            
            if SettingsManager.shared.clipboardPrivacyMode {
                let sensitiveApps = ["1Password", "Bitwarden", "Keychain Access", "LastPass", "Dashlane", "Enpass", "Keeper", "RoboForm", "Secrets"]
                if sensitiveApps.contains(where: { appName.localizedCaseInsensitiveContains($0) }) {
                    return // Ignore copy from sensitive app
                }
            }
            
            let type = classifyContent(text)
            let newItem = ClipboardItem(content: text, sourceApp: appName, contentType: type)
            modelContext.insert(newItem)
            
            let limit = SettingsManager.shared.clipboardHistoryLimit
            let unpinnedItems = items.filter { !$0.isPinned }
            if unpinnedItems.count >= limit {
                let itemsToDelete = unpinnedItems.dropFirst(limit - 1) // limit - 1 because we just added 1 unpinned (newItem isn't in items array yet)
                for oldItem in itemsToDelete {
                    modelContext.delete(oldItem)
                }
            }
            
            // Trigger Sticky Clipboard Animation (Overwrites anything else currently showing)
            if !NotchState.shared.isExpanded {
                NotchState.shared.transitionTo(stickyType: .clipboard)
                
                NotchState.shared.clipboardDisplayTimer?.invalidate()
                NotchState.shared.clipboardDisplayTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                    Task { @MainActor in
                        if NotchState.shared.stickyType == .clipboard {
                            NotchState.shared.stickyType = .none // Clear so evaluate works
                            NotchState.shared.evaluateStickyPriority()
                        }
                    }
                }
            }
        } catch {
            print("ClipboardMonitor Error: \(error)")
        }
    }
    
    private func classifyContent(_ text: String) -> String {
        let urlRegex = "(?i)^https?://.*"
        let emailRegex = "(?i)^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let numberRegex = "^[0-9.,\\s+()-]+$"
        let colorRegex = "^#?[0-9A-Fa-f]{6}$"
        
        if text.range(of: urlRegex, options: .regularExpression) != nil {
            return "Link"
        }
        if text.range(of: emailRegex, options: .regularExpression) != nil {
            return "Email"
        }
        if text.range(of: colorRegex, options: .regularExpression) != nil {
            return "Color"
        }
        if text.range(of: numberRegex, options: .regularExpression) != nil {
            return "Number"
        }
        
        let codeHeuristics = ["func ", "var ", "let ", "import ", "struct ", "class ", "def ", "console.log"]
        if codeHeuristics.contains(where: { text.contains($0) }) {
            return "Code"
        }
        if text.contains("{") && text.contains("}") && text.contains(":") {
            return "Code" // JSON-like
        }
        if text.contains("</") && text.contains(">") {
            return "Code" // XML/HTML-like
        }
        
        return "Text"
    }
}

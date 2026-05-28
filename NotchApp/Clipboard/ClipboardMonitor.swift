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
        // Check if the most recent item is exactly the same to avoid duplicates
        let fetchDescriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.copiedAt, order: .reverse)])
        do {
            let items = try modelContext.fetch(fetchDescriptor)
            if let first = items.first, first.content == text {
                return // Duplicate of immediately preceding item
            }
            
            let newItem = ClipboardItem(content: text, sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown")
            modelContext.insert(newItem)
            
            // Limit history to 100 items to preserve performance
            if items.count >= 100 {
                // Delete everything past 99th item
                let itemsToDelete = items.dropFirst(99)
                for oldItem in itemsToDelete {
                    modelContext.delete(oldItem)
                }
            }
        } catch {
            print("ClipboardMonitor Error: \(error)")
        }
    }
}

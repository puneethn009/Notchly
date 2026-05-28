import Foundation
import SwiftData

@Model
final class TodoItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var isPinned: Bool
    var createdAt: Date
    var dueDate: Date?
    var reminderTime: Date?
    var tags: [String] = []
    var hasSoundReminder: Bool = false
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, isPinned: Bool = false, createdAt: Date = Date(), dueDate: Date? = nil, reminderTime: Date? = nil, tags: [String] = [], hasSoundReminder: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.reminderTime = reminderTime
        self.tags = tags
        self.hasSoundReminder = hasSoundReminder
    }
}

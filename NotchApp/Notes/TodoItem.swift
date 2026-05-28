import Foundation
import SwiftData

@Model
final class TodoItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var isPinned: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, isPinned: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.createdAt = createdAt
    }
}

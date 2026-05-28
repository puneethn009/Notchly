import Foundation
import SwiftData

@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var content: String
    var copiedAt: Date
    var sourceApp: String
    var isPinned: Bool
    var contentType: String = "Text"
    
    init(id: UUID = UUID(), content: String, copiedAt: Date = Date(), sourceApp: String = "Unknown", isPinned: Bool = false, contentType: String = "Text") {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        self.sourceApp = sourceApp
        self.isPinned = isPinned
        self.contentType = contentType
    }
}

import Foundation
import SwiftData

@Model
class ScreenshotItem {
    @Attribute(.unique) var id: UUID
    var filename: String
    var filePath: String
    var capturedAt: Date
    var contentType: String
    var extractedText: String?
    var isFavorited: Bool
    var cornerRadius: Double = 12
    var rotation: Double = 0
    
    init(id: UUID = UUID(), filename: String, filePath: String, capturedAt: Date = Date(), contentType: ContentType = .unknown, extractedText: String? = nil) {
        self.id = id
        self.filename = filename
        self.filePath = filePath
        self.capturedAt = capturedAt
        self.contentType = contentType.rawValue
        self.extractedText = extractedText
        self.isFavorited = false
        self.cornerRadius = 12
        self.rotation = 0
    }
}

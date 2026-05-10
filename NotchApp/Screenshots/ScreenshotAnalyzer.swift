import Foundation
import Vision
import AppKit
import OSLog

struct AnalysisResult {
    let text: String
    let barcodes: [String]
    let contentType: ContentType
}

enum ContentType: String, Codable {
    case photo
    case textDocument
    case uiScreenshot
    case receipt
    case codeSnippet
    case qrCode
    case unknown
}

class ScreenshotAnalyzer {
    static let shared = ScreenshotAnalyzer()
    private let logger = Logger(subsystem: "com.notchly.app", category: "ScreenshotAnalyzer")
    
    func analyze(imageURL: URL) async -> AnalysisResult {
        guard let image = NSImage(contentsOf: imageURL),
              let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            return AnalysisResult(text: "", barcodes: [], contentType: .unknown)
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // 1. Text Recognition
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        
        // 2. Barcode Detection
        let barcodeRequest = VNDetectBarcodesRequest()
        
        do {
            try handler.perform([textRequest, barcodeRequest])
            
            let recognizedText = textRequest.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
            let recognizedBarcodes = barcodeRequest.results?.compactMap { $0.payloadStringValue } ?? []
            
            let type = classify(text: recognizedText, barcodes: recognizedBarcodes)
            
            return AnalysisResult(text: recognizedText, barcodes: recognizedBarcodes, contentType: type)
        } catch {
            logger.error("Analysis failed: \(error.localizedDescription)")
            return AnalysisResult(text: "", barcodes: [], contentType: .unknown)
        }
    }
    
    private func classify(text: String, barcodes: [String]) -> ContentType {
        if !barcodes.isEmpty { return .qrCode }
        
        let lowerText = text.lowercased()
        
        // Receipt patterns
        if lowerText.contains("total") || lowerText.contains("amount") || lowerText.contains("tax") || lowerText.contains("sum") {
            return .receipt
        }
        
        // Code snippet patterns
        let codeKeywords = ["func ", "var ", "let ", "class ", "import ", "def ", "printf", "console.log", "<html>"]
        if codeKeywords.contains(where: { lowerText.contains($0) }) {
            return .codeSnippet
        }
        
        // UI Screenshot patterns (often contains status bar items or density of UI text)
        if lowerText.contains("file") && lowerText.contains("edit") && lowerText.contains("view") {
            return .uiScreenshot
        }
        
        if text.count > 100 {
            return .textDocument
        }
        
        return .photo
    }
}

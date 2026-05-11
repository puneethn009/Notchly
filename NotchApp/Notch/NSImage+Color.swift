import AppKit
import CoreImage
import SwiftUI

extension NSImage {
    /// Extracts two colors (top-left average and bottom-right average) to form a gradient matching the image
    func extractGradientColors() -> [Color] {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return [.gray.opacity(0.3), .black.opacity(0.5)]
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        
        // Define two rects for top-left and bottom-right
        let topLeftRect = CGRect(x: extent.minX, y: extent.midY, width: extent.width / 2, height: extent.height / 2)
        let bottomRightRect = CGRect(x: extent.midX, y: extent.minY, width: extent.width / 2, height: extent.height / 2)
        
        let color1 = averageColor(of: ciImage, in: topLeftRect) ?? .gray.opacity(0.3)
        let color2 = averageColor(of: ciImage, in: bottomRightRect) ?? .black.opacity(0.5)
        
        return [color1, color2]
    }
    
    private func averageColor(of image: CIImage, in rect: CGRect) -> Color? {
        let filter = CIFilter(name: "CIAreaAverage")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: rect), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)
        
        // Add saturation boost to make shadows pop
        let color = NSColor(red: CGFloat(bitmap[0]) / 255.0,
                            green: CGFloat(bitmap[1]) / 255.0,
                            blue: CGFloat(bitmap[2]) / 255.0,
                            alpha: 1.0)
        
        // Slightly boost saturation/brightness for a better shadow glow
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var brg: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &sat, brightness: &brg, alpha: &alpha)
        
        let vibrant = NSColor(hue: hue, saturation: min(sat * 1.5, 1.0), brightness: min(brg * 1.2, 1.0), alpha: 1.0)
        return Color(vibrant)
    }
}

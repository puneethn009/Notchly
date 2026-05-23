import SwiftUI

struct NotchShape: Shape {
    var cornerRadius: CGFloat
    
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = cornerRadius
        let tr = r * 0.7 // Top outside flare is 70% of bottom corner radius for a sleeker look
        
        if r == 0 {
            path.addRect(rect)
            return path
        }
        
        // Start top-left flare tip (flush with top edge)
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        
        // Top-right flare (concave)
        path.addArc(center: CGPoint(x: rect.maxX, y: tr),
                    radius: tr,
                    startAngle: Angle(degrees: -90),
                    endAngle: Angle(degrees: -180),
                    clockwise: true)
        
        // Right edge down to start of bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.maxY - r))
        
        // Bottom-right convex corner
        path.addArc(center: CGPoint(x: rect.maxX - tr - r, y: rect.maxY - r),
                    radius: r,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90),
                    clockwise: false)
        
        // Bottom edge
        path.addLine(to: CGPoint(x: tr + r, y: rect.maxY))
        
        // Bottom-left convex corner
        path.addArc(center: CGPoint(x: tr + r, y: rect.maxY - r),
                    radius: r,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180),
                    clockwise: false)
        
        // Left edge up to start of top-left flare
        path.addLine(to: CGPoint(x: tr, y: tr))
        
        // Top-left concave flare
        path.addArc(center: CGPoint(x: 0, y: tr),
                    radius: tr,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: -90),
                    clockwise: true)
        
        return path
    }
}

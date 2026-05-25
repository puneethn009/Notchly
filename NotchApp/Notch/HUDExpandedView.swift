import SwiftUI

struct HUDExpandedView: View {
    @ObservedObject private var state = HUDState.shared
    
    var body: some View {
        ZStack {
            // Software Pill (slightly larger than physical notch)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)
                .frame(width: 280, height: 42)
                .shadow(color: Color.black.opacity(0.4), radius: 10, y: 5)
            
            // Glowing neon stroke
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .trim(from: 0, to: CGFloat(state.value))
                .stroke(
                    state.hudType == .volume ? Color.pink : Color(hue: 0.14, saturation: 0.9, brightness: 1.0),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 280, height: 42)
                .rotationEffect(.degrees(-180)) // Start from left side
                .shadow(
                    color: (state.hudType == .volume ? Color.pink : Color(hue: 0.14, saturation: 0.9, brightness: 1.0)).opacity(0.8),
                    radius: 4
                )
            
            // Icon & Text Content
            HStack(spacing: 12) {
                Image(systemName: state.hudType == .volume ? "speaker.wave.3.fill" : "sun.max.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(state.hudType == .volume ? .pink : Color(hue: 0.14, saturation: 0.9, brightness: 1.0))
                
                // Progress Bar (Internal)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                        
                        Capsule()
                            .fill(state.hudType == .volume ? Color.pink : Color(hue: 0.14, saturation: 0.9, brightness: 1.0))
                            .frame(width: max(0, geo.size.width * CGFloat(state.value)))
                    }
                }
                .frame(height: 6)
                
                Text("\(Int(state.value * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 24)
            .frame(width: 280, height: 42)
        }
        .offset(y: state.isVisible ? 0 : -60)
        .opacity(state.isVisible ? 1.0 : 0.0)
    }
}

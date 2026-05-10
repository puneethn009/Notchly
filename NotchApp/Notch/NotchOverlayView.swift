import SwiftUI
import Combine

struct NotchOverlayView: View {
    @StateObject private var notchState = NotchState.shared
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var mediaManager = MediaPlayerManager.shared

    private let collapsedWidth: CGFloat = 192
    private let collapsedHeight: CGFloat = 31
    private let expandedWidth: CGFloat = 700
    private let expandedHeight: CGFloat = 200

    private var isExpanded: Bool { notchState.isExpanded }
    private var isSticky: Bool { notchState.isSticky }

    var body: some View {
        let width = isExpanded ? expandedWidth : (isSticky ? 300 : collapsedWidth)
        let height = isExpanded ? expandedHeight : (isSticky ? 32 : collapsedHeight)
        
        ZStack(alignment: .top) {
            // Main Notch Background Shape
            NotchShape(cornerRadius: isExpanded ? 20 : (isSticky ? 12 : 8))
                .fill(Color.black)
                .shadow(color: Color.black.opacity(isExpanded ? 0.6 : 0), radius: 30, x: 0, y: 15)
                .frame(width: width, height: height)
            
            // Content
            Group {
                if isExpanded {
                    NotchExpandedView()
                        .frame(width: expandedWidth, height: expandedHeight)
                        .clipShape(NotchShape(cornerRadius: 20))
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.75).delay(0.15)),
                            removal: .opacity.animation(.easeOut(duration: 0.1))
                        ))
                } else if isSticky {
                    if notchState.stickyType == .timer {
                        StickyTimerView()
                    } else if notchState.stickyType == .media {
                        StickyMediaView()
                    }
                } else {
                    // Static Collapsed Icons
                    HStack(spacing: 25) {
                        ZStack {
                            if SettingsManager.shared.showClosedNotchMusicIndicator && mediaManager.isPlaying {
                                VisualizerView(color: .blue, isPlaying: true)
                                    .scaleEffect(0.5)
                            } else {
                                Image(systemName: "music.note")
                            }
                        }
                        .frame(width: 14)
                        
                        Image(systemName: "timer")
                            .foregroundColor(timerManager.isRunning ? .orange : .white.opacity(0.3))
                        Image(systemName: "calendar")
                        Image(systemName: "cpu")
                        Image(systemName: "gearshape")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: collapsedWidth, height: collapsedHeight)
                    .offset(y: -1)
                }
            }
        }
        .frame(width: 900, height: 400, alignment: .top)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSticky)
    }

    // Static helper for notch width based on screen
    static func hardwareNotchWidth(for screen: NSScreen) -> CGFloat {
        if screen.safeAreaInsets.top > 30 {
            return 210 // Macbook Pro 14/16 notch
        }
        return 180 // Default
    }
}

struct StickyTimerView: View {
    @ObservedObject var timerManager = TimerManager.shared
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                Text(timerManager.currentTimerName.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1)
            }
            .foregroundColor(.orange)
            .padding(.leading, 20)
            
            Spacer()
            
            Text(timerManager.timeString)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.trailing, 20)
        }
        .frame(width: 300, height: 32)
    }
}

struct StickyMediaView: View {
    @ObservedObject var mediaManager = MediaPlayerManager.shared
    
    var body: some View {
        HStack {
            HStack {
                if let img = mediaManager.artworkImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 12))
                }
            }
            .padding(.leading, 20)
            
            Spacer()
            
            VisualizerView(color: .white, isPlaying: mediaManager.isPlaying)
                .padding(.trailing, 20)
        }
        .frame(width: 300, height: 32)
    }
}

struct VisualizerView: View {
    let color: Color
    let isPlaying: Bool
    
    @State private var heights: [CGFloat] = [10, 15, 8, 12, 10]
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: isPlaying ? heights[i] : 4)
            }
        }
        .frame(height: 20)
        .onReceive(timer) { _ in
            if isPlaying {
                withAnimation(.easeInOut(duration: 0.15)) {
                    heights = (0..<5).map { _ in CGFloat.random(in: 4...16) }
                }
            }
        }
    }
}

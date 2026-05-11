import SwiftUI
import Combine

struct NotchOverlayView: View {
    @ObservedObject private var notchState = NotchState.shared
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var mediaManager = MediaPlayerManager.shared

    private let collapsedWidth: CGFloat = 192
    private let collapsedHeight: CGFloat = 30
    private let expandedWidth: CGFloat = 700
    private let expandedHeight: CGFloat = 200

    @State private var currentRadius: CGFloat = 6
    
    private var isExpanded: Bool { notchState.isExpanded }
    private var isSticky: Bool { notchState.isSticky }

    var body: some View {
        let isShowingPopup = notchState.isShowingScreenshotPopup && !isExpanded
        let isRunning = mediaManager.isPlaying || timerManager.isRunning || timerManager.isStopwatchRunning
        let width = isExpanded ? expandedWidth : (isShowingPopup ? 280 : (isSticky ? 300 : collapsedWidth))
        let height = isExpanded ? expandedHeight : (isShowingPopup ? 36 : (isSticky ? 34 : (isRunning ? 31 : collapsedHeight)))
        
        ZStack(alignment: .top) {
            // Main Interaction Surface
            ZStack(alignment: .top) {
                // Background
                NotchShape(cornerRadius: currentRadius)
                    .fill(Color.black)
                    .shadow(color: Color.black.opacity((isExpanded || notchState.isHovering || isShowingPopup) ? 0.5 : 0), radius: isExpanded ? 20 : 8, x: 0, y: isExpanded ? 10 : 4)
                    .onAppear {
                        currentRadius = isExpanded ? 20 : (isSticky ? 12 : 6)
                    }
                    .onChange(of: isExpanded) { expanded in
                        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45)) {
                            currentRadius = expanded ? 20 : (isSticky ? 12 : 6)
                        }
                    }
                    .onChange(of: isSticky) { sticky in
                        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45)) {
                            currentRadius = isExpanded ? 20 : (sticky ? 12 : 6)
                        }
                    }
                
                // Content
                Group {
                    if isExpanded {
                        NotchExpandedView()
                            .frame(width: expandedWidth, height: expandedHeight)
                            .clipShape(NotchShape(cornerRadius: 20))
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.75).delay(0.2)),
                                removal: .opacity.animation(.easeOut(duration: 0.1))
                            ))
                    } else if isShowingPopup {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .foregroundColor(.blue)
                                .font(.system(size: 14, weight: .bold))
                            
                            Text("New Screenshot Captured")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if let url = notchState.lastCapturedScreenshotURL,
                               let image = NSImage(contentsOf: url) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 34, height: 22)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(width: 280, height: 36)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
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
                            
                            ZStack {
                                if SettingsManager.shared.showClosedNotchTimerIndicator && (timerManager.isRunning || timerManager.isStopwatchRunning) {
                                    Image(systemName: "timer")
                                        .foregroundColor(.orange)
                                } else {
                                    Image(systemName: "timer")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                            .frame(width: 14)
                            
                            Image(systemName: "calendar")
                            Image(systemName: "cpu")
                            Image(systemName: "gearshape")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: collapsedWidth, height: 30)
                        .offset(y: -1)
                    }
                }
            }
            .frame(width: width, height: height)
            .contentShape(NotchShape(cornerRadius: currentRadius))
            .onHover { hovering in
                notchState.isHovering = hovering
                if hovering && !isExpanded {
                    withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45)) {
                        notchState.isExpanded = true
                    }
                }
            }
        }
        .frame(width: 900, height: 400, alignment: .top)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45), value: isExpanded)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45), value: isSticky)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45), value: isShowingPopup)
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
                Image(systemName: timerManager.isRunning ? "timer" : "stopwatch")
            }
            .foregroundColor(.orange)
            .padding(.leading, 20)
            
            Spacer()
            
            Text(timerManager.isRunning ? timerManager.timeString : timerManager.stopwatchShortString)
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

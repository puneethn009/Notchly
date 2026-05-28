import SwiftUI
import Combine
import SwiftData

struct NotchOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TodoItem> { !$0.isCompleted }, sort: [SortDescriptor(\TodoItem.createdAt, order: .forward)]) private var pendingTasks: [TodoItem]
    
    @ObservedObject private var notchState = NotchState.shared
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var mediaManager = MediaPlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    private let collapsedWidth: CGFloat = 192
    private let collapsedHeight: CGFloat = 32
    private let expandedWidth: CGFloat = 700
    private var expandedHeight: CGFloat { 200 + notchState.extraHeight }

    @State private var currentRadius: CGFloat = 9
    
    private var isExpanded: Bool { notchState.isExpanded }
    private var isSticky: Bool { notchState.isSticky }

    private var notchWidth: CGFloat {
        if isExpanded { return expandedWidth }
        if notchState.isShowingScreenshotPopup { return 280 }
        if isSticky {
            if notchState.stickyType == .todo { return 380 }
            if notchState.stickyType == .clipboard { return 340 }
            return 300
        }
        return collapsedWidth
    }
    
    private var notchHeight: CGFloat {
        if isExpanded { return expandedHeight }
        if notchState.isShowingScreenshotPopup { return 35 }
        return collapsedHeight
    }

    var body: some View {
        let isShowingPopup = notchState.isShowingScreenshotPopup && !isExpanded
        let width = notchWidth
        let height = notchHeight
        
        ZStack(alignment: .top) {
            // Main Interaction Surface
            ZStack(alignment: .top) {
                // Background
                NotchShape(cornerRadius: currentRadius)
                    .fill(Color.black)
                    .shadow(color: Color.black.opacity((isExpanded || notchState.isHovering || isShowingPopup) ? 0.5 : 0), radius: isExpanded ? 20 : 8, x: 0, y: isExpanded ? 10 : 4)
                    .onAppear {
                        currentRadius = isExpanded ? 20 : (isSticky ? 12 : 9)
                    }
                    .onChange(of: isExpanded) { oldValue, expanded in
                        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45)) {
                            currentRadius = expanded ? 20 : (isSticky ? 12 : 9)
                        }
                    }
                    .onChange(of: isSticky) { oldValue, sticky in
                        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45)) {
                            currentRadius = isExpanded ? 20 : (sticky ? 12 : 9)
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
                        .clipShape(NotchShape(cornerRadius: currentRadius))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else if isSticky {
                        ZStack {
                            if notchState.stickyType == .clipboard {
                                StickyClipboardCopiedView().transition(.opacity)
                            } else if notchState.stickyType == .todo {
                                StickyTodoView().transition(.opacity)
                            } else if notchState.stickyType == .timer {
                                StickyTimerView().transition(.opacity)
                            } else if notchState.stickyType == .media {
                                StickyMediaView().transition(.opacity)
                            }
                        }
                        .frame(width: width, height: collapsedHeight)
                        .clipShape(NotchShape(cornerRadius: currentRadius))
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeIn(duration: 0.3).delay(0.1)),
                            removal: .opacity.animation(.easeOut(duration: 0.1))
                        ))
                    } else {
                        // Static Collapsed Icons
                        HStack(spacing: 25) {
                            ZStack {
                                if settings.showClosedNotchMusicIndicator && mediaManager.isPlaying {
                                    VisualizerView(isPlaying: true)
                                        .scaleEffect(0.5)
                                } else {
                                    Image(systemName: "music.note")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                            .frame(width: 14)
                            
                            ZStack {
                                if settings.showClosedNotchTimerIndicator && (timerManager.isRunning || timerManager.isStopwatchRunning) {
                                    Image(systemName: "timer")
                                        .foregroundColor(.orange)
                                } else {
                                    Image(systemName: "timer")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                            .frame(width: 14)
                            
                            ZStack {
                                Image(systemName: "checklist")
                                    .foregroundColor(.white.opacity(0.3))
                                
                                if notchState.hasOverdueTodo && settings.todoShowOverdue {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 4, height: 4)
                                        .offset(x: 6, y: -6)
                                } else if pendingTasks.first != nil {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 4, height: 4)
                                        .offset(x: 6, y: -6)
                                }
                            }
                            
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
        .frame(width: 900, height: 800, alignment: .top)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45), value: isExpanded)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45), value: isSticky)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45), value: notchState.stickyType)
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
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                        .offset(x: -3, y: -2)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .offset(x: -3, y: -1)
                }
            }
            .padding(.leading, 20)
            
            Spacer()
            
            VisualizerView(isPlaying: mediaManager.isPlaying)
                .offset(y: -2)
                .padding(.trailing, 20)
        }
        .frame(width: 300, height: 32)
    }
}

struct VisualizerView: View {
    let isPlaying: Bool
    
    @State private var heights: [CGFloat] = [10, 15, 8, 12, 10]
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(MediaPlayerManager.shared.primaryArtworkColor)
                    .frame(width: 2, height: isPlaying ? heights[i] : 4)
            }
        }
        .frame(height: 20)
        .onReceive(timer) { _ in
            if isPlaying {
                withAnimation(.easeInOut(duration: 0.15)) {
                    for i in 0..<5 {
                        heights[i] = CGFloat.random(in: 4...18)
                    }
                }
            }
        }
    }
}

struct StickyTodoView: View {
    @State private var pulse = false
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.leading, 20)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .scaleEffect(pulse ? 1.4 : 1.0)
                    .opacity(pulse ? 0.7 : 1.0)
                    .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                Text("Overdue")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 16)
        }
        .frame(width: 380, height: 32)
        .onAppear {
            pulse = true
        }
    }
}

struct StickyClipboardCopiedView: View {
    @State private var showCheck = false
    @State private var showText = false
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if showCheck {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "doc.on.clipboard.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 14))
                }
            }
            .padding(.leading, 24)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showCheck)
            
            Spacer()
            
            if showText {
                Text("Copied")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.trailing, 24)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: 340, height: 32)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showCheck = true
                    showText = true
                }
            }
        }
    }
}

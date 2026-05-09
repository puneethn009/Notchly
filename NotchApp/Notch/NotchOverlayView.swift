import SwiftUI

struct NotchOverlayView: View {
    @StateObject private var notchState = NotchState.shared

    // ... (hardwareNotchWidth stays same)
    static func hardwareNotchWidth(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *) {
            if let left = screen.auxiliaryTopLeftArea,
               let right = screen.auxiliaryTopRightArea {
                let w = screen.frame.width - left.width - right.width
                if w > 0 { return w }
            }
        }
        return 126
    }

    var collapsedWidth: CGFloat {
        NotchOverlayView.hardwareNotchWidth(for: NSScreen.main ?? NSScreen.screens[0])
    }
    var collapsedHeight: CGFloat {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let inset = screen.safeAreaInsets.top
        return inset > 0 ? inset : 37
    }

    let expandedWidth: CGFloat = 680
    let expandedHeight: CGFloat = 180

    var body: some View {
        let _ = print("[NotchOverlayView] Rendering (isExpanded: \(notchState.isExpanded))")
        return ZStack(alignment: .top) {
            NotchShape(cornerRadius: notchState.isExpanded ? 16 : 8)
                .fill(Color.black)
                .shadow(color: Color.black.opacity(notchState.isExpanded ? 0.5 : 0), radius: 25, x: 0, y: 15)
                .frame(
                    width: notchState.isExpanded ? expandedWidth : collapsedWidth,
                    height: notchState.isExpanded ? expandedHeight : collapsedHeight
                )

            if notchState.isExpanded {
                NotchExpandedView()
                    .frame(width: expandedWidth, height: expandedHeight)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.2).delay(0.1)),
                        removal: .opacity.animation(.easeOut(duration: 0.1))
                    ))
            }
        }
        .frame(width: 740, height: 240, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: notchState.isExpanded)
    }
}

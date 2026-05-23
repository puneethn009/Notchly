import SwiftUI
import AppKit

class ScreenshotPreviewController: NSObject {
    static let shared = ScreenshotPreviewController()
    private var window: NSPanel?
    private var timer: Timer?
    
    func showPreview(for url: URL) {
        if window != nil {
            hidePreview()
        }
        
        let previewView = ScreenshotFloatingPreview(url: url) { [weak self] action in
            self?.handleAction(action, url: url)
        }
        
        let hostingView = NSHostingView(rootView: previewView)
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 224, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false // SwiftUI handles the rounded shadow
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView
        
        // Position in bottom right, above the Dock
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let padding: CGFloat = 20
            let bottomOffset: CGFloat = 16 // Extra clearance for the Dock
            panel.setFrameOrigin(NSPoint(
                x: screenFrame.maxX - 224 - padding,
                y: screenFrame.minY + padding + bottomOffset
            ))
        }
        
        panel.orderFrontRegardless()
        self.window = panel
        
        // Auto-hide after 10 seconds if no action
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.handleAction(.autoSave, url: url)
        }
    }
    
    func hidePreview() {
        window?.orderOut(nil)
        window = nil
        timer?.invalidate()
        timer = nil
    }
    
    private func handleAction(_ action: ScreenshotPreviewAction, url: URL) {
        switch action {
        case .save:
            hidePreview()
            // Trigger Notch naming
            Task { @MainActor in
                NotchState.shared.pendingScreenshotURL = url
                NotchState.shared.isExpanded = true
                NSApp.activate(ignoringOtherApps: true)
                NotchWindowController.shared.window?.makeKeyAndOrderFront(nil)
            }
        case .autoSave:
            hidePreview()
            Task { @MainActor in
                NotchState.shared.pendingScreenshotURL = url
                ScreenshotMonitor.shared.finalizePendingScreenshot(withName: "")
            }
        case .copy:
            if let image = NSImage(contentsOf: url) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([image])
            }
            hidePreview()
            try? FileManager.default.removeItem(at: url)
        case .edit:
            hidePreview()
            ScreenshotEditorWindowController.shared.open(with: url)
        case .close:
            hidePreview()
            try? FileManager.default.removeItem(at: url)
        }
    }
}

enum ScreenshotPreviewAction {
    case save, copy, edit, close, autoSave
}

struct ScreenshotFloatingPreview: View {
    let url: URL
    let onAction: (ScreenshotPreviewAction) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .onDrag {
                            let provider = NSItemProvider(object: image)
                            return provider
                        }
                }
                
                Button(action: { onAction(.close) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.8))
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            
            HStack(spacing: 4) {
                PreviewActionButton(icon: "pencil.and.outline", label: "Edit") { onAction(.edit) }
                PreviewActionButton(icon: "doc.on.doc.fill", label: "Copy") { onAction(.copy) }
                PreviewActionButton(icon: "folder.fill.badge.plus", label: "Save") { onAction(.save) }
            }
            .padding(4)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .padding(12)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                RoundedRectangle(cornerRadius: 24)
                    .stroke(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

struct PreviewActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

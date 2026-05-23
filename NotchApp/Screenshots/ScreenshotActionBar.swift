import SwiftUI
import AppKit

struct ScreenshotActionBar: View {
    let item: ScreenshotItem
    
    var body: some View {
        HStack(spacing: 16) {
            ActionButton(icon: "eye.fill", label: "Preview", color: .white) {
                NSWorkspace.shared.open(URL(fileURLWithPath: item.filePath))
            }
            
            ActionButton(icon: "doc.on.doc.fill", label: "Copy Text", color: .blue) {
                if let text = item.extractedText {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
            
            ActionButton(icon: "photo.fill", label: "Copy Image", color: .purple) {
                if let image = NSImage(contentsOfFile: item.filePath) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([image])
                }
            }
            
            ActionButton(icon: "folder.fill", label: "Finder", color: .orange) {
                NSWorkspace.shared.selectFile(item.filePath, inFileViewerRootedAtPath: "")
            }
            
            ActionButton(icon: "square.and.arrow.up", label: "Share", color: .green) {
                let url = URL(fileURLWithPath: item.filePath)
                let picker = NSSharingServicePicker(items: [url])
                picker.show(relativeTo: .zero, of: NSView(), preferredEdge: .minY)
            }
            
            ActionButton(icon: "pencil.circle.fill", label: "Edit", color: .blue) {
                let url = URL(fileURLWithPath: item.filePath)
                ScreenshotEditorWindowController.shared.open(with: url)
            }
            
            ActionButton(icon: "trash.fill", label: "Delete", color: .red) {
                // Move to Trash
                NSWorkspace.shared.recycle([URL(fileURLWithPath: item.filePath)]) { _, _ in
                    DispatchQueue.main.async {
                        // Delete from DB is handled by the caller or via environment
                        NotificationCenter.default.post(name: NSNotification.Name("DeleteScreenshot"), object: item)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            Capsule()
                .fill(Color.black)
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        )
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isHovering ? color.opacity(0.15) : Color.white.opacity(0.05))
                        .shadow(color: isHovering ? color.opacity(0.3) : .clear, radius: 8)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isHovering ? color : .white.opacity(0.8))
                }
                .frame(width: 48, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isHovering ? color.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 0.5)
                )
                
                Text(label)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(isHovering ? .white : .white.opacity(0.5))
                    .textCase(.uppercase)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
    }
}

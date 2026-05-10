import SwiftUI
import AppKit

struct ScreenshotActionBar: View {
    let item: ScreenshotItem
    
    var body: some View {
        HStack(spacing: 12) {
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
            
            ActionButton(icon: "folder.fill", label: "Show in Finder", color: .orange) {
                NSWorkspace.shared.selectFile(item.filePath, inFileViewerRootedAtPath: "")
            }
            
            ActionButton(icon: "square.and.arrow.up", label: "Share", color: .green) {
                let picker = NSSharingServicePicker(items: [URL(fileURLWithPath: item.filePath)])
                // Note: Picker positioning usually requires a view reference
                picker.show(relativeTo: .zero, of: NSView(), preferredEdge: .minY)
            }
        }
        .padding(.horizontal)
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(isHovering ? 0.3 : 0.15))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                }
                .frame(width: 44, height: 44)
                
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

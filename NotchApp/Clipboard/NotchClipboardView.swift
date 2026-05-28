import SwiftUI
import SwiftData
import AppKit

struct NotchClipboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.copiedAt, order: .reverse) private var clipboardItems: [ClipboardItem]
    
    @ObservedObject private var notchState = NotchState.shared
    
    @State private var copiedItemId: UUID? = nil
    @State private var selectedFilter: String = "All"
    @State private var scrollMonitor: Any?
    
    let filters = ["All", "Link", "Code", "Email", "Number", "Color", "Text"]
    
    private var sortedItems: [ClipboardItem] {
        clipboardItems.filter { item in
            selectedFilter == "All" || item.contentType == selectedFilter
        }.sorted {
            if $0.isPinned == $1.isPinned {
                return $0.copiedAt > $1.copiedAt
            }
            return $0.isPinned && !$1.isPinned
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Clipboard History")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 36)
            .padding(.top, 2)
            .padding(.bottom, 16)
            
            // Filters
            if !clipboardItems.isEmpty && notchState.extraHeight > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { filter in
                            Button(action: {
                                withAnimation { selectedFilter = filter }
                            }) {
                                Text(filter)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(selectedFilter == filter ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                    )
                                    .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 8)
                }
            }
            
            // List
            ScrollView {
                LazyVStack(spacing: 8) {
                    if clipboardItems.isEmpty {
                        Text("No clipboard history yet.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 20)
                    } else {
                        ForEach(sortedItems) { item in
                            ClipboardRowView(item: item, isCopied: copiedItemId == item.id) {
                                // Copy action
                                copyToPasteboard(item: item)
                            } togglePin: {
                                // Pin action
                                item.isPinned.toggle()
                                try? modelContext.save()
                            } deleteAction: {
                                // Delete action
                                modelContext.delete(item)
                                try? modelContext.save()
                            }
                            // Drag and Drop support
                            .onDrag {
                                NSItemProvider(object: item.content as NSString)
                            }
                        }
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: notchState.extraHeight > 0 ? 300 : 130)
        }
        .onAppear {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                if NotchState.shared.selectedPage == .clipboard && NotchState.shared.isHovering {
                    handleScroll(event: event)
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
    
    private func handleScroll(event: NSEvent) {
        let deltaY = event.scrollingDeltaY
        if deltaY < -2 && notchState.extraHeight == 0 && !clipboardItems.isEmpty {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                notchState.extraHeight = 200
            }
        } else if deltaY > 15 && notchState.extraHeight > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                notchState.extraHeight = 0
            }
        }
    }
    
    private func copyToPasteboard(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        
        withAnimation {
            copiedItemId = item.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                if copiedItemId == item.id {
                    copiedItemId = nil
                }
            }
        }
    }
}

struct ClipboardRowView: View {
    var item: ClipboardItem
    var isCopied: Bool
    var onCopy: () -> Void
    var togglePin: () -> Void
    var deleteAction: () -> Void
    
    @State private var isHovering = false
    
    private var previewText: String {
        item.content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        HStack {
            // Icon representing the content type
            Image(systemName: iconForContentType(item.contentType))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(previewText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(item.sourceApp)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            if isHovering || item.isPinned {
                HStack(spacing: 8) {
                    if isHovering && !item.isPinned {
                        Button(action: deleteAction) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(4)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: togglePin) {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 12))
                            .foregroundColor(item.isPinned ? .orange : .white.opacity(0.5))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 4)
            }
            
            Button(action: onCopy) {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundColor(isCopied ? .green : .white.opacity(0.6))
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isHovering ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    private func iconForContentType(_ type: String) -> String {
        switch type {
        case "Link": return "link"
        case "Email": return "envelope"
        case "Code": return "curlybraces"
        case "Color": return "paintpalette"
        case "Number": return "number"
        default: return "doc.plaintext"
        }
    }
}

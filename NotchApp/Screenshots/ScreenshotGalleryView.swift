import SwiftUI
import SwiftData

struct ScreenshotGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenshotItem.capturedAt, order: .reverse) private var items: [ScreenshotItem]
    @State private var searchText = ""
    @State private var selectedItem: ScreenshotItem?
    // Hover is now handled via PreviewWindowController
    
    var filteredItems: [ScreenshotItem] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { 
                $0.extractedText?.localizedCaseInsensitiveContains(searchText) ?? false ||
                $0.filename.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 12)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search text, code, or receipts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            .frame(maxWidth: 300)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.1))
                    Text("No screenshots yet")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            ScreenshotThumbnail(item: item)
                                .onHover { isHovering in
                                    if isHovering {
                                        let mouseLoc = NSEvent.mouseLocation
                                        PreviewWindowController.shared.showPreview(item: item, at: mouseLoc)
                                    } else {
                                        PreviewWindowController.shared.hidePreview()
                                    }
                                }
                                .onTapGesture {
                                    PreviewWindowController.shared.hidePreview()
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedItem = item
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 40) // Increased padding for edge breathing room
                }
                .frame(height: 100) // Fixed height for horizontal reel
                .padding(.bottom, 10)
            }
        }
        .overlay {
            if let item = selectedItem {
                ScreenshotDetailOverlay(item: item) {
                    selectedItem = nil
                }
                .zIndex(200)
            }
        }
    }
}

struct ScreenshotThumbnail: View {
    let item: ScreenshotItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                if let image = NSImage(contentsOfFile: item.filePath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 100, height: 60)
                        .overlay(Image(systemName: "photo").foregroundColor(.white.opacity(0.2)))
                }
                
                // Content Type Badge
                Image(systemName: iconForType(item.contentType))
                    .font(.system(size: 8, weight: .bold))
                    .padding(3)
                    .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).clipShape(Circle()))
                    .padding(3)
            }
            
            Text(item.filename)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
                .frame(width: 100)
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch ContentType(rawValue: type) {
        case .qrCode: return "qrcode"
        case .receipt: return "scroll"
        case .codeSnippet: return "chevron.left.forwardslash.chevron.right"
        case .uiScreenshot: return "macwindow"
        case .textDocument: return "doc.text"
        default: return "photo"
        }
    }
}

struct ScreenshotDetailOverlay: View {
    let item: ScreenshotItem
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            // Full solid black background
            Color.black
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            
            VStack(spacing: 12) { // Slightly tighter spacing to pull items up
                // Header with close button
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
                .padding(.top, 16)
                
                if let image = NSImage(contentsOfFile: item.filePath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 130) // Tighter height
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.5), radius: 20)
                }
                
                ScreenshotActionBar(item: item)
                    .scaleEffect(0.85) // Slightly more compact
                
                if let text = item.extractedText, !text.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXTRACTED TEXT")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white.opacity(0.3))
                        
                        ScrollView {
                            Text(text)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 45) // Slightly shorter
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20) // Pull up from bottom
                }
                
                Spacer(minLength: 40) // Increased bottom spacer to keep everything high
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 1.01)))
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

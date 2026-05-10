import SwiftUI
import SwiftData

struct ScreenshotGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenshotItem.capturedAt, order: .reverse) private var items: [ScreenshotItem]
    @State private var searchText = ""
    @State private var selectedItem: ScreenshotItem?
    
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
                                .onTapGesture {
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
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            
            VStack(spacing: 20) {
                if let image = NSImage(contentsOfFile: item.filePath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 20)
                }
                
                ScreenshotActionBar(item: item)
                
                if let text = item.extractedText, !text.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EXTRACTED TEXT")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white.opacity(0.4))
                        
                        ScrollView {
                            Text(text)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 100)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 30)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).clipShape(RoundedRectangle(cornerRadius: 24)))
            .padding(20)
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(32)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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

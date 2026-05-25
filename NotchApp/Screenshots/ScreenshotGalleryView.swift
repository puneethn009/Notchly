import SwiftUI
import SwiftData

struct ScreenshotGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenshotItem.capturedAt, order: .reverse) private var items: [ScreenshotItem]
    
    @State private var searchText = ""
    @State private var selectedItem: ScreenshotItem?
    @State private var isWiggleMode: Bool = false
    
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
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    if isWiggleMode {
                        Text("EDIT MODE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.red)
                            .tracking(2)
                    } else {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search screenshots...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                        .frame(maxWidth: 250)
                    }
                    
                    Spacer()
                    
                    if isWiggleMode {
                        Button("Done") {
                            withAnimation(.spring()) {
                                isWiggleMode = false
                            }
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 40)
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
                        HStack(spacing: 16) {
                            Spacer(minLength: 40)
                            
                            ForEach(Array(filteredItems.prefix(4))) { item in
                                ScreenshotThumbnail(
                                    item: item,
                                    isWiggling: isWiggleMode,
                                    onDelete: {
                                        deleteItem(item)
                                    }
                                )
                                .onTapGesture {
                                    if !isWiggleMode {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedItem = item
                                        }
                                    }
                                }
                                .onLongPressGesture {
                                    withAnimation(.spring()) {
                                        isWiggleMode = true
                                    }
                                }
                            }
                            
                            Button(action: {
                                NotchlyHubWindowController.shared.show()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    NotificationCenter.default.post(name: NSNotification.Name("OpenScreenshotManager"), object: nil)
                                }
                                NotchState.shared.isExpanded = false
                            }) {
                                VStack(alignment: .center, spacing: 4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                            .frame(width: 100, height: 60)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                                        
                                        VStack(spacing: 4) {
                                            Image(systemName: "square.grid.2x2.fill")
                                                .font(.system(size: 16))
                                            Text("View All")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .foregroundColor(.white.opacity(0.7))
                                    }
                                    
                                    Text("Manager")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 100)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Spacer(minLength: 40)
                        }
                        .frame(minWidth: 700)
                    }
                    .frame(height: 100)
                    .padding(.bottom, 10)
                }
            }
            .onTapGesture {
                // Tapping anywhere in the gallery area (between items) exits wiggle mode
                if isWiggleMode {
                    withAnimation(.spring()) {
                        isWiggleMode = false
                    }
                }
            }
        }
        .overlay {
            if let item = selectedItem {
                ScreenshotDetailOverlay(item: item) {
                    selectedItem = nil
                }
                .zIndex(200)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    private func deleteItem(_ item: ScreenshotItem) {
        NSWorkspace.shared.recycle([URL(fileURLWithPath: item.filePath)]) { _, _ in
            DispatchQueue.main.async {
                modelContext.delete(item)
                try? modelContext.save()
            }
        }
    }
}

struct ScreenshotThumbnail: View {
    let item: ScreenshotItem
    let isWiggling: Bool
    let onDelete: () -> Void
    
    @State private var wiggleRotation: Double = 0
    @State private var randomDelay: Double = Double.random(in: 0...0.15)
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .center, spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    if let image = NSImage(contentsOfFile: item.filePath) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 100, height: 60)
                    }
                    
                    // Content Type Badge
                    Image(systemName: iconForType(item.contentType))
                        .font(.system(size: 7, weight: .bold))
                        .padding(3)
                        .background(Color.black.opacity(0.6).clipShape(Circle()))
                        .padding(4)
                }
                .scaleEffect(isWiggling ? 0.98 : 1.0)
                .rotationEffect(.degrees(isWiggling ? wiggleRotation : 0))
                .animation(isWiggling ? 
                           Animation.easeInOut(duration: 0.15)
                            .repeatForever(autoreverses: true)
                            .delay(randomDelay) : 
                           .spring(response: 0.3, dampingFraction: 0.7), value: isWiggling)
                .animation(isWiggling ? 
                           Animation.easeInOut(duration: 0.15)
                            .repeatForever(autoreverses: true)
                            .delay(randomDelay) : 
                           .default, value: wiggleRotation)
                
                Text(item.filename)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
                    .frame(width: 100)
            }
            
            if isWiggling {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .onAppear {
            if isWiggling {
                startWiggling()
            }
        }
        .onChange(of: isWiggling) { _, wiggling in
            if wiggling {
                startWiggling()
            } else {
                wiggleRotation = 0
            }
        }
    }
    
    private func startWiggling() {
        wiggleRotation = -0.8
        withAnimation {
            wiggleRotation = 0.8
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
    @Environment(\.modelContext) private var modelContext
    let item: ScreenshotItem
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            
            VStack(spacing: 12) {
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
                        .frame(maxHeight: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.5), radius: 20)
                }
                
                ScreenshotActionBar(item: item)
                    .scaleEffect(0.85)
                
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
                        .frame(maxHeight: 45)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
                
                Spacer(minLength: 40)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeleteScreenshot"))) { notification in
            if let item = notification.object as? ScreenshotItem {
                modelContext.delete(item)
                try? modelContext.save()
                withAnimation {
                    onClose()
                }
            }
        }
    }
}

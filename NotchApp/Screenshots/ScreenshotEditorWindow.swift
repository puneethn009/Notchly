import SwiftUI
import AppKit
import Vision
import SwiftData

class ScreenshotEditorWindowController: NSWindowController {
    static let shared = ScreenshotEditorWindowController()
    
    private var editorView: ScreenshotEditorView?
    
    func open(with url: URL) {
        if let window = self.window, window.isVisible {
            window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: 1250, height: 800), display: true, animate: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let editorState = ScreenshotEditorState(imageURL: url)
        let view = ScreenshotEditorView(state: editorState)
            .modelContainer(PersistenceController.shared.container)
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1250, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Screenshot Editor"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.contentViewController = hostingController
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum CanvasTool: String, CaseIterable {
    case pen, highlighter, marker, arrow, rectangle, circle, text, erase
}

enum BackgroundType: Equatable {
    case color(Color)
    case gradient([Color])
}

struct CanvasAnnotation: Identifiable, Equatable {
    let id = UUID()
    var tool: CanvasTool
    var color: Color
    var points: [CGPoint] = []
    var text: String = ""
    var lineWidth: CGFloat = 3
    var opacity: Double = 1.0
}

@Observable
class ScreenshotEditorState {
    var imageURL: URL
    var currentImage: NSImage?
    var extractedText: String = ""
    var extractedImages: [NSImage] = []
    
    // Annotation History
    var annotations: [CanvasAnnotation] = []
    private var redoStack: [CanvasAnnotation] = []
    
    var currentAnnotation: CanvasAnnotation?
    var selectedTool: CanvasTool = .pen
    var selectedColor: Color = .red
    var canvasBackground: BackgroundType = .color(Color(white: 0.08))
    
    init(imageURL: URL) {
        self.imageURL = imageURL
        self.currentImage = NSImage(contentsOf: imageURL)
        analyzeImage()
    }
    
    func startDrawing(at point: CGPoint, in size: CGSize) {
        let normalizedPoint = CGPoint(x: point.x / size.width, y: point.y / size.height)
        
        var lineWidth: CGFloat = 3
        var opacity: Double = 1.0
        
        switch selectedTool {
        case .highlighter:
            lineWidth = 20
            opacity = 0.4
        case .marker:
            lineWidth = 8
            opacity = 1.0
        case .pen:
            lineWidth = 3
            opacity = 1.0
        default:
            lineWidth = 3
            opacity = 1.0
        }
        
        currentAnnotation = CanvasAnnotation(
            tool: selectedTool,
            color: selectedColor,
            points: [normalizedPoint],
            lineWidth: lineWidth,
            opacity: opacity
        )
    }
    
    func updateDrawing(to point: CGPoint, in size: CGSize) {
        let normalizedPoint = CGPoint(x: point.x / size.width, y: point.y / size.height)
        currentAnnotation?.points.append(normalizedPoint)
    }
    
    func endDrawing() {
        if let annotation = currentAnnotation {
            annotations.append(annotation)
            redoStack.removeAll() // Clear redo on new action
            currentAnnotation = nil
        }
    }
    
    func undo() {
        guard !annotations.isEmpty else { return }
        let removed = annotations.removeLast()
        redoStack.append(removed)
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        let restored = redoStack.removeLast()
        annotations.append(restored)
    }
    
    func analyzeImage() {
        Task {
            let result = await ScreenshotAnalyzer.shared.analyze(imageURL: imageURL)
            await MainActor.run {
                self.extractedText = result.text
            }
        }
    }
    
    func removeBackground() {
        guard let image = currentImage,
              let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage)
        
        Task {
            do {
                try handler.perform([request])
                guard let result = request.results?.first else { return }
                print("Mask generated successfully")
            } catch {
                print("BG Removal Error: \(error)")
            }
        }
    }
}


struct ScreenshotEditorView: View {
    @Bindable var state: ScreenshotEditorState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenshotItem.capturedAt, order: .reverse) private var items: [ScreenshotItem]
    
    var body: some View {
        ZStack {
            // Full window background with dynamic coloring/gradients
            Group {
                switch state.canvasBackground {
                case .color(let color):
                    color
                case .gradient(let colors):
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            HStack(spacing: 0) {
                // Left Sidebar: Smart Extraction / Insights
                ZStack {
                    VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Space for window controls
                        Spacer().frame(height: 50)
                        
                        Text("INSIGHTS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white.opacity(0.3))
                            .tracking(1)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "text.viewfinder")
                                Text("Live Text")
                            }
                            .font(.system(size: 12, weight: .bold))
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(state.extractedText, forType: .string)
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc.fill")
                                    Text("Copy Results")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            
                            ScrollView {
                                Text(state.extractedText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineSpacing(4)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .padding(.top, 60)
                }
                .frame(width: 240)

                // Main Canvas Area (Center Column)
                ZStack(alignment: .center) {
                    // Perfectly Symmetrical Background Frame
                    if let image = state.currentImage {
                        ZStack {
                            // The Selected Background (Framed to the image)
                            Group {
                                switch state.canvasBackground {
                                case .color(let color):
                                    color
                                case .gradient(let colors):
                                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            // The Screenshot
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(60) // Absolute equal padding on all sides
                                .overlay(
                                    GeometryReader { geo in
                                        Canvas { context, size in
                                            for annotation in state.annotations {
                                                drawAnnotation(annotation, in: context, size: size)
                                            }
                                            if let current = state.currentAnnotation {
                                                drawAnnotation(current, in: context, size: size)
                                            }
                                        }
                                        .background(Color.white.opacity(0.001))
                                        .gesture(
                                            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                                .onChanged { value in
                                                    if state.currentAnnotation == nil {
                                                        state.startDrawing(at: value.location, in: geo.size)
                                                    } else {
                                                        state.updateDrawing(to: value.location, in: geo.size)
                                                    }
                                                }
                                                .onEnded { _ in
                                                    state.endDrawing()
                                                }
                                        )
                                    }
                                )
                        }
                        .fixedSize(horizontal: false, vertical: true) // Hug the content vertically
                        .padding(40) // Spacing from sidebars
                    }
                    
                    // Floating Background Presets (Overlay style at top)
                    VStack(spacing: 0) {
                        Spacer().frame(height: 104)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                BackgroundPresetButton(type: .color(Color(white: 0.08)), current: $state.canvasBackground)
                                BackgroundPresetButton(type: .color(.black), current: $state.canvasBackground)
                                
                                Divider().frame(height: 16).background(Color.white.opacity(0.1))
                                
                                BackgroundPresetButton(type: .gradient([Color(hex: "FF512F"), Color(hex: "DD2476")]), current: $state.canvasBackground)
                                BackgroundPresetButton(type: .gradient([Color(hex: "1FA2FF"), Color(hex: "12D8FA"), Color(hex: "A6FFCB")]), current: $state.canvasBackground)
                                
                                Divider().frame(height: 16).background(Color.white.opacity(0.1))
                                
                                BackgroundPresetButton(type: .gradient([Color(hex: "00F260"), Color(hex: "0575E6"), Color(hex: "642BBD"), Color(hex: "FF00CC")]), current: $state.canvasBackground)
                                BackgroundPresetButton(type: .gradient([Color(hex: "833ab4"), Color(hex: "fd1d1d"), Color(hex: "fcb045"), Color(hex: "ff0084"), Color(hex: "3300ff")]), current: $state.canvasBackground)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.4))
                                    .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).clipShape(Capsule()))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            )
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.2)) // Base studio floor

                // Right Sidebar: Session/All Screenshots (Preview Style)
                ZStack {
                    VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                    
                    VStack(spacing: 0) {
                        // Space for window controls (Symmetry)
                        Spacer().frame(height: 50)
                        
                        Text("THUMBNAILS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white.opacity(0.3))
                            .tracking(1)
                            .padding(.top, 40)
                            .padding(.bottom, 20)
                        
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                ForEach(items) { item in
                                    VStack(spacing: 6) {
                                        Button(action: { 
                                            state.imageURL = URL(fileURLWithPath: item.filePath)
                                            state.currentImage = NSImage(contentsOf: state.imageURL)
                                            state.analyzeImage()
                                        }) {
                                            ZStack {
                                                AsyncImage(url: URL(fileURLWithPath: item.filePath)) { img in
                                                    img.resizable().aspectRatio(contentMode: .fit)
                                                } placeholder: {
                                                    Color.white.opacity(0.05)
                                                }
                                                .frame(width: 120, height: 90)
                                                .background(Color.black.opacity(0.2))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                                            }
                                            .padding(8)
                                            .background(state.imageURL.path == item.filePath ? Color.blue.opacity(0.3) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text(item.filename)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(.white.opacity(0.5))
                                            .lineLimit(1)
                                            .frame(width: 120)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 60)
                }
                .frame(width: 160)
            }
            
            // GLOBAL OVERLAY TOOLBAR (Wide over sidebars)
            VStack {
                HStack(spacing: 12) {
                    // Discard Action
                    Button(action: { /* Discard logic */ }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    
                    Divider().frame(height: 20).background(Color.white.opacity(0.15))
                    
                    // Undo/Redo Group
                    HStack(spacing: 4) {
                        Button(action: { state.undo() }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { state.redo() }) {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Divider().frame(height: 20).background(Color.white.opacity(0.15))
                    
                    Group {
                        ToolButton(icon: "pencil.line", tool: .pen, current: $state.selectedTool)
                        ToolButton(icon: "highlighter", tool: .highlighter, current: $state.selectedTool)
                        ToolButton(icon: "paintbrush.pointed.fill", tool: .marker, current: $state.selectedTool)
                        ToolButton(icon: "arrow.up.right", tool: .arrow, current: $state.selectedTool)
                        ToolButton(icon: "square.dashed", tool: .rectangle, current: $state.selectedTool)
                        ToolButton(icon: "circle.dashed", tool: .circle, current: $state.selectedTool)
                        ToolButton(icon: "text.cursor", tool: .text, current: $state.selectedTool)
                    }
                    
                    Divider().frame(height: 20).background(Color.white.opacity(0.15))
                    
                    ColorPicker("", selection: $state.selectedColor)
                        .labelsHidden()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    
                    Spacer()
                    
                    Button(action: { state.removeBackground() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                            Text("Remove BG")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.blue))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { exportAsPDF() }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    
                    Divider().frame(height: 20).background(Color.white.opacity(0.15))
                    
                    // Save Action
                    Button(action: { ScreenshotMonitor.shared.finalizePendingScreenshot(withName: "") }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("SAVE")
                        }
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity) // Make it span the width
                .frame(height: 54)
                .background(
                    Capsule() // Fully rounded corners
                        .fill(Color.white.opacity(0.05))
                        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).clipShape(Capsule()))
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                )
                .padding(.horizontal, 20) // Window margins
                .padding(.top, 40) // Alignment with top bar
                
                Spacer()
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .edgesIgnoringSafeArea(.all)
        .preferredColorScheme(.dark)
    }
    
    private func drawAnnotation(_ annotation: CanvasAnnotation, in context: GraphicsContext, size: CGSize) {
        guard !annotation.points.isEmpty else { return }
        
        let scaledPoints = annotation.points.map { 
            CGPoint(x: $0.x * size.width, y: $0.y * size.height)
        }
        
        var path = Path()
        
        switch annotation.tool {
        case .pen, .highlighter, .marker:
            path.addLines(scaledPoints)
            context.stroke(
                path, 
                with: .color(annotation.color.opacity(annotation.opacity)), 
                lineWidth: annotation.lineWidth
            )
        case .arrow:
            if let first = scaledPoints.first, let last = scaledPoints.last {
                path.move(to: first)
                path.addLine(to: last)
                context.stroke(path, with: .color(annotation.color.opacity(annotation.opacity)), lineWidth: annotation.lineWidth)
            }
        case .rectangle:
            if let first = scaledPoints.first, let last = scaledPoints.last {
                let rect = CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(first.x - last.x), height: abs(first.y - last.y))
                context.stroke(Path(rect), with: .color(annotation.color.opacity(annotation.opacity)), lineWidth: annotation.lineWidth)
            }
        case .circle:
            if let first = scaledPoints.first, let last = scaledPoints.last {
                let rect = CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(first.x - last.x), height: abs(first.y - last.y))
                context.stroke(Path(ellipseIn: rect), with: .color(annotation.color.opacity(annotation.opacity)), lineWidth: annotation.lineWidth)
            }
        default: break
        }
    }
    
    private func exportAsPDF() {
        // PDF Export logic
    }
}

struct ToolButton: View {
    let icon: String
    let tool: CanvasTool
    @Binding var current: CanvasTool
    
    var body: some View {
        Button(action: { current = tool }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(current == tool ? .white : .white.opacity(0.4))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(current == tool ? Color.white.opacity(0.15) : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

struct BackgroundPresetButton: View {
    let type: BackgroundType
    @Binding var current: BackgroundType
    
    var body: some View {
        Button(action: { current = type }) {
            ZStack {
                if case .color(let color) = type {
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                } else if case .gradient(let colors) = type {
                    Circle()
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 20, height: 20)
                }
                
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 20, height: 20)
                
                if current == type {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

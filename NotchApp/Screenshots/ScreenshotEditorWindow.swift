import SwiftUI
import AppKit
import Vision
import SwiftData

class ScreenshotEditorWindowController: NSWindowController {
    static let shared = ScreenshotEditorWindowController()
    
    private var editorView: ScreenshotEditorView?
    
    func open(with url: URL) {
        if let window = self.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let editorState = ScreenshotEditorState(imageURL: url)
        let view = ScreenshotEditorView(state: editorState)
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
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
        window.isMovableByWindowBackground = true
        window.contentViewController = hostingController
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@Observable
class ScreenshotEditorState {
    var imageURL: URL
    var currentImage: NSImage?
    var extractedText: String = ""
    var extractedImages: [NSImage] = []
    var annotations: [CanvasAnnotation] = []
    var currentAnnotation: CanvasAnnotation?
    var selectedTool: CanvasTool = .pen
    var selectedColor: Color = .red
    
    init(imageURL: URL) {
        self.imageURL = imageURL
        self.currentImage = NSImage(contentsOf: imageURL)
        analyzeImage()
    }
    
    func startDrawing(at point: CGPoint) {
        currentAnnotation = CanvasAnnotation(tool: selectedTool, color: selectedColor, points: [point])
    }
    
    func updateDrawing(to point: CGPoint) {
        currentAnnotation?.points.append(point)
    }
    
    func endDrawing() {
        if let annotation = currentAnnotation {
            annotations.append(annotation)
            currentAnnotation = nil
        }
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

enum CanvasTool {
    case pen, arrow, rectangle, circle, text, erase
}

struct CanvasAnnotation: Identifiable {
    let id = UUID()
    var tool: CanvasTool
    var color: Color
    var points: [CGPoint] = []
    var text: String = ""
}

struct ScreenshotEditorView: View {
    @Bindable var state: ScreenshotEditorState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenshotItem.capturedAt, order: .reverse) private var items: [ScreenshotItem]
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar: Smart Extraction / Insights
            VStack(alignment: .leading, spacing: 20) {
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
                    
                    ScrollView {
                        Text(state.extractedText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .lineSpacing(4)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .frame(height: 250)
                    
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
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.top, 40)
            .padding(.horizontal, 20)
            .frame(width: 240)
            .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))

            // Main Canvas Area (Center)
            VStack(spacing: 0) {
                // Floating Toolbar
                HStack(spacing: 12) {
                    Group {
                        ToolButton(icon: "pencil.line", tool: .pen, current: $state.selectedTool)
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
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).clipShape(Capsule()))
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                )
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // The actual canvas
                ZStack {
                    if let image = state.currentImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(40)
                            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                            .overlay(
                                Canvas { context, size in
                                    for annotation in state.annotations {
                                        drawAnnotation(annotation, in: context)
                                    }
                                    if let current = state.currentAnnotation {
                                        drawAnnotation(current, in: context)
                                    }
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            if state.currentAnnotation == nil {
                                                state.startDrawing(at: value.location)
                                            } else {
                                                state.updateDrawing(to: value.location)
                                            }
                                        }
                                        .onEnded { _ in
                                            state.endDrawing()
                                        }
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Footer
                HStack(spacing: 20) {
                    Button(action: { /* Discard */ }) {
                        Text("DISCARD")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: { ScreenshotMonitor.shared.finalizePendingScreenshot(withName: "") }) {
                        Text("SAVE PROJECT")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1)
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .background(VisualEffectView(material: .contentBackground, blendingMode: .withinWindow))
            }
            .background(Color.black.opacity(0.2))

            // Right Sidebar: Session/All Screenshots (Preview Style)
            VStack(spacing: 0) {
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
            .frame(width: 160)
            .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .background(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }
    
    private func drawAnnotation(_ annotation: CanvasAnnotation, in context: GraphicsContext) {
        guard !annotation.points.isEmpty else { return }
        var path = Path()
        switch annotation.tool {
        case .pen:
            path.addLines(annotation.points)
            context.stroke(path, with: .color(annotation.color), lineWidth: 3)
        case .arrow:
            if let first = annotation.points.first, let last = annotation.points.last {
                path.move(to: first)
                path.addLine(to: last)
                context.stroke(path, with: .color(annotation.color), lineWidth: 3)
            }
        case .rectangle:
            if let first = annotation.points.first, let last = annotation.points.last {
                let rect = CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(first.x - last.x), height: abs(first.y - last.y))
                context.stroke(Path(rect), with: .color(annotation.color), lineWidth: 3)
            }
        case .circle:
            if let first = annotation.points.first, let last = annotation.points.last {
                let rect = CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(first.x - last.x), height: abs(first.y - last.y))
                context.stroke(Path(ellipseIn: rect), with: .color(annotation.color), lineWidth: 3)
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

import SwiftUI
import AppKit
import Vision
import SwiftData

class ScreenshotEditorWindowController: NSWindowController {
    static let shared = ScreenshotEditorWindowController()
    
    private var editorView: ScreenshotEditorView?
    
    func open(with url: URL) {
        if let window = self.window, window.isVisible {
            window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: 1300, height: 850), display: true, animate: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let editorState = ScreenshotEditorState(imageURL: url)
        let view = ScreenshotEditorView(state: editorState)
            .modelContainer(PersistenceController.shared.container)
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1300, height: 850),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Screenshot Editor Studio"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.contentViewController = hostingController
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum CanvasTool: String, CaseIterable {
    case pen, highlighter, marker, arrow, shape, text, erase
}

enum ShapeType: String {
    case rectangle, circle, triangle, line
}

enum ArrowStyle: String {
    case straight, curvedSingle, curvedDouble, rough
}

enum BackgroundType: Equatable {
    case color(Color)
    case gradient([Color])
}

struct CanvasAnnotation: Identifiable, Equatable {
    let id: UUID
    var tool: CanvasTool
    var color: Color
    var points: [CGPoint] = []
    var text: String = ""
    var lineWidth: CGFloat = 3
    var opacity: Double = 1.0
    var arrowStyle: ArrowStyle = .straight
    var shapeType: ShapeType = .rectangle
    var isSolid: Bool = false
    var isDashed: Bool = false
    var fontName: String = "Helvetica"
    var fontSize: CGFloat = 18
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderlined: Bool = false
    
    init(id: UUID = UUID(), tool: CanvasTool, color: Color, points: [CGPoint] = [], text: String = "", lineWidth: CGFloat = 3, opacity: Double = 1.0, arrowStyle: ArrowStyle = .straight, shapeType: ShapeType = .rectangle, isSolid: Bool = false, isDashed: Bool = false, fontName: String = "Helvetica", fontSize: CGFloat = 18, isBold: Bool = false, isItalic: Bool = false, isUnderlined: Bool = false) {
        self.id = id
        self.tool = tool
        self.color = color
        self.points = points
        self.text = text
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.arrowStyle = arrowStyle
        self.shapeType = shapeType
        self.isSolid = isSolid
        self.isDashed = isDashed
        self.fontName = fontName
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
    }
    
    static func == (lhs: CanvasAnnotation, rhs: CanvasAnnotation) -> Bool {
        lhs.id == rhs.id && 
        lhs.tool == rhs.tool && 
        lhs.color == rhs.color && 
        lhs.points == rhs.points && 
        lhs.text == rhs.text &&
        lhs.lineWidth == rhs.lineWidth &&
        lhs.opacity == rhs.opacity &&
        lhs.arrowStyle == rhs.arrowStyle &&
        lhs.shapeType == rhs.shapeType &&
        lhs.isSolid == rhs.isSolid &&
        lhs.isDashed == rhs.isDashed &&
        lhs.fontName == rhs.fontName &&
        lhs.fontSize == rhs.fontSize &&
        lhs.isBold == rhs.isBold &&
        lhs.isItalic == rhs.isItalic &&
        lhs.isUnderlined == rhs.isUnderlined
    }
}

@Observable
class ScreenshotEditorState {
    var imageURL: URL
    var currentImage: NSImage?
    var extractedText: String = ""
    
    var annotations: [CanvasAnnotation] = []
    private var redoStack: [CanvasAnnotation] = []
    
    var currentAnnotation: CanvasAnnotation?
    var editingAnnotationID: UUID?
    
    var selectedTool: CanvasTool = .pen {
        didSet { editingAnnotationID = nil }
    }
    var selectedArrowStyle: ArrowStyle = .curvedSingle
    var selectedShapeType: ShapeType = .rectangle
    var isShapeSolid: Bool = false
    var selectedLineWidth: Double = 3
    var isDashed: Bool = false
    
    var selectedFontName: String = "Helvetica"
    var selectedFontSize: Double = 18
    var isTextBold: Bool = false
    var isTextItalic: Bool = false
    var isTextUnderlined: Bool = false
    
    var selectedColor: Color = .red
    var canvasBackground: BackgroundType = .gradient([Color(hex: "FF512F"), Color(hex: "DD2476")])
    var isThumbnailsCollapsed: Bool = true
    var rotation: Double = 0
    var cornerRadius: Double = 12
    
    init(imageURL: URL) {
        self.imageURL = imageURL
        self.currentImage = NSImage(contentsOf: imageURL)
        analyzeImage()
    }
    
    func cancelEditing() {
        if let id = editingAnnotationID {
            // Remove the annotation if it was just created and is empty
            if let index = annotations.firstIndex(where: { $0.id == id }), annotations[index].text.isEmpty {
                annotations.remove(at: index)
            }
            editingAnnotationID = nil
        }
    }
    
    func rotate() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            rotation += 90
        }
    }
    
    func startDrawing(at point: CGPoint, in size: CGSize) {
        let normalizedPoint = CGPoint(x: point.x / size.width, y: point.y / size.height)
        var opacity: Double = 1.0
        
        if selectedTool == .highlighter { opacity = 0.4 }
        
        currentAnnotation = CanvasAnnotation(
            tool: selectedTool, color: selectedColor, points: [normalizedPoint],
            lineWidth: selectedLineWidth, opacity: opacity, arrowStyle: selectedArrowStyle,
            shapeType: selectedShapeType, isSolid: isShapeSolid, isDashed: isDashed,
            fontName: selectedFontName, fontSize: selectedFontSize,
            isBold: isTextBold, isItalic: isTextItalic, isUnderlined: isTextUnderlined
        )
    }
    
    func updateDrawing(to point: CGPoint, in size: CGSize) {
        let normalizedPoint = CGPoint(x: point.x / size.width, y: point.y / size.height)
        currentAnnotation?.points.append(normalizedPoint)
    }
    
    func endDrawing() {
        if let annotation = currentAnnotation {
            if annotation.tool == .text {
                editingAnnotationID = annotation.id
            }
            annotations.append(annotation)
            currentAnnotation = nil
            redoStack.removeAll()
        }
    }
    
    func undo() {
        guard !annotations.isEmpty else { return }
        redoStack.append(annotations.removeLast())
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        annotations.append(redoStack.removeLast())
    }
    
    func analyzeImage() {
        Task {
            let result = await ScreenshotAnalyzer.shared.analyze(imageURL: imageURL)
            await MainActor.run { self.extractedText = result.text }
        }
    }
    
    func removeBackground() { /* Placeholder for AI logic */ }
}

struct ScreenshotEditorView: View {
    @Bindable var state: ScreenshotEditorState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenshotItem.capturedAt, order: .reverse) private var items: [ScreenshotItem]
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. UNIFIED COMMAND SURFACE (Header)
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .ignoresSafeArea()
                
                HStack(spacing: 20) {
                    Spacer().frame(width: 80) // Traffic Light Space
                    
                    // History & Transform Actions
                    HStack(spacing: 6) {
                        CommandButton(icon: "trash", color: .red) { /* Discard */ }
                        Divider().frame(height: 18).padding(.horizontal, 4).opacity(0.3)
                        CommandButton(icon: "arrow.uturn.backward") { state.undo() }
                        CommandButton(icon: "arrow.uturn.forward") { state.redo() }
                        Divider().frame(height: 18).padding(.horizontal, 4).opacity(0.3)
                        CommandButton(icon: "rotate.right") { state.rotate() }
                        CornerRadiusButton(radius: $state.cornerRadius)
                    }
                    
                    Spacer()
                    
                    // MAIN TOOLSET (Unified Pill)
                    HStack(spacing: 14) {
                        ForEach(CanvasTool.allCases.filter { $0 != .erase }, id: \.self) { tool in
                            ToolButton(tool: tool, 
                                       current: $state.selectedTool, 
                                       arrowStyle: $state.selectedArrowStyle,
                                       shapeType: $state.selectedShapeType,
                                       isSolid: $state.isShapeSolid,
                                       lineWidth: $state.selectedLineWidth,
                                       isDashed: $state.isDashed,
                                       fontName: $state.selectedFontName,
                                       fontSize: $state.selectedFontSize,
                                       isBold: $state.isTextBold,
                                       isItalic: $state.isTextItalic,
                                       isUnderlined: $state.isTextUnderlined)
                        }
                        
                        Divider().frame(height: 18).padding(.horizontal, 2).opacity(0.3)
                        
                        // Annotation Color Swatch (Robust System Picker)
                        ColorPicker(selection: $state.selectedColor, supportsOpacity: true) {
                            Circle()
                                .fill(state.selectedColor)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        }
                        .labelsHidden()
                        .buttonStyle(.plain)
                        .frame(width: 22, height: 22)
                        
                        Divider().frame(height: 18).padding(.horizontal, 2).opacity(0.3)
                        
                        // NEW: Background Magic Swatch
                        BackgroundSwatchButton(current: $state.canvasBackground)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    
                    Spacer()
                    
                    // Secondary Actions
                    HStack(spacing: 12) {
                        // Adaptive Remove BG Button
                        Button(action: { state.removeBackground() }) {
                            ViewThatFits(in: .horizontal) {
                                Label("Remove BG", systemImage: "wand.and.stars")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(Capsule().fill(Color.blue))
                                
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.blue))
                            }
                        }
                        .buttonStyle(.plain)
                        
                        CommandButton(icon: "sidebar.right", active: !state.isThumbnailsCollapsed) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { state.isThumbnailsCollapsed.toggle() }
                        }
                        
                        // Adaptive SAVE Button
                        Button(action: { /* Save */ }) {
                            ViewThatFits(in: .horizontal) {
                                Text("SAVE")
                                    .font(.system(size: 11, weight: .black))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 9)
                                    .background(Capsule().fill(Color.white))
                                    .foregroundColor(.black)
                                
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.white))
                                    .foregroundColor(.black)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 24)
                }
            }
            .frame(height: 64)
            .overlay(Divider().opacity(0.2), alignment: .bottom)
            
            // 2. MAIN STUDIO AREA
            HStack(spacing: 0) {
                // LEFT PANEL: INSIGHTS
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("INSIGHTS")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.2)
                    }
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Extracted Text")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(state.extractedText, forType: .string)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(6)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        ScrollView {
                            Text(state.extractedText)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                                .lineSpacing(4)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .padding(24)
                .frame(width: 280)
                .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                .overlay(Divider().opacity(0.2), alignment: .trailing)
                
                // CENTER PANEL: THE CANVAS
                ZStack {
                    // Studio Floor
                    Group {
                        switch state.canvasBackground {
                        case .color(let color): color
                        case .gradient(let colors): LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                    .ignoresSafeArea()
                    
                    if let image = state.currentImage {
                        // The Screenshot "Card" with Multi-layered Soft Shadows
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .rotationEffect(.degrees(state.rotation))
                            .clipShape(RoundedRectangle(cornerRadius: state.cornerRadius))
                            .padding(80)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
                            .shadow(color: .black.opacity(0.15), radius: 40, x: 0, y: 30)
                            .overlay(
                                GeometryReader { geo in
                                    Canvas { context, size in
                                        for annotation in state.annotations { drawAnnotation(annotation, in: context, size: size) }
                                        if let current = state.currentAnnotation { drawAnnotation(current, in: context, size: size) }
                                    }
                                    .background(Color.white.opacity(0.001))
                                    .gesture(
                                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                            .onChanged { value in
                                                if state.currentAnnotation == nil { state.startDrawing(at: value.location, in: geo.size) }
                                                else { state.updateDrawing(to: value.location, in: geo.size) }
                                            }
                                            .onEnded { _ in state.endDrawing() }
                                    )
                                    
                                    // Interactive Text Editor Overlay
                                    ZStack {
                                        if state.editingAnnotationID != nil {
                                            // Invisible dismissal layer that covers the canvas
                                            Color.white.opacity(0.001)
                                                .onTapGesture { state.editingAnnotationID = nil }
                                        }
                                        
                                        ForEach($state.annotations) { $annotation in
                                            if state.editingAnnotationID == annotation.id {
                                                let first = annotation.points.first ?? .zero
                                                let last = annotation.points.last ?? .zero
                                                let isTap = abs(first.x - last.x) < 0.005
                                                
                                                // Constrain the box to sensible limits
                                                let boxWidth = isTap ? 250 : max(min(abs(first.x - last.x) * geo.size.width, geo.size.width - (first.x * geo.size.width)), 100)
                                                let boxHeight = isTap ? (annotation.fontSize * 2.5) : max(abs(first.y - last.y) * geo.size.height, 40)
                                                
                                                TextField("Type something...", text: $annotation.text, axis: .vertical)
                                                    .textFieldStyle(.plain)
                                                    .font(.custom(annotation.fontName, size: annotation.fontSize).weight(annotation.isBold ? .bold : .regular))
                                                    .italic(annotation.isItalic)
                                                    .underline(annotation.isUnderlined)
                                                    .foregroundColor(annotation.color)
                                                    .padding(10)
                                                    .frame(width: boxWidth, height: boxHeight, alignment: .topLeading)
                                                    .position(x: (min(first.x, last.x) * geo.size.width) + (boxWidth / 2), 
                                                              y: (min(first.y, last.y) * geo.size.height) + (boxHeight / 2))
                                                    .onExitCommand { state.cancelEditing() }
                                                    .onSubmit { state.editingAnnotationID = nil }
                                            }
                                        }
                                    }
                                }
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.1))
                .clipped()
                
                // RIGHT PANEL: THUMBNAILS
                if !state.isThumbnailsCollapsed {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("HISTORY")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white.opacity(0.3))
                            .tracking(1.2)
                            .padding(.top, 4)
                        
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                ForEach(items) { item in
                                    ThumbnailItem(item: item, isActive: state.imageURL.path == item.filePath) {
                                        state.imageURL = URL(fileURLWithPath: item.filePath)
                                        state.currentImage = NSImage(contentsOf: state.imageURL)
                                        state.analyzeImage()
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                    .frame(width: 200)
                    .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                    .overlay(Divider().opacity(0.2), alignment: .leading)
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 750)
        .preferredColorScheme(.dark)
    }
    
    private func drawAnnotation(_ annotation: CanvasAnnotation, in context: GraphicsContext, size: CGSize) {
        guard !annotation.points.isEmpty else { return }
        let scaledPoints = annotation.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        var path = Path()
        let strokeStyle = StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round, dash: annotation.isDashed ? [annotation.lineWidth * 2, annotation.lineWidth] : [])
        
        switch annotation.tool {
        case .pen, .highlighter, .marker:
            path.addLines(scaledPoints)
            context.stroke(path, with: .color(annotation.color.opacity(annotation.opacity)), style: strokeStyle)
            
        case .arrow:
            drawCurvedArrow(in: context, annotation: annotation, size: size)
            
        case .shape:
            drawShape(in: context, annotation: annotation, size: size)
            
        case .text:
            if state.editingAnnotationID != annotation.id && !annotation.text.isEmpty {
                let first = scaledPoints.first ?? .zero
                let last = scaledPoints.last ?? .zero
                let rect = CGRect(
                    x: min(first.x, last.x),
                    y: min(first.y, last.y),
                    width: max(abs(first.x - last.x), 200),
                    height: max(abs(first.y - last.y), 100)
                )
                
                let font = Font.custom(annotation.fontName, size: annotation.fontSize)
                    .weight(annotation.isBold ? .bold : .regular)
                
                context.draw(
                    Text(annotation.text)
                        .font(font)
                        .italic(annotation.isItalic)
                        .underline(annotation.isUnderlined)
                        .foregroundColor(annotation.color),
                    in: rect
                )
            }
            
        default: break
        }
    }
    
    private func drawShape(in context: GraphicsContext, annotation: CanvasAnnotation, size: CGSize) {
        let points = annotation.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        guard points.count >= 2, let first = points.first, let last = points.last else { return }
        
        let rect = CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(first.x - last.x), height: abs(first.y - last.y))
        var path = Path()
        let strokeStyle = StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round, dash: annotation.isDashed ? [annotation.lineWidth * 2, annotation.lineWidth] : [])
        
        switch annotation.shapeType {
        case .rectangle:
            path = Path(rect)
        case .circle:
            path = Path(ellipseIn: rect)
        case .triangle:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        case .line:
            path.move(to: first)
            path.addLine(to: last)
        }
        
        if annotation.isSolid && annotation.shapeType != .line {
            context.fill(path, with: .color(annotation.color.opacity(annotation.opacity)))
        } else {
            context.stroke(path, with: .color(annotation.color.opacity(annotation.opacity)), style: strokeStyle)
        }
    }
    
    private func drawArrowheadManual(in context: GraphicsContext, at end: CGPoint, angle: Double, color: Color, width: CGFloat) {
        let headLength: CGFloat = 12 + width
        let headAngle: CGFloat = .pi / 6
        var path = Path()
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - headLength * cos(angle - headAngle), y: end.y - headLength * sin(angle - headAngle)))
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - headLength * cos(angle + headAngle), y: end.y - headLength * sin(angle + headAngle)))
        context.stroke(path, with: .color(color), lineWidth: width)
    }
    
    private func drawCurvedArrow(in context: GraphicsContext, annotation: CanvasAnnotation, size: CGSize) {
        let points = annotation.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        guard points.count >= 2 else { return }
        let start = points.first!
        let end = points.last!
        var path = Path()
        let strokeStyle = StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round, dash: annotation.isDashed ? [annotation.lineWidth * 2, annotation.lineWidth] : [])
        
        switch annotation.arrowStyle {
        case .straight:
            path.move(to: start); path.addLine(to: end)
            context.stroke(path, with: .color(annotation.color.opacity(annotation.opacity)), style: strokeStyle)
            drawArrowheadManual(in: context, at: end, angle: atan2(end.y - start.y, end.x - start.x), color: annotation.color, width: annotation.lineWidth)
            
        case .curvedSingle:
            path.move(to: start)
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let dx = end.x - start.x
            let dy = end.y - start.y
            let control = CGPoint(x: mid.x - dy * 0.25, y: mid.y + dx * 0.25)
            path.addQuadCurve(to: end, control: control)
            context.stroke(path, with: .color(annotation.color.opacity(annotation.opacity)), style: strokeStyle)
            drawArrowheadManual(in: context, at: end, angle: atan2(end.y - control.y, end.x - control.x), color: annotation.color, width: annotation.lineWidth)
            
        case .curvedDouble:
            path.move(to: start)
            let cp1 = CGPoint(x: start.x + (end.x - start.x) * 0.25 - (end.y - start.y) * 0.2, y: start.y + (end.y - start.y) * 0.25 + (end.x - start.x) * 0.2)
            let cp2 = CGPoint(x: start.x + (end.x - start.x) * 0.75 + (end.y - start.y) * 0.2, y: start.y + (end.y - start.y) * 0.75 - (end.x - start.x) * 0.2)
            path.addCurve(to: end, control1: cp1, control2: cp2)
            context.stroke(path, with: .color(annotation.color.opacity(annotation.opacity)), style: strokeStyle)
            drawArrowheadManual(in: context, at: end, angle: atan2(end.y - cp2.y, end.x - cp2.x), color: annotation.color, width: annotation.lineWidth)
            
        case .rough:
            path.addLines(points)
            context.stroke(path, with: .color(annotation.color.opacity(annotation.opacity)), style: strokeStyle)
            let lookback = min(points.count - 1, 5)
            if lookback >= 1 {
                let p1 = points[points.count - 1 - lookback]; let p2 = points.last!
                drawArrowheadManual(in: context, at: p2, angle: atan2(p2.y - p1.y, p2.x - p1.x), color: annotation.color, width: annotation.lineWidth)
            }
        }
    }
}

// UI COMPONENTS

struct CommandButton: View {
    let icon: String
    var color: Color = .white
    var active: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(active ? .blue : color.opacity(active ? 1 : 0.6))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(active ? Color.blue.opacity(0.1) : Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }
}

struct ToolButton: View {
    let tool: CanvasTool
    @Binding var current: CanvasTool
    @Binding var arrowStyle: ArrowStyle
    @Binding var shapeType: ShapeType
    @Binding var isSolid: Bool
    @Binding var lineWidth: Double
    @Binding var isDashed: Bool
    @Binding var fontName: String
    @Binding var fontSize: Double
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderlined: Bool
    
    @State private var showShapePicker = false
    @State private var showArrowPicker = false
    @State private var showStrokePicker = false
    @State private var showTypographyPicker = false
    
    var body: some View {
        Button(action: { 
            if tool == .shape { showShapePicker.toggle() }
            if tool == .arrow { showArrowPicker.toggle() }
            if tool == .text { showTypographyPicker.toggle() }
            if tool == .pen || tool == .marker || tool == .highlighter { showStrokePicker.toggle() }
            current = tool 
        }) {
            Image(systemName: toolIcon(tool, arrowStyle: arrowStyle, shapeType: shapeType, isSolid: isSolid))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(current == tool ? .white : .white.opacity(0.4))
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(current == tool ? Color.white.opacity(0.15) : Color.clear))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTypographyPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                Text("TYPOGRAPHY")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("FONT FAMILY").font(.system(size: 10, weight: .bold)).opacity(0.6)
                    Picker("", selection: $fontName) {
                        Text("Helvetica").tag("Helvetica")
                        Text("Inter").tag("Inter")
                        Text("SF Pro").tag("SF Pro Display")
                        Text("Georgia").tag("Georgia")
                        Text("Courier").tag("Courier")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 188)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("SIZE").font(.system(size: 10, weight: .bold)).opacity(0.6)
                    HStack(spacing: 12) {
                        Slider(value: $fontSize, in: 8...120)
                            .accentColor(.blue)
                        TextField("", value: $fontSize, format: .number)
                            .textFieldStyle(.plain)
                            .frame(width: 40)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                }
                
                Divider().opacity(0.2)
                
                HStack(spacing: 8) {
                    Toggle(isOn: $isBold) {
                        Image(systemName: "bold").font(.system(size: 12, weight: .bold))
                    }
                    .toggleStyle(.button)
                    
                    Toggle(isOn: $isItalic) {
                        Image(systemName: "italic").font(.system(size: 12, weight: .bold))
                    }
                    .toggleStyle(.button)
                    
                    Toggle(isOn: $isUnderlined) {
                        Image(systemName: "underline").font(.system(size: 12, weight: .bold))
                    }
                    .toggleStyle(.button)
                }
            }
            .padding(16)
            .frame(width: 220)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        }
        .popover(isPresented: $showStrokePicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                Text("STROKE SETTINGS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("WIDTH").font(.system(size: 10, weight: .bold)).opacity(0.6)
                    HStack(spacing: 12) {
                        Slider(value: $lineWidth, in: 1...40)
                            .accentColor(.blue)
                        TextField("", value: $lineWidth, format: .number)
                            .textFieldStyle(.plain)
                            .frame(width: 40)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                }
                
                Divider().opacity(0.2)
                
                Toggle(isOn: $isDashed) {
                    Text("DASHED STROKE").font(.system(size: 10, weight: .bold))
                }
                .toggleStyle(.checkbox)
            }
            .padding(16)
            .frame(width: 220)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        }
        .popover(isPresented: $showArrowPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                Text("ARROW STYLE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
                
                HStack(spacing: 12) {
                    ForEach([ArrowStyle.straight, .curvedSingle, .curvedDouble, .rough], id: \.self) { style in
                        Button(action: { arrowStyle = style; current = .arrow; showArrowPicker = false }) {
                            Image(systemName: arrowIcon(style))
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 6).fill(arrowStyle == style ? Color.blue.opacity(0.2) : Color.white.opacity(0.05)))
                                .foregroundColor(arrowStyle == style ? .blue : .white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        }
        .popover(isPresented: $showShapePicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                Text("SHAPE TOOL")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
                
                // Shape Type Row
                HStack(spacing: 12) {
                    ForEach([ShapeType.rectangle, .circle, .triangle, .line], id: \.self) { type in
                        Button(action: { shapeType = type; current = .shape; showShapePicker = false }) {
                            Image(systemName: shapeIcon(type, solid: isSolid))
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 6).fill(shapeType == type ? Color.blue.opacity(0.2) : Color.white.opacity(0.05)))
                                .foregroundColor(shapeType == type ? .blue : .white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider().opacity(0.2)
                
                // Fill Toggle
                Toggle(isOn: $isSolid) {
                    Text("SOLID FILL").font(.system(size: 10, weight: .bold))
                }
                .toggleStyle(.checkbox)
            }
            .padding(16)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        }
    }
    
    private func arrowIcon(_ style: ArrowStyle) -> String {
        switch style {
        case .straight: return "arrow.up.right"
        case .curvedSingle: return "arrow.up.right.circle"
        case .curvedDouble: return "arrow.up.right.square"
        case .rough: return "scribble.variable"
        }
    }
    
    private func toolIcon(_ tool: CanvasTool, arrowStyle: ArrowStyle, shapeType: ShapeType, isSolid: Bool) -> String {
        switch tool {
        case .pen: return "pencil.line"
        case .highlighter: return "highlighter"
        case .marker: return "paintbrush.pointed.fill"
        case .arrow: 
            switch arrowStyle {
            case .straight: return "arrow.up.right"
            case .curvedSingle: return "arrow.up.right.circle"
            case .curvedDouble: return "arrow.up.right.square"
            case .rough: return "scribble.variable"
            }
        case .shape:
            return shapeIcon(shapeType, solid: isSolid)
        case .text: return "text.cursor"
        default: return "pencil"
        }
    }
    
    private func shapeIcon(_ type: ShapeType, solid: Bool) -> String {
        switch type {
        case .rectangle: return solid ? "square.fill" : "square"
        case .circle: return solid ? "circle.fill" : "circle"
        case .triangle: return solid ? "triangle.fill" : "triangle"
        case .line: return "line.diagonal"
        }
    }
}

struct CornerRadiusButton: View {
    @Binding var radius: Double
    @State private var showPicker = false
    
    var body: some View {
        Button(action: { showPicker.toggle() }) {
            Image(systemName: "square.dashed.inset.filled")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(showPicker ? .blue : .white.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(showPicker ? Color.blue.opacity(0.1) : Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("CORNER RADIUS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
                
                HStack(spacing: 12) {
                    Slider(value: $radius, in: 0...100)
                        .accentColor(.blue)
                    
                    TextField("", value: $radius, format: .number)
                        .textFieldStyle(.plain)
                        .frame(width: 44)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
            }
            .padding(16)
            .frame(width: 240)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        }
    }
}

struct BackgroundSwatchButton: View {
    @Binding var current: BackgroundType
    @State private var showPicker = false
    
    var body: some View {
        Button(action: { showPicker.toggle() }) {
            ZStack {
                Group {
                    switch current {
                    case .color(let c): c
                    case .gradient(let g): LinearGradient(colors: g, startPoint: .top, endPoint: .bottom)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 28, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            BackgroundPickerPopover(current: $current)
        }
    }
}

struct BackgroundPickerPopover: View {
    @Binding var current: BackgroundType
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    Group {
                        BackgroundPresetButton(type: .color(Color(white: 0.12)), current: $current)
                        BackgroundPresetButton(type: .color(.black), current: $current)
                        BackgroundPresetButton(type: .color(.white), current: $current)
                        BackgroundPresetButton(type: .color(Color(hex: "3498db")), current: $current)
                        BackgroundPresetButton(type: .color(Color(hex: "e74c3c")), current: $current)
                        BackgroundPresetButton(type: .color(Color(hex: "2ecc71")), current: $current)
                        BackgroundPresetButton(type: .color(Color(hex: "f1c40f")), current: $current)
                    }
                    
                    Divider().frame(height: 18).opacity(0.3)
                    
                    Group {
                        // 2-Color Gradients
                        BackgroundPresetButton(type: .gradient([Color(hex: "FF512F"), Color(hex: "DD2476")]), current: $current)
                        BackgroundPresetButton(type: .gradient([Color(hex: "1FA2FF"), Color(hex: "12D8FA")]), current: $current)
                        BackgroundPresetButton(type: .gradient([Color(hex: "00F260"), Color(hex: "0575E6")]), current: $current)
                        
                        Divider().frame(height: 18).opacity(0.3)
                        
                        // 3-Color TRIPLE MIX Gradients
                        BackgroundPresetButton(type: .gradient([Color(hex: "833ab4"), Color(hex: "fd1d1d"), Color(hex: "fcb045")]), current: $current)
                        BackgroundPresetButton(type: .gradient([Color(hex: "642BBD"), Color(hex: "FF00CC"), Color(hex: "333399")]), current: $current)
                        BackgroundPresetButton(type: .gradient([Color(hex: "FDB99B"), Color(hex: "CF8BF3"), Color(hex: "A770EF")]), current: $current)
                        BackgroundPresetButton(type: .gradient([Color(hex: "00c6ff"), Color(hex: "0072ff"), Color(hex: "0021ff")]), current: $current)
                        BackgroundPresetButton(type: .gradient([Color(hex: "f093fb"), Color(hex: "f5576c"), Color(hex: "ff0844")]), current: $current)
                    }
                }
                .padding(16)
            }
            .frame(width: 450)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        }
    }
}

struct BackgroundPresetButton: View {
    let type: BackgroundType
    @Binding var current: BackgroundType
    var body: some View {
        Button(action: { current = type }) {
            ZStack {
                if case .color(let c) = type {
                    Circle().fill(c).frame(width: 22, height: 22)
                } else if case .gradient(let g) = type {
                    Circle().fill(LinearGradient(colors: g, startPoint: .top, endPoint: .bottom)).frame(width: 22, height: 22)
                }
                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1).frame(width: 22, height: 22)
                if current == type { Circle().stroke(Color.blue, lineWidth: 2).frame(width: 28, height: 28) }
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}

struct ThumbnailItem: View {
    let item: ScreenshotItem
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                AsyncImage(url: URL(fileURLWithPath: item.filePath)) { img in
                    img.resizable().aspectRatio(contentMode: .fit)
                } placeholder: { Color.white.opacity(0.05) }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Color.blue : Color.white.opacity(0.1), lineWidth: isActive ? 2 : 1))
                .shadow(color: .black.opacity(isActive ? 0.3 : 0), radius: 10)
                
                Text(item.filename)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(isActive ? 1 : 0.4))
                    .lineLimit(1)
            }
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
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}

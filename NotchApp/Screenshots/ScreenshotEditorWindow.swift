import SwiftUI
import AppKit
import Vision
import SwiftData
import UniformTypeIdentifiers
import OSLog

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
        window.tabbingMode = .disallowed
        window.contentViewController = hostingController
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum CanvasTool: String, CaseIterable {
    case cursor, pen, highlighter, marker, arrow, shape, text, snippet, sticker, erase, blur
}

enum ShapeType: String {
    case rectangle, circle, triangle, line, freehand, star, diamond, hexagon
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
    var image: NSImage? = nil
    
    // For movement
    var offset: CGSize = .zero
    var cornerRadius: Double = 0
    var rotation: Double = 0
    
    init(id: UUID = UUID(), tool: CanvasTool, color: Color, points: [CGPoint] = [], text: String = "", lineWidth: CGFloat = 3, opacity: Double = 1.0, arrowStyle: ArrowStyle = .straight, shapeType: ShapeType = .rectangle, isSolid: Bool = false, isDashed: Bool = false, fontName: String = "Helvetica", fontSize: CGFloat = 18, isBold: Bool = false, isItalic: Bool = false, isUnderlined: Bool = false, offset: CGSize = .zero, image: NSImage? = nil, cornerRadius: Double = 0, rotation: Double = 0) {
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
        self.offset = offset
        self.image = image
        self.cornerRadius = cornerRadius
        self.rotation = rotation
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
        lhs.isUnderlined == rhs.isUnderlined &&
        lhs.offset == rhs.offset &&
        lhs.image == rhs.image &&
        lhs.cornerRadius == rhs.cornerRadius &&
        lhs.rotation == rhs.rotation
    }
}

struct ExtractedSnippet: Identifiable, Equatable {
    let id = UUID()
    let image: NSImage
    let capturedAt = Date()
}

/// Lightweight viewport state — updated every frame by pan/zoom/hover gestures.
/// Kept separate from ScreenshotEditorState so gesture updates never trigger
/// a full annotation canvas re-render.
@Observable
class CanvasViewport {
    var zoomScale: CGFloat = 1.0
    var lastZoomScale: CGFloat = 1.0
    var panOffset: CGSize = .zero
    var lastPanOffset: CGSize = .zero
    var hoverLocation: CGPoint = .zero
}

struct EditorHistoryState {
    let annotations: [CanvasAnnotation]
    let image: NSImage?
}

@Observable
class ScreenshotEditorState {
    var imageURL: URL
    var currentImage: NSImage?
    var extractedText: String = ""
    
    var annotations: [CanvasAnnotation] = []
    private var historyStack: [EditorHistoryState] = []
    private var redoHistory: [EditorHistoryState] = []
    var initialResizePoints: [CGPoint]? = nil
    
    var currentAnnotation: CanvasAnnotation?
    var editingAnnotationID: UUID?
    var selectedAnnotationID: UUID?
    var extractedSnippets: [ExtractedSnippet] = []
    var activeItem: ScreenshotItem?
    var allAnnotations: [String: [CanvasAnnotation]] = [:]
    
    var selectedTool: CanvasTool = .pen {
        didSet { 
            editingAnnotationID = nil 
            selectedAnnotationID = nil
            if selectedTool != .cursor {
                isImageTransformMode = false
            }
            if selectedTool == .blur && selectedLineWidth < 10 {
                selectedLineWidth = 20
            }
            if selectedTool == .erase && selectedLineWidth < 10 {
                selectedLineWidth = 20
            }
        }
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
    
    /// Image-level transform (scale + crop insets), independent of canvas zoom.
    var imageScaleX: CGFloat = 1.0
    var imageScaleY: CGFloat = 1.0
    var imageCropInsets: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    var imagePanOffset: CGSize = .zero
    var isImageTransformMode: Bool = false {
        didSet {
            if isImageTransformMode {
                selectedTool = .cursor
            } else {
                resetImageTransform()
            }
        }
    }
    
    func resetImageTransform() {
        imageScaleX = 1.0
        imageScaleY = 1.0
        imageCropInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        imagePanOffset = .zero
    }
    
    func clampPanOffset() {
        let S = imageScaleX
        guard S > 1.0 else {
            imagePanOffset = .zero
            return
        }
        
        let leading = imageCropInsets.leading
        let trailing = imageCropInsets.trailing
        let top = imageCropInsets.top
        let bottom = imageCropInsets.bottom
        
        let pxMax = 0.5 * (1.0 - 1.0 / S) + leading / S
        let pxMin = -0.5 * (1.0 - 1.0 / S) - trailing / S
        let pyMax = 0.5 * (1.0 - 1.0 / S) + top / S
        let pyMin = -0.5 * (1.0 - 1.0 / S) - bottom / S
        
        imagePanOffset.width = Swift.max(pxMin, Swift.min(pxMax, imagePanOffset.width))
        imagePanOffset.height = Swift.max(pyMin, Swift.min(pyMax, imagePanOffset.height))
    }
    
    func commitCrop() {
        guard let img = currentImage else { return }
        
        // Save history state before executing the crop
        saveHistory()
        
        let w = img.size.width
        let h = img.size.height
        
        let S = imageScaleX
        let px = imagePanOffset.width
        let py = imagePanOffset.height
        
        let leading = imageCropInsets.leading
        let trailing = imageCropInsets.trailing
        let top = imageCropInsets.top
        let bottom = imageCropInsets.bottom
        
        let cropLeft = Swift.max(0.0, Swift.min(1.0, 0.5 - px + (leading - 0.5) / S))
        let cropWidth = Swift.max(0.01, Swift.min(1.0, (1.0 - leading - trailing) / S))
        let cropTop = Swift.max(0.0, Swift.min(1.0, 0.5 - py + (top - 0.5) / S))
        let cropHeight = Swift.max(0.01, Swift.min(1.0, (1.0 - top - bottom) / S))
        let cropBottom = Swift.max(0.0, Swift.min(1.0, 0.5 + py + (bottom - 0.5) / S))
        
        let cropX = cropLeft * w
        let cropY = cropBottom * h // NSImage starts at bottom-left
        let cropW = cropWidth * w
        let cropH = cropHeight * h
        
        if cropW > 10 && cropH > 10 {
            let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
            if let croppedImg = img.cropped(to: cropRect) {
                self.currentImage = croppedImg
                
                // Adjust all existing annotations so they map to the new crop area
                if cropWidth > 0.01 && cropHeight > 0.01 {
                    for i in 0..<annotations.count {
                        var ann = annotations[i]
                        ann.points = ann.points.map { pt in
                            let newX = (pt.x - cropLeft) / cropWidth
                            let newY = (pt.y - cropTop) / cropHeight
                            return CGPoint(x: newX, y: newY)
                        }
                        annotations[i] = ann
                    }
                }
            }
        }
        
        imageScaleX = 1.0
        imageScaleY = 1.0
        imageCropInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        imagePanOffset = .zero
    }
    
    /// Viewport is a separate lightweight object — mutations here do NOT re-render annotations.
    let viewport = CanvasViewport()
    
    init(imageURL: URL) {
        self.imageURL = imageURL
        self.currentImage = NSImage(contentsOf: imageURL)
        analyzeImage()
    }
    
    func cancelEditing() {
        if let id = editingAnnotationID {
            if let index = annotations.firstIndex(where: { $0.id == id }), annotations[index].text.isEmpty {
                annotations.remove(at: index)
            }
            editingAnnotationID = nil
        }
        // Cleanup all empty text annotations
        annotations.removeAll { $0.tool == .text && $0.text.isEmpty }
    }
    
    func findAnnotation(at point: CGPoint, in size: CGSize) -> UUID? {
        let normalizedPoint = CGPoint(x: point.x / size.width, y: point.y / size.height)
        
        // Iterate backwards to find the topmost annotation
        for annotation in annotations.reversed() {
            let points = annotation.points.map { 
                CGPoint(x: $0.x + annotation.offset.width / size.width, 
                        y: $0.y + annotation.offset.height / size.height) 
            }
            
            if annotation.tool == .text {
                let first = points.first ?? .zero
                let last = points.last ?? .zero
                let isTap = abs(first.x - last.x) < 0.005
                
                // Intelligent hit-box for text
                let estimatedWidth = isTap ? (CGFloat(max(annotation.text.count, 5)) * annotation.fontSize * 0.6 / size.width) : abs(first.x - last.x)
                let estimatedHeight = isTap ? (annotation.fontSize * 1.5 / size.height) : abs(first.y - last.y)
                
                let rect = CGRect(x: min(first.x, last.x), 
                                  y: min(first.y, last.y), 
                                  width: max(estimatedWidth, 0.1), 
                                  height: max(estimatedHeight, 0.05))
                
                // Add a small padding to make it even easier to click
                let paddedRect = rect.insetBy(dx: -0.02, dy: -0.01)
                
                if paddedRect.contains(normalizedPoint) { return annotation.id }
            } else if annotation.tool == .sticker {
                let first = points.first ?? .zero
                let last = points.last ?? .zero
                let rect = CGRect(x: min(first.x, last.x), y: min(first.y, last.y), 
                                  width: max(abs(first.x - last.x), 0.05), 
                                  height: max(abs(first.y - last.y), 0.05))
                let paddedRect = rect.insetBy(dx: -0.02, dy: -0.02)
                if paddedRect.contains(normalizedPoint) { return annotation.id }
            } else if points.count >= 2 {
                let xs = points.map { $0.x }
                let ys = points.map { $0.y }
                let minX = xs.min() ?? 0
                let maxX = xs.max() ?? 0
                let minY = ys.min() ?? 0
                let maxY = ys.max() ?? 0
                let rect = CGRect(x: minX, y: minY, 
                                  width: max(maxX - minX, 0.05), 
                                  height: max(maxY - minY, 0.05))
                if rect.contains(normalizedPoint) { return annotation.id }
            }
        }
        return nil
    }
    
    func selectAnnotation(at point: CGPoint, in size: CGSize) {
        selectedAnnotationID = findAnnotation(at: point, in: size)
    }
    
    func rotate() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            rotation += 90
        }
    }
    
    func startEditingText(id: UUID) {
        if let ann = annotations.first(where: { $0.id == id }), ann.tool == .text {
            editingAnnotationID = id
            selectedAnnotationID = id
        }
    }
    
    func addImageSticker(image: NSImage) {
        let imgSize = image.size
        let aspect = imgSize.width / imgSize.height
        let dropWidth: CGFloat = 0.3
        let dropHeight = dropWidth / aspect
        
        let dropPoint = CGPoint(x: 0.5 - (dropWidth/2), y: 0.5 - (dropHeight/2)) 
        let newAnnotation = CanvasAnnotation(
            tool: .sticker, color: .clear, points: [dropPoint, CGPoint(x: dropPoint.x + dropWidth, y: dropPoint.y + dropHeight)],
            image: image
        )
        annotations.append(newAnnotation)
    }
    
    func startResize(id: UUID) {
        if let ann = annotations.first(where: { $0.id == id }) {
            initialResizePoints = ann.points
        }
    }
    
    func resizeAnnotation(_ id: UUID, handleIndex: Int, translation: CGSize, in size: CGSize, isShiftPressed: Bool = false) {
        guard let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        guard let start = initialResizePoints, start.count >= 2 else { return }
        
        let dx = translation.width / size.width
        let dy = translation.height / size.height
        
        let minX: CGFloat
        let maxX: CGFloat
        let minY: CGFloat
        let maxY: CGFloat
        if start.count > 2 {
            let xs = start.map { $0.x }
            let ys = start.map { $0.y }
            minX = xs.min() ?? 0
            maxX = xs.max() ?? 0
            minY = ys.min() ?? 0
            maxY = ys.max() ?? 0
        } else {
            minX = min(start[0].x, start[1].x)
            maxX = max(start[0].x, start[1].x)
            minY = min(start[0].y, start[1].y)
            maxY = max(start[0].y, start[1].y)
        }
        
        var newMinX = minX; var newMaxX = maxX
        var newMinY = minY; var newMaxY = maxY
        
        let isCorner = (handleIndex == 0 || handleIndex == 2 || handleIndex == 5 || handleIndex == 7)
        
        if isShiftPressed && isCorner {
            let initialW = maxX - minX
            let initialH = maxY - minY
            if initialH > 0 && initialW > 0 {
                // Calculate the proposed new width and height
                var proposedW = initialW
                var proposedH = initialH
                
                switch handleIndex {
                case 0: // TL
                    proposedW = maxX - (minX + dx)
                    proposedH = maxY - (minY + dy)
                case 2: // TR
                    proposedW = (maxX + dx) - minX
                    proposedH = maxY - (minY + dy)
                case 5: // BL
                    proposedW = maxX - (minX + dx)
                    proposedH = (maxY + dy) - minY
                case 7: // BR
                    proposedW = (maxX + dx) - minX
                    proposedH = (maxY + dy) - minY
                default: break
                }
                
                // Keep aspect ratio by using the dominant axis scale delta from 1.0
                let scaleX = proposedW / initialW
                let scaleY = proposedH / initialH
                
                let scale: CGFloat
                if abs(scaleX - 1.0) > abs(scaleY - 1.0) {
                    scale = max(0.01, scaleX)
                } else {
                    scale = max(0.01, scaleY)
                }
                
                let finalW = initialW * scale
                let finalH = initialH * scale
                
                // Apply final width and height back to new bounds
                switch handleIndex {
                case 0: // TL
                    newMinX = maxX - finalW
                    newMinY = maxY - finalH
                case 2: // TR
                    newMaxX = minX + finalW
                    newMinY = maxY - finalH
                case 5: // BL
                    newMinX = maxX - finalW
                    newMaxY = minY + finalH
                case 7: // BR
                    newMaxX = minX + finalW
                    newMaxY = minY + finalH
                default: break
                }
            }
        } else {
            // Free resizing
            switch handleIndex {
            case 0: // TL
                newMinX += dx; newMinY += dy
            case 1: // TC
                newMinY += dy
            case 2: // TR
                newMaxX += dx; newMinY += dy
            case 3: // ML
                newMinX += dx
            case 4: // MR
                newMaxX += dx
            case 5: // BL
                newMinX += dx; newMaxY += dy
            case 6: // BC
                newMaxY += dy
            case 7: // BR
                newMaxX += dx; newMaxY += dy
            default: break
            }
        }
        
        // Ensure minimum size
        if newMaxX - newMinX < 0.02 { newMaxX = newMinX + 0.02 }
        if newMaxY - newMinY < 0.02 { newMaxY = newMinY + 0.02 }
        
        if start.count > 2 {
            let initialW = maxX - minX
            let initialH = maxY - minY
            let newW = newMaxX - newMinX
            let newH = newMaxY - newMinY
            
            annotations[idx].points = start.map { pt in
                let tx = initialW > 0 ? (pt.x - minX) / initialW : 0
                let ty = initialH > 0 ? (pt.y - minY) / initialH : 0
                return CGPoint(x: newMinX + tx * newW, y: newMinY + ty * newH)
            }
        } else {
            annotations[idx].points = [CGPoint(x: newMinX, y: newMinY), CGPoint(x: newMaxX, y: newMaxY)]
        }
    }
    
    func rotateAnnotation(_ id: UUID, degrees: Double) {
        guard let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[idx].rotation = degrees
    }
    
    func eraseAnnotations(near point: CGPoint, in size: CGSize) {
        let threshold: CGFloat = max(selectedLineWidth, 12)
        var indicesToRemove = Set<Int>()
        
        for (idx, annotation) in annotations.enumerated() {
            let annPoints = annotation.points.map {
                CGPoint(x: ($0.x * size.width) + annotation.offset.width,
                        y: ($0.y * size.height) + annotation.offset.height)
            }
            
            guard !annPoints.isEmpty else { continue }
            
            switch annotation.tool {
            case .text, .sticker:
                let minX = annPoints.map { $0.x }.min() ?? 0
                let maxX = annPoints.map { $0.x }.max() ?? 0
                let minY = annPoints.map { $0.y }.min() ?? 0
                let maxY = annPoints.map { $0.y }.max() ?? 0
                let rect = CGRect(x: minX - threshold, y: minY - threshold, width: (maxX - minX) + threshold * 2, height: (maxY - minY) + threshold * 2)
                if rect.contains(point) {
                    indicesToRemove.insert(idx)
                }
                
            case .shape:
                if annotation.shapeType == .rectangle || annotation.shapeType == .circle || annotation.shapeType == .star || annotation.shapeType == .diamond || annotation.shapeType == .hexagon {
                    let minX = annPoints.map { $0.x }.min() ?? 0
                    let maxX = annPoints.map { $0.x }.max() ?? 0
                    let minY = annPoints.map { $0.y }.min() ?? 0
                    let maxY = annPoints.map { $0.y }.max() ?? 0
                    let rect = CGRect(x: minX - threshold, y: minY - threshold, width: (maxX - minX) + threshold * 2, height: (maxY - minY) + threshold * 2)
                    if rect.contains(point) {
                        indicesToRemove.insert(idx)
                    }
                } else {
                    for p in annPoints {
                        if distance(p, point) < threshold {
                            indicesToRemove.insert(idx)
                            break
                        }
                    }
                }
                
            case .blur, .snippet:
                let minX = annPoints.map { $0.x }.min() ?? 0
                let maxX = annPoints.map { $0.x }.max() ?? 0
                let minY = annPoints.map { $0.y }.min() ?? 0
                let maxY = annPoints.map { $0.y }.max() ?? 0
                let rect = CGRect(x: minX - threshold, y: minY - threshold, width: (maxX - minX) + threshold * 2, height: (maxY - minY) + threshold * 2)
                if rect.contains(point) {
                    indicesToRemove.insert(idx)
                }
                
            case .pen, .highlighter, .marker, .arrow:
                for p in annPoints {
                    if distance(p, point) < threshold {
                        indicesToRemove.insert(idx)
                        break
                    }
                }
            default:
                break
            }
        }
        
        if !indicesToRemove.isEmpty {
            saveHistory()
            for idx in indicesToRemove.sorted(by: >) {
                annotations.remove(at: idx)
            }
            if let selectedID = selectedAnnotationID, !annotations.contains(where: { $0.id == selectedID }) {
                selectedAnnotationID = nil
            }
        }
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
    }
    
    func startDrawing(at point: CGPoint, in size: CGSize) {
        guard !isImageTransformMode else { return }
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
        guard !isImageTransformMode else { return }
        let normalizedPoint = CGPoint(x: point.x / size.width, y: point.y / size.height)
        guard let current = currentAnnotation else { return }
        
        let isContinuous = current.tool == .pen || current.tool == .marker || current.tool == .highlighter || current.tool == .erase || current.shapeType == .freehand || (current.tool == .arrow && current.arrowStyle == .rough)
        
        if isContinuous {
            currentAnnotation?.points.append(normalizedPoint)
        } else {
            // Geometric tools only need first and last
            if current.points.count >= 2 {
                currentAnnotation?.points[1] = normalizedPoint
            } else {
                currentAnnotation?.points.append(normalizedPoint)
            }
        }
    }
    
    func endDrawing() {
        guard !isImageTransformMode else { return }
        if let annotation = currentAnnotation {
            if annotation.tool == .text {
                editingAnnotationID = annotation.id
            }
            saveHistory()
            annotations.append(annotation)
            currentAnnotation = nil
        }
    }
    
    func saveHistory() {
        let state = EditorHistoryState(annotations: annotations, image: currentImage)
        historyStack.append(state)
        redoHistory = []
        if historyStack.count > 30 { historyStack.removeFirst() }
    }
    
    func undo() {
        guard !historyStack.isEmpty else { return }
        let currentState = EditorHistoryState(annotations: annotations, image: currentImage)
        redoHistory.append(currentState)
        
        let prevState = historyStack.removeLast()
        self.annotations = prevState.annotations
        if let prevImg = prevState.image {
            self.currentImage = prevImg
        }
    }
    
    func redo() {
        guard !redoHistory.isEmpty else { return }
        let currentState = EditorHistoryState(annotations: annotations, image: currentImage)
        historyStack.append(currentState)
        
        let nextState = redoHistory.removeLast()
        self.annotations = nextState.annotations
        if let nextImg = nextState.image {
            self.currentImage = nextImg
        }
    }
    
    func analyzeImage() {
        Task {
            let result = await ScreenshotAnalyzer.shared.analyze(imageURL: imageURL)
            await MainActor.run { self.extractedText = result.text }
        }
    }
    
    func removeBackground() { /* Placeholder for AI logic */ }
    
    // MARK: - Layer Controls (Phase 4.2)
    
    func bringForward() {
        guard let id = selectedAnnotationID,
              let idx = annotations.firstIndex(where: { $0.id == id }),
              idx < annotations.count - 1 else { return }
        saveHistory()
        annotations.swapAt(idx, idx + 1)
    }
    
    func sendBackward() {
        guard let id = selectedAnnotationID,
              let idx = annotations.firstIndex(where: { $0.id == id }),
              idx > 0 else { return }
        saveHistory()
        annotations.swapAt(idx, idx - 1)
    }
    
    func bringToFront() {
        guard let id = selectedAnnotationID,
              let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        saveHistory()
        let ann = annotations.remove(at: idx)
        annotations.append(ann)
    }
    
    func sendToBack() {
        guard let id = selectedAnnotationID,
              let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        saveHistory()
        let ann = annotations.remove(at: idx)
        annotations.insert(ann, at: 0)
    }
    
    func deleteSelected() {
        guard let id = selectedAnnotationID else { return }
        saveHistory()
        annotations.removeAll { $0.id == id }
        selectedAnnotationID = nil
    }
    
    func duplicateSelected() {
        guard let id = selectedAnnotationID,
              var ann = annotations.first(where: { $0.id == id }) else { return }
        saveHistory()
        ann = CanvasAnnotation(
            id: UUID(), tool: ann.tool, color: ann.color,
            points: ann.points.map { CGPoint(x: $0.x + 0.02, y: $0.y + 0.02) },
            text: ann.text, lineWidth: ann.lineWidth, opacity: ann.opacity,
            arrowStyle: ann.arrowStyle, shapeType: ann.shapeType,
            isSolid: ann.isSolid, isDashed: ann.isDashed,
            fontName: ann.fontName, fontSize: ann.fontSize,
            isBold: ann.isBold, isItalic: ann.isItalic, isUnderlined: ann.isUnderlined,
            offset: CGSize(width: ann.offset.width + 10, height: ann.offset.height + 10),
            image: ann.image, cornerRadius: ann.cornerRadius, rotation: ann.rotation
        )
        annotations.append(ann)
        selectedAnnotationID = ann.id
    }
    
    func selectAll() {
        // Multi-select not yet implemented, just select last
        selectedAnnotationID = annotations.last?.id
    }
    
    func nudgeSelected(dx: CGFloat, dy: CGFloat) {
        guard let id = selectedAnnotationID,
              let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        saveHistory()
        annotations[idx].offset.width += dx
        annotations[idx].offset.height += dy
    }
}

struct ScreenshotEditorView: View {
    @Bindable var state: ScreenshotEditorState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenshotItem.capturedAt, order: .reverse) private var items: [ScreenshotItem]
    

    @State private var isExporting: Bool = false
    @State private var keyMonitor: Any? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. UNIFIED COMMAND SURFACE (Header)
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .ignoresSafeArea()
                
                HStack(spacing: 8) {
                    Spacer().frame(width: 16) // Elegant leading padding
                    
                    // 1. Thumbnail Collapse
                    CommandButton(icon: "sidebar.left", active: !state.isThumbnailsCollapsed) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { state.isThumbnailsCollapsed.toggle() }
                    }
                    
                    // 2. Undo
                    CommandButton(icon: "arrow.uturn.backward") { state.undo() }
                    
                    // 3. Redo
                    CommandButton(icon: "arrow.uturn.forward") { state.redo() }
                    
                    // Space between Redo and Rotate
                    Divider()
                        .frame(height: 18)
                        .padding(.horizontal, 8)
                        .opacity(0.3)
                    
                    // 4. Rotate
                    CommandButton(icon: "rotate.right") { state.rotate() }
                    
                    // 5. Crop
                    CommandButton(icon: "crop", active: state.isImageTransformMode) {
                        state.isImageTransformMode.toggle()
                    }
                    
                    // 6. Select tool (Cursor)
                    ToolButton(tool: .cursor, 
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
                    
                    // 7. Corner Radius
                    CornerRadiusButton(radius: $state.cornerRadius, state: state)
                    
                    // Remaining drawing tools in the correct order
                    let remainingTools: [CanvasTool] = [.pen, .marker, .highlighter, .arrow, .shape, .text, .blur, .erase, .snippet]
                    ForEach(remainingTools, id: \.self) { tool in
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
                    
                    // Annotation Color Swatch (Robust System Picker with no button background)
                    ZStack {
                        Circle()
                            .fill(state.selectedColor)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        
                        MinimalColorPicker(selection: $state.selectedColor)
                            .frame(width: 34, height: 34)
                    }
                    .frame(width: 34, height: 34)
                    
                    // Background Magic Swatch
                    BackgroundSwatchButton(current: $state.canvasBackground)
                        .frame(width: 34, height: 34)
                    
                    Spacer()
                    
                    // Secondary Actions
                    
                    CommandButton(icon: "trash", color: .red) {
                        state.saveHistory()
                        state.annotations.removeAll()
                    }
                    
                    // SAVE Menu — Two-mode export
                    Menu {
                        Button(action: {
                            Task { await saveWithBackground() }
                        }) {
                            Label("Save with Background", systemImage: "photo.fill")
                        }
                        Button(action: {
                            Task { await saveScreenshotOnly() }
                        }) {
                            Label("Save Screenshot Only", systemImage: "scissors")
                        }
                        Divider()
                        Button(action: {
                            Task { await copyToClipboard() }
                        }) {
                            Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                        }
                    } label: {
                        Group {
                            if isExporting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.6)
                                    .frame(width: 60, height: 34)
                            } else {
                                Text("SAVE")
                                    .font(.system(size: 11, weight: .black))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 9)
                                    .background(Capsule().fill(Color.white))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .padding(.trailing, 20)
                }
            }
            .frame(height: 64)
            .zIndex(10) // Ensure header is always on top for interactions
            .overlay(Divider().opacity(0.2), alignment: .bottom)
            
            // 2. MAIN STUDIO AREA
            HStack(spacing: 0) {
                // LEFT PANEL: THUMBNAILS
                if !state.isThumbnailsCollapsed {
                    ScreenshotsSidebarView(state: state, items: items, onSnippetDrop: { img in
                        saveSnippetToHistory(img)
                    })
                }
                
                // CENTER PANEL: THE CANVAS
                GeometryReader { viewportGeo in
                    ScreenshotStudioCanvasView(state: state, viewportGeo: viewportGeo)
                }
                
                // RIGHT PANEL: INSIGHTS & SNIPPETS
                VStack(alignment: .leading, spacing: 24) {
                    // Snippets Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "scissors")
                                .font(.system(size: 12, weight: .bold))
                            Text("EXTRACTED SNIPPETS")
                                .font(.system(size: 10, weight: .black))
                                .tracking(1.2)
                        }
                        .foregroundColor(.white.opacity(0.4))
                        
                        if state.extractedSnippets.isEmpty {
                            Text("Use the scissors tool to capture specific areas.")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.3))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(state.extractedSnippets) { snippet in
                                        ZStack(alignment: .topTrailing) {
                                            Image(nsImage: snippet.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 80, height: 80)
                                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .onDrag { NSItemProvider(object: snippet.id.uuidString as NSString) }
                                            
                                            Button(action: { state.extractedSnippets.removeAll(where: { $0.id == snippet.id }) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white.opacity(0.6))
                                                    .background(Circle().fill(Color.black.opacity(0.4)))
                                            }
                                            .buttonStyle(.plain)
                                            .padding(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider().opacity(0.1)
                    
                    // Text Insights Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                            Text("TEXT INSIGHTS")
                                .font(.system(size: 10, weight: .black))
                                .tracking(1.2)
                        }
                        .foregroundColor(.white.opacity(0.4))
                        
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
                .overlay(Divider().opacity(0.2), alignment: .leading)
            }
        }
        .frame(minWidth: 1100, minHeight: 750)
        .preferredColorScheme(.dark)
        .onExitCommand { state.cancelEditing() }
        .onAppear {
            // Phase 4.1: Register keyboard shortcuts via NSEvent local monitor
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak state] event in
                guard let state = state else { return event }
                let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
                let isMeta = flags == .command
                let isMetaShift = flags == [.command, .shift]
                let isPlain = flags.isEmpty

                switch event.keyCode {
                case 6  where isMeta:      state.undo();            return nil // ⌘Z
                case 6  where isMetaShift: state.redo();            return nil // ⌘⇧Z
                case 1  where isMeta:      state.selectAll();       return nil // ⌘A  (s=1? no — 'a'=0, 's'=1) wait
                case 0  where isMeta:      state.selectAll();       return nil // ⌘A (keyCode 0 = 'a')
                case 2  where isMeta:      state.duplicateSelected(); return nil // ⌘D
                case 51: // Delete/Backspace
                    if isPlain || isMeta { state.deleteSelected(); return nil }
                case 117: // Forward Delete
                    if isPlain { state.deleteSelected(); return nil }
                case 123 where isPlain:    state.nudgeSelected(dx: -1, dy: 0); return nil // ← Arrow
                case 124 where isPlain:    state.nudgeSelected(dx: 1,  dy: 0); return nil // → Arrow
                case 125 where isPlain:    state.nudgeSelected(dx: 0,  dy: 1); return nil // ↓ Arrow
                case 126 where isPlain:    state.nudgeSelected(dx: 0,  dy: -1); return nil // ↑ Arrow
                case 123 where flags == .shift: state.nudgeSelected(dx: -10, dy: 0); return nil
                case 124 where flags == .shift: state.nudgeSelected(dx: 10,  dy: 0); return nil
                case 125 where flags == .shift: state.nudgeSelected(dx: 0,  dy: 10); return nil
                case 126 where flags == .shift: state.nudgeSelected(dx: 0,  dy: -10); return nil
                // Tool shortcuts
                case 9  where isPlain: state.selectedTool = .cursor;      return nil // V
                case 35 where isPlain: state.selectedTool = .pen;          return nil // P
                case 17 where isPlain: state.selectedTool = .text;         return nil // T
                case 1  where isPlain: state.selectedTool = .shape;        return nil // S
                case 0  where isPlain: state.selectedTool = .arrow;        return nil // A
                case 11 where isPlain: state.selectedTool = .blur;         return nil // B
                // Layer controls
                case 30 where isMeta:  state.bringForward();  return nil // ⌘]
                case 33 where isMeta:  state.sendBackward();  return nil // ⌘[
                default: break
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }

        .onChange(of: state.cornerRadius) { _, newValue in
            state.activeItem?.cornerRadius = newValue
        }
        .onChange(of: state.rotation) { _, newValue in
            state.activeItem?.rotation = newValue
        }
        .onAppear {
            if state.activeItem == nil {
                state.activeItem = items.first(where: { $0.filePath == state.imageURL.path })
                if let item = state.activeItem {
                    state.cornerRadius = item.cornerRadius
                    state.rotation = item.rotation
                }
            }
        }
    }
    
    // MARK: - Export Functions
    
    @MainActor
    private func saveWithBackground() async {
        guard let image = renderWithBackground() else { return }
        presentSavePanel(image: image, suggestedName: "screenshot_canvas")
    }
    
    @MainActor
    private func saveScreenshotOnly() async {
        guard let image = renderScreenshotOnly() else { return }
        presentSavePanel(image: image, suggestedName: "screenshot")
    }
    
    @MainActor
    private func copyToClipboard() async {
        guard let image = renderScreenshotOnly() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    /// Renders the full canvas — background gradient/colour + padded screenshot + annotations.
    @MainActor
    private func renderWithBackground() -> NSImage? {
        guard let screenshot = state.currentImage else { return nil }
        let padding: CGFloat = 160
        let aspectRatio = screenshot.size.width / max(screenshot.size.height, 1)
        let canvasW: CGFloat = max(screenshot.size.width, 1200)
        let canvasH: CGFloat = canvasW / aspectRatio + padding * 2
        let canvasSize = CGSize(width: canvasW, height: canvasH)
        
        let outputImage = NSImage(size: canvasSize)
        outputImage.lockFocus()
        defer { outputImage.unlockFocus() }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }
        
        // 1. Fill background
        ctx.saveGState()
        switch state.canvasBackground {
        case .color(let c):
            ctx.setFillColor(NSColor(c).cgColor)
            ctx.fill(CGRect(origin: .zero, size: canvasSize))
        case .gradient(let swiftColors):
            let cgColors = swiftColors.map { NSColor($0).cgColor }
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: cgColors as CFArray,
                                         locations: nil) {
                ctx.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: canvasSize.width, y: canvasSize.height),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
        }
        ctx.restoreGState()
        
        // 2. Draw screenshot card with cornerRadius mask
        let baseW = canvasW - padding * 2
        let baseH = canvasH - padding * 2
        let scaleX = state.imageScaleX
        let scaleY = state.imageScaleY
        let scaledW = baseW * scaleX
        let scaledH = baseH * scaleY
        let screenshotRect = CGRect(
            x: padding + (baseW - scaledW) / 2,
            y: padding + (baseH - scaledH) / 2,
            width: scaledW,
            height: scaledH
        )
        ctx.saveGState()
        let clipPath = CGPath(roundedRect: screenshotRect,
                              cornerWidth: state.cornerRadius,
                              cornerHeight: state.cornerRadius, transform: nil)
        ctx.addPath(clipPath)
        ctx.clip()
        screenshot.draw(in: screenshotRect)
        ctx.restoreGState()
        
        // 3. Composite annotations scaled into screenshotRect
        renderAnnotationsToCGContext(ctx, in: screenshotRect)
        
        return outputImage
    }
    
    /// Renders only the screenshot at native resolution with annotations, no canvas background.
    @MainActor
    private func renderScreenshotOnly() -> NSImage? {
        guard let screenshot = state.currentImage else { return nil }
        let size = screenshot.size
        
        let outputImage = NSImage(size: size)
        outputImage.lockFocus()
        defer { outputImage.unlockFocus() }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }
        
        // 1. Clip to cornerRadius
        ctx.saveGState()
        let clipPath = CGPath(roundedRect: CGRect(origin: .zero, size: size),
                              cornerWidth: state.cornerRadius,
                              cornerHeight: state.cornerRadius, transform: nil)
        ctx.addPath(clipPath)
        ctx.clip()
        screenshot.draw(in: CGRect(origin: .zero, size: size))
        ctx.restoreGState()
        
        // 2. Composite annotations at native screenshot scale
        renderAnnotationsToCGContext(ctx, in: CGRect(origin: .zero, size: size))
        
        return outputImage
    }
    
    /// Re-draws all annotations into a CGContext scaled to `targetRect`.
    private func renderAnnotationsToCGContext(_ ctx: CGContext, in targetRect: CGRect) {
        let size = targetRect.size
        // We reuse the SwiftUI drawing logic via ImageRenderer for annotations
        let renderer = ImageRenderer(content:
            Canvas { context, canvasSize in
                for annotation in state.annotations {
                    drawAnnotation(annotation, state: state, in: context, size: canvasSize)
                }
            }
            .frame(width: size.width, height: size.height)
        )
        renderer.scale = 2.0
        if let annotationImage = renderer.nsImage {
            NSGraphicsContext.current?.saveGraphicsState()
            annotationImage.draw(in: targetRect)
            NSGraphicsContext.current?.restoreGraphicsState()
        }
    }
    
    @MainActor
    private func presentSavePanel(image: NSImage, suggestedName: String) {
        isExporting = true
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.begin { [self] response in
            isExporting = false
            guard response == .OK, let url = panel.url else { return }
            if let data = image.pngData() {
                try? data.write(to: url)
            }
        }
    }
    
    @MainActor
    private func saveSnippetToHistory(_ image: NSImage) {
        let docs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        let managedURL = docs.appendingPathComponent("Notchly/Screenshots", isDirectory: true)
        
        let filename = "Snippet_\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = managedURL.appendingPathComponent(filename)
        
        if let data = image.tiffRepresentation, 
           let bitmap = NSBitmapImageRep(data: data), 
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
            
            let newItem = ScreenshotItem(
                filename: filename, 
                filePath: fileURL.path, 
                contentType: .snippet
            )
            modelContext.insert(newItem)
            try? modelContext.save()
        }
    }
}

// MARK: - Canvas View Component
struct ScreenshotStudioCanvasView: View {
    @Bindable var state: ScreenshotEditorState
    let viewportGeo: GeometryProxy
    
    @State private var dragStartAnnotationOffset: CGSize = .zero
    @State private var activeDragAnnotationID: UUID? = nil
    @State private var isDraggingActive = false
    @FocusState private var focusedFieldID: UUID?
    
    var body: some View {
        ZStack {
            // Studio Floor
            Group {
                switch state.canvasBackground {
                case .color(let color): color
                case .gradient(let colors): LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .ignoresSafeArea()
            
            // Viewport container for the interactive screenshot
            if let image = state.currentImage {
                let imageAspectRatio = image.size.width / max(image.size.height, 1)
                let maxDisplayW = viewportGeo.size.width - 160
                let maxDisplayH = viewportGeo.size.height - 160
                let fitWidth = maxDisplayW / maxDisplayH > imageAspectRatio ? (maxDisplayH * imageAspectRatio) : maxDisplayW
                let fitHeight = maxDisplayW / maxDisplayH > imageAspectRatio ? maxDisplayH : (maxDisplayW / imageAspectRatio)
                
                let li = state.imageCropInsets.leading * fitWidth
                let ri = state.imageCropInsets.trailing * fitWidth
                let ti = state.imageCropInsets.top * fitHeight
                let bi = state.imageCropInsets.bottom * fitHeight
                
                let layoutLi = state.isImageTransformMode ? 0 : li
                let layoutRi = state.isImageTransformMode ? 0 : ri
                let layoutTi = state.isImageTransformMode ? 0 : ti
                let layoutBi = state.isImageTransformMode ? 0 : bi
                
                let displayW = max(10, fitWidth - layoutLi - layoutRi)
                let displayH = max(10, fitHeight - layoutTi - layoutBi)
                
                ZStack {
                    // 1. Scaled container (Base image & Canvas together)
                    ZStack {
                        // Base image
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: fitWidth, height: fitHeight)
                            .offset(x: (layoutLi - layoutRi)/2 + state.imagePanOffset.width * fitWidth, y: (layoutTi - layoutBi)/2 + state.imagePanOffset.height * fitHeight)
                            .clipShape(RoundedRectangle(cornerRadius: state.cornerRadius))
                        
                        // Canvas annotations layer
                        ZStack {
                            CanvasDrawingLayer(
                                state: state,
                                fitWidth: fitWidth,
                                fitHeight: fitHeight,
                                dragStartAnnotationOffset: $dragStartAnnotationOffset,
                                activeDragAnnotationID: $activeDragAnnotationID,
                                isDraggingActive: $isDraggingActive
                            )
                            
                            SelectionOverlayLayer(
                                state: state,
                                fitWidth: fitWidth,
                                fitHeight: fitHeight
                            )
                            
                            TextEditorOverlayLayer(
                                state: state,
                                fitWidth: fitWidth,
                                fitHeight: fitHeight,
                                focusedFieldID: $focusedFieldID
                            )
                        }
                        .frame(width: fitWidth, height: fitHeight)
                        .offset(x: (layoutLi - layoutRi)/2 + state.imagePanOffset.width * fitWidth, y: (layoutTi - layoutBi)/2 + state.imagePanOffset.height * fitHeight)
                        .allowsHitTesting(!state.isImageTransformMode)
                    }
                    .scaleEffect(x: state.imageScaleX, y: state.imageScaleY, anchor: .center)
                    .frame(width: displayW, height: displayH)
                    .clipShape(RoundedRectangle(cornerRadius: state.cornerRadius))
                    
                    // 2. Image Transform Overlay (drawn AT THE VERY TOP)
                    if state.isImageTransformMode {
                        ImageTransformOverlay(state: state, size: CGSize(width: fitWidth, height: fitHeight))
                    }
                }
                .scaleEffect(state.viewport.zoomScale)
                .offset(state.viewport.panOffset)
                .rotationEffect(.degrees(state.rotation))
                .padding(80)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
                .shadow(color: .black.opacity(0.15), radius: 40, x: 0, y: 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .clipped()
                .onDrop(of: ["public.text"], isTargeted: nil) { providers, location in
                    for provider in providers {
                        _ = provider.loadObject(ofClass: NSString.self) { dropString, _ in
                            if let dropString = dropString as? String {
                                if let uuid = UUID(uuidString: dropString) {
                                    if let snippet = state.extractedSnippets.first(where: { $0.id == uuid }) {
                                        DispatchQueue.main.async { state.addImageSticker(image: snippet.image) }
                                    }
                                } else if let image = NSImage(contentsOfFile: dropString) {
                                    DispatchQueue.main.async { state.addImageSticker(image: image) }
                                }
                            }
                        }
                    }
                    return true
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(white: 0.1)
                ScrollWheelReader { event in
                    let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1.0 : 10.0
                    let dx = event.scrollingDeltaX * scale
                    let dy = event.scrollingDeltaY * scale
                    state.viewport.panOffset = CGSize(
                        width: state.viewport.panOffset.width + dx,
                        height: state.viewport.panOffset.height + dy
                    )
                    state.viewport.lastPanOffset = state.viewport.panOffset
                }
            }
        )
        .onContinuousHover { phase in
            if case .active(let location) = phase {
                state.viewport.hoverLocation = location
            }
        }
        .clipped()
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    let newScale = state.viewport.lastZoomScale * value
                    state.viewport.zoomScale = min(max(newScale, 0.5), 5.0)
                }
                .onEnded { _ in
                    state.viewport.lastZoomScale = state.viewport.zoomScale
                }
        )
        .overlay(alignment: .bottom) {
            if state.isImageTransformMode {
                TransformControlPanel(state: state)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: state.editingAnnotationID) { oldValue, newValue in
            focusedFieldID = newValue
        }
    }
}

// MARK: - Scroll Wheel Event Interceptor for Trackpad Panning
struct ScrollWheelReader: NSViewRepresentable {
    let onScroll: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollTrackingView()
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let trackingView = nsView as? ScrollTrackingView {
            trackingView.onScroll = onScroll
        }
    }
    
    class ScrollTrackingView: NSView {
        var onScroll: ((NSEvent) -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func scrollWheel(with event: NSEvent) {
            onScroll?(event)
            nextResponder?.scrollWheel(with: event)
        }
    }
}

// MARK: - Canvas Drawing & Gesture Sub-component

struct CanvasDrawingLayer: View {
    @Bindable var state: ScreenshotEditorState
    let fitWidth: CGFloat
    let fitHeight: CGFloat
    @Binding var dragStartAnnotationOffset: CGSize
    @Binding var activeDragAnnotationID: UUID?
    @Binding var isDraggingActive: Bool
    
    var body: some View {
        Canvas { context, size in
            for annotation in state.annotations { 
                drawAnnotation(annotation, state: state, in: context, size: size) 
            }
            if let current = state.currentAnnotation { 
                drawAnnotation(current, state: state, in: context, size: size) 
            }
        }
        .background(Color.white.opacity(0.001))
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .local)
                .onChanged { value in
                    guard !state.isImageTransformMode else { return }
                    if state.selectedTool == .cursor {
                        if !isDraggingActive {
                            isDraggingActive = true
                            let clickedID = state.findAnnotation(at: value.startLocation, in: CGSize(width: fitWidth, height: fitHeight))
                            activeDragAnnotationID = clickedID
                            if let id = clickedID {
                                state.saveHistory()
                                state.selectedAnnotationID = id
                                if let index = state.annotations.firstIndex(where: { $0.id == id }) {
                                    dragStartAnnotationOffset = state.annotations[index].offset
                                }
                            } else {
                                state.selectedAnnotationID = nil
                                state.viewport.lastPanOffset = state.viewport.panOffset
                            }
                        }
                        
                        if let id = activeDragAnnotationID, let index = state.annotations.firstIndex(where: { $0.id == id }) {
                            state.annotations[index].offset = CGSize(
                                width: dragStartAnnotationOffset.width + value.translation.width,
                                height: dragStartAnnotationOffset.height + value.translation.height
                            )
                        } else {
                            state.viewport.panOffset = CGSize(
                                width: state.viewport.lastPanOffset.width + value.translation.width * state.viewport.zoomScale,
                                height: state.viewport.lastPanOffset.height + value.translation.height * state.viewport.zoomScale
                            )
                        }
                    } else {
                        if state.currentAnnotation == nil { 
                            state.startDrawing(at: value.startLocation, in: CGSize(width: fitWidth, height: fitHeight)) 
                        }
                        state.updateDrawing(to: value.location, in: CGSize(width: fitWidth, height: fitHeight))
                    }
                }
                .onEnded { _ in 
                    guard !state.isImageTransformMode else { return }
                    isDraggingActive = false
                    if state.selectedTool == .cursor && activeDragAnnotationID == nil {
                        state.viewport.lastPanOffset = state.viewport.panOffset
                    }
                    activeDragAnnotationID = nil
                    if state.selectedTool == .cursor {
                        // Keep selection
                    } else if state.selectedTool == .snippet {
                        if let current = state.currentAnnotation {
                            captureSnippet(state: state, shape: state.selectedShapeType, points: current.points, size: CGSize(width: fitWidth, height: fitHeight))
                            state.currentAnnotation = nil
                        }
                    } else {
                        state.endDrawing() 
                    }
                }
        )
        .simultaneousGesture(
            SpatialTapGesture(count: 2)
                .onEnded { event in
                    guard !state.isImageTransformMode else { return }
                    if let id = state.findAnnotation(at: event.location, in: CGSize(width: fitWidth, height: fitHeight)) {
                        state.startEditingText(id: id)
                    }
                }
        )
        .simultaneousGesture(
            SpatialTapGesture(count: 1)
                .onEnded { event in
                    guard !state.isImageTransformMode else { return }
                    if state.selectedTool == .cursor {
                        state.selectAnnotation(at: event.location, in: CGSize(width: fitWidth, height: fitHeight))
                    } else if state.selectedTool == .text {
                        if let id = state.findAnnotation(at: event.location, in: CGSize(width: fitWidth, height: fitHeight)) {
                            if let index = state.annotations.firstIndex(where: { $0.id == id }), state.annotations[index].tool == .text {
                                state.editingAnnotationID = id
                            } else {
                                state.startDrawing(at: event.location, in: CGSize(width: fitWidth, height: fitHeight))
                                state.endDrawing()
                            }
                        } else {
                            state.startDrawing(at: event.location, in: CGSize(width: fitWidth, height: fitHeight))
                            state.endDrawing()
                        }
                    } else {
                        state.selectAnnotation(at: event.location, in: CGSize(width: fitWidth, height: fitHeight))
                    }
                }
        )
    }
}

// MARK: - Canvas Selection Overlay Sub-component

struct SelectionOverlayLayer: View {
    @Bindable var state: ScreenshotEditorState
    let fitWidth: CGFloat
    let fitHeight: CGFloat
    
    private func getRect(for ann: CanvasAnnotation) -> CGRect {
        let points = ann.points
        let minX: CGFloat
        let maxX: CGFloat
        let minY: CGFloat
        let maxY: CGFloat
        if points.count > 2 {
            let xs = points.map { $0.x }
            let ys = points.map { $0.y }
            minX = xs.min() ?? 0
            maxX = xs.max() ?? 0
            minY = ys.min() ?? 0
            maxY = ys.max() ?? 0
        } else {
            let first = points.first ?? .zero
            let last = points.last ?? .zero
            minX = min(first.x, last.x)
            maxX = max(first.x, last.x)
            minY = min(first.y, last.y)
            maxY = max(first.y, last.y)
        }
        
        let isTextTap = ann.tool == .text && abs(maxX - minX) < 0.005
        let boxWidth = isTextTap ? (CGFloat(max(ann.text.count, 5)) * ann.fontSize * 0.6) : max(abs(maxX - minX) * fitWidth, 20)
        let boxHeight = isTextTap ? (ann.fontSize * 1.5) : max(abs(maxY - minY) * fitHeight, 20)
        
        return CGRect(
            x: (minX * fitWidth) + ann.offset.width,
            y: (minY * fitHeight) + ann.offset.height,
            width: boxWidth,
            height: boxHeight
        )
    }
    
    var body: some View {
        Group {
            if let selectedID = state.selectedAnnotationID, 
               let index = state.annotations.firstIndex(where: { $0.id == selectedID }) {
                let ann = state.annotations[index]
                if ann.tool == .sticker || ann.tool == .shape || ann.tool == .arrow || ann.tool == .text {
                    AnnotationSelectionOverlay(
                        rect: getRect(for: ann),
                        annotation: ann,
                        state: state,
                        viewportSize: CGSize(width: fitWidth, height: fitHeight)
                    )
                }
            }
        }
    }
}

// MARK: - Canvas Text Editor Overlay Sub-component

struct TextEditorOverlayLayer: View {
    @Bindable var state: ScreenshotEditorState
    let fitWidth: CGFloat
    let fitHeight: CGFloat
    var focusedFieldID: FocusState<UUID?>.Binding
    
    var body: some View {
        ZStack {
            if state.editingAnnotationID != nil {
                Color.white.opacity(0.001)
                    .onTapGesture { state.editingAnnotationID = nil }
            }
            
            ForEach($state.annotations) { $annotation in
                if state.editingAnnotationID == annotation.id {
                    AnnotationTextEditorView(
                        annotation: $annotation,
                        state: state,
                        fitWidth: fitWidth,
                        fitHeight: fitHeight,
                        focusedFieldID: focusedFieldID
                    )
                }
            }
        }
    }
}

struct AnnotationTextEditorView: View {
    @Binding var annotation: CanvasAnnotation
    @Bindable var state: ScreenshotEditorState
    let fitWidth: CGFloat
    let fitHeight: CGFloat
    var focusedFieldID: FocusState<UUID?>.Binding
    
    var body: some View {
        let first = annotation.points.first ?? .zero
        let last = annotation.points.last ?? .zero
        let isTap = abs(first.x - last.x) < 0.005
        
        let boxWidth = isTap ? 200 : max(abs(first.x - last.x) * fitWidth, 40)
        let boxHeight = isTap ? (annotation.fontSize * 1.8) : max(abs(first.y - last.y) * fitHeight, 20)
        
        return TextField("Type something...", text: $annotation.text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.custom(annotation.fontName, size: annotation.fontSize).weight(annotation.isBold ? .bold : .regular))
            .italic(annotation.isItalic)
            .underline(annotation.isUnderlined)
            .foregroundColor(annotation.color)
            .padding(4)
            .focused(focusedFieldID, equals: annotation.id)
            .frame(width: boxWidth, height: boxHeight, alignment: .topLeading)
            .position(x: (min(first.x, last.x) * fitWidth) + (boxWidth / 2) + annotation.offset.width, 
                      y: (min(first.y, last.y) * fitHeight) + (boxHeight / 2) + annotation.offset.height)
            .onExitCommand { state.cancelEditing() }
            .onSubmit { state.editingAnnotationID = nil }
    }
}

// MARK: - Drawing Utility Helper Functions

fileprivate func captureSnippet(state: ScreenshotEditorState, shape: ShapeType, points: [CGPoint], size: CGSize) {
    let renderer = ImageRenderer(content: 
        ZStack {
            if let nsImage = state.currentImage {
                Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit)
            }
            Canvas { context, size in
                for annotation in state.annotations {
                    drawAnnotation(annotation, state: state, in: context, size: size)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    )
    
    guard let fullImage = renderer.nsImage else { return }
    
    let scaledPoints = points.map { CGPoint(x: $0.x * size.width, y: (1 - $0.y) * size.height) }
    guard scaledPoints.count >= 2 else { return }
    let minX = scaledPoints.map { $0.x }.min() ?? 0
    let maxX = scaledPoints.map { $0.x }.max() ?? 0
    let minY = scaledPoints.map { $0.y }.min() ?? 0
    let maxY = scaledPoints.map { $0.y }.max() ?? 0
    let rect = CGRect(x: minX, y: minY, width: max(maxX - minX, 1), height: max(maxY - minY, 1))
    
    let snippetImage = NSImage(size: rect.size)
    snippetImage.lockFocus()
    
    let maskPath = NSBezierPath()
    let localPoints = points.map { CGPoint(x: ($0.x * size.width) - rect.minX, y: ((1 - $0.y) * size.height) - rect.minY) }
    
    switch shape {
    case .rectangle:
        maskPath.appendRect(CGRect(origin: .zero, size: rect.size))
    case .circle:
        maskPath.appendOval(in: CGRect(origin: .zero, size: rect.size))
    case .triangle:
        let r = CGRect(origin: .zero, size: rect.size)
        maskPath.move(to: CGPoint(x: r.midX, y: r.maxY))
        maskPath.line(to: CGPoint(x: r.maxX, y: r.minY))
        maskPath.line(to: CGPoint(x: r.minX, y: r.minY))
        maskPath.close()
    case .star:
        let r = CGRect(origin: .zero, size: rect.size)
        let center = CGPoint(x: r.midX, y: r.midY)
        let rx = r.width / 2
        let ry = r.height / 2
        let pointsCount = 5
        let angleIncrement = CGFloat.pi * 2 / CGFloat(pointsCount * 2)
        var firstPoint = true
        for i in 0..<(pointsCount * 2) {
            let angle = CGFloat(i) * angleIncrement - CGFloat.pi / 2
            let isOuter = i % 2 == 0
            let rX = isOuter ? rx : rx * 0.4
            let rY = isOuter ? ry : ry * 0.4
            let pt = CGPoint(x: center.x + rX * cos(angle), y: center.y - rY * sin(angle))
            if firstPoint {
                maskPath.move(to: pt)
                firstPoint = false
            } else {
                maskPath.line(to: pt)
            }
        }
        maskPath.close()
    case .diamond:
        let r = CGRect(origin: .zero, size: rect.size)
        maskPath.move(to: CGPoint(x: r.midX, y: r.minY))
        maskPath.line(to: CGPoint(x: r.maxX, y: r.midY))
        maskPath.line(to: CGPoint(x: r.midX, y: r.maxY))
        maskPath.line(to: CGPoint(x: r.minX, y: r.midY))
        maskPath.close()
    case .hexagon:
        let r = CGRect(origin: .zero, size: rect.size)
        let dx = r.width * 0.25
        maskPath.move(to: CGPoint(x: r.minX + dx, y: r.minY))
        maskPath.line(to: CGPoint(x: r.maxX - dx, y: r.minY))
        maskPath.line(to: CGPoint(x: r.maxX, y: r.midY))
        maskPath.line(to: CGPoint(x: r.maxX - dx, y: r.maxY))
        maskPath.line(to: CGPoint(x: r.minX + dx, y: r.maxY))
        maskPath.line(to: CGPoint(x: r.minX, y: r.midY))
        maskPath.close()
    case .freehand, .line:
        if let f = localPoints.first {
            maskPath.move(to: f)
            for p in localPoints.dropFirst() { maskPath.line(to: p) }
            maskPath.close()
        }
    }
    
    maskPath.setClip()
    fullImage.draw(in: CGRect(origin: .zero, size: rect.size), from: rect, operation: .sourceOver, fraction: 1.0)
    snippetImage.unlockFocus()
    
    state.extractedSnippets.append(ExtractedSnippet(image: snippetImage))
}

fileprivate func drawAnnotation(_ annotation: CanvasAnnotation, state: ScreenshotEditorState, in context: GraphicsContext, size: CGSize) {
    guard !annotation.points.isEmpty else { return }
    let scaledPoints = annotation.points.map { 
        CGPoint(x: ($0.x * size.width) + annotation.offset.width, 
                y: ($0.y * size.height) + annotation.offset.height) 
    }
    
    // Special style for snippet selection
    if annotation.tool == .snippet {
        let strokeStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [5, 3])
        
        // Draw the selection shape
        let minX = scaledPoints.map { $0.x }.min() ?? 0
        let maxX = scaledPoints.map { $0.x }.max() ?? 0
        let minY = scaledPoints.map { $0.y }.min() ?? 0
        let maxY = scaledPoints.map { $0.y }.max() ?? 0
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        
        var selectionPath = Path()
        switch annotation.shapeType {
        case .rectangle:
            if annotation.cornerRadius > 0 {
                selectionPath = Path(roundedRect: rect, cornerRadius: CGFloat(annotation.cornerRadius))
            } else {
                selectionPath = Path(rect)
            }
        case .circle: selectionPath = Path(ellipseIn: rect)
        case .triangle:
            selectionPath.move(to: CGPoint(x: rect.midX, y: rect.minY))
            selectionPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            selectionPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            selectionPath.closeSubpath()
        case .star:
            selectionPath = pathForStar(in: rect)
        case .diamond:
            selectionPath = pathForDiamond(in: rect)
        case .hexagon:
            selectionPath = pathForHexagon(in: rect)
        case .freehand, .line:
            selectionPath.addLines(scaledPoints)
            selectionPath.closeSubpath()
        }
        
        context.fill(selectionPath, with: .color(Color.blue.opacity(0.15)))
        context.stroke(selectionPath, with: .color(Color.blue), style: strokeStyle)
        return
    }
    if annotation.tool == .erase {
        var localCtx = context
        localCtx.blendMode = .clear
        for point in scaledPoints {
            let eraseRect = CGRect(
                x: point.x - annotation.lineWidth,
                y: point.y - annotation.lineWidth,
                width: annotation.lineWidth * 2,
                height: annotation.lineWidth * 2
            )
            localCtx.fill(Path(ellipseIn: eraseRect), with: .color(.white))
        }
        return
    }
    
    let strokeStyle = StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round, dash: annotation.isDashed ? [annotation.lineWidth * 2, annotation.lineWidth] : [])
    
    context.drawLayer { ctx in
        // Apply rotation
        let minX = scaledPoints.map { $0.x }.min() ?? 0
        let maxX = scaledPoints.map { $0.x }.max() ?? 0
        let minY = scaledPoints.map { $0.y }.min() ?? 0
        let maxY = scaledPoints.map { $0.y }.max() ?? 0
        let center = CGPoint(x: (minX + maxX)/2, y: (minY + maxY)/2)
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: .degrees(annotation.rotation))
        ctx.translateBy(x: -center.x, y: -center.y)
        
        switch annotation.tool {
        case .pen, .highlighter, .marker:
            var p = Path()
            p.addLines(scaledPoints)
            ctx.stroke(p, with: .color(annotation.color.opacity(annotation.opacity)), style: strokeStyle)
            
        case .arrow:
            drawCurvedArrow(in: ctx, annotation: annotation, size: size)
            
        case .shape:
            drawShape(in: ctx, annotation: annotation, size: size)
            
        case .text:
            if state.editingAnnotationID == annotation.id { return }
            let first = scaledPoints.first ?? .zero
            let last = scaledPoints.last ?? .zero
            let isTap = abs(first.x - last.x) < 0.002
            let rect = CGRect(
                x: min(first.x, last.x),
                y: min(first.y, last.y),
                width: isTap ? 200 : max(abs(first.x - last.x), 40),
                height: isTap ? (annotation.fontSize * 1.8) : max(abs(first.y - last.y), 20)
            )
            
            let font = Font.custom(annotation.fontName, size: annotation.fontSize)
            let resolved = ctx.resolve(Text(annotation.text).font(font).foregroundColor(annotation.color).fontWeight(annotation.isBold ? .bold : .regular).italic(annotation.isItalic))
            ctx.draw(resolved, in: rect)
            
        case .sticker:
            if let image = annotation.image {
                let first = scaledPoints.first ?? .zero
                let last = scaledPoints.last ?? .zero
                let rect = CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: max(abs(first.x - last.x), 20), height: max(abs(first.y - last.y), 20))
                
                ctx.drawLayer { sctx in
                    let clipPath = Path(roundedRect: rect, cornerRadius: annotation.cornerRadius)
                    sctx.clip(to: clipPath)
                    sctx.draw(Image(nsImage: image), in: rect)
                }
                
                if state.selectedAnnotationID == annotation.id {
                    let clipPath = Path(roundedRect: rect, cornerRadius: annotation.cornerRadius)
                    ctx.stroke(clipPath, with: .color(.blue.opacity(0.5)), lineWidth: 2)
                }
            }
        case .blur:
            // Draw a frosted-glass blur region using SwiftUI's blur filter
            guard scaledPoints.count >= 2,
                  let first = scaledPoints.first, let last = scaledPoints.last else { break }
            let blurRect = CGRect(
                x: min(first.x, last.x),
                y: min(first.y, last.y),
                width: max(abs(first.x - last.x), 4),
                height: max(abs(first.y - last.y), 4)
            )
            // Render the base image cropped to blurRect and blurred dynamically
            if let baseImg = state.currentImage,
               let cgImg = baseImg.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let pixelWidth = CGFloat(cgImg.width)
                let pixelHeight = CGFloat(cgImg.height)
                
                let scaleX = pixelWidth / size.width
                let scaleY = pixelHeight / size.height
                
                // Expand by blur radius to prevent transparent edges
                let radius = annotation.lineWidth
                let expandedRect = blurRect.insetBy(dx: -radius, dy: -radius)
                
                // CGImage cropping is top-left oriented, matching SwiftUI canvas!
                let cropX = max(0, min(expandedRect.origin.x * scaleX, pixelWidth - 1))
                let cropY = max(0, min(expandedRect.origin.y * scaleY, pixelHeight - 1))
                let cropW = max(1, min(expandedRect.width * scaleX, pixelWidth - cropX))
                let cropH = max(1, min(expandedRect.height * scaleY, pixelHeight - cropY))
                let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
                
                if let croppedCg = cgImg.cropping(to: cropRect) {
                    let croppedNsImage = NSImage(cgImage: croppedCg, size: expandedRect.size)
                    ctx.drawLayer { layerCtx in
                        layerCtx.clip(to: Path(blurRect))
                        layerCtx.addFilter(.blur(radius: radius))
                        layerCtx.draw(Image(nsImage: croppedNsImage).resizable(), in: expandedRect)
                    }
                }
            }
            // Overlay a semi-transparent tint so the region is clearly redacted
            let tintPath = Path(blurRect)
            ctx.fill(tintPath, with: .color(annotation.color.opacity(0.25)))
            ctx.stroke(tintPath, with: .color(annotation.color.opacity(0.5)), lineWidth: 1.5)
        default: break
        }
    }
}

fileprivate func drawShape(in context: GraphicsContext, annotation: CanvasAnnotation, size: CGSize) {
    let points = annotation.points.map { 
        CGPoint(x: ($0.x * size.width) + annotation.offset.width, 
                y: ($0.y * size.height) + annotation.offset.height) 
    }
    guard points.count >= 2, let first = points.first, let last = points.last else { return }
    
    let rect = CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(first.x - last.x), height: abs(first.y - last.y))
    var path = Path()
    let strokeStyle = StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round, dash: annotation.isDashed ? [annotation.lineWidth * 2, annotation.lineWidth] : [])
    
    switch annotation.shapeType {
    case .rectangle:
        if annotation.cornerRadius > 0 {
            path = Path(roundedRect: rect, cornerRadius: CGFloat(annotation.cornerRadius))
        } else {
            path = Path(rect)
        }
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
    case .star:
        path = pathForStar(in: rect)
    case .diamond:
        path = pathForDiamond(in: rect)
    case .hexagon:
        path = pathForHexagon(in: rect)
    case .freehand:
        path.addLines(points)
        path.closeSubpath()
    }
    
    if annotation.isSolid && annotation.shapeType != .line {
        context.fill(path, with: .color(annotation.color.opacity(annotation.opacity)))
    } else {
        context.stroke(path, with: .color(annotation.color.opacity(annotation.opacity)), style: strokeStyle)
    }
}

fileprivate func pathForStar(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let rx = rect.width / 2
    let ry = rect.height / 2
    let points = 5
    let angleIncrement = CGFloat.pi * 2 / CGFloat(points * 2)
    
    var first = true
    for i in 0..<(points * 2) {
        let angle = CGFloat(i) * angleIncrement - CGFloat.pi / 2
        let isOuter = i % 2 == 0
        let rX = isOuter ? rx : rx * 0.4
        let rY = isOuter ? ry : ry * 0.4
        let pt = CGPoint(x: center.x + rX * cos(angle), y: center.y + rY * sin(angle))
        if first {
            path.move(to: pt)
            first = false
        } else {
            path.addLine(to: pt)
        }
    }
    path.closeSubpath()
    return path
}

fileprivate func pathForDiamond(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
    path.closeSubpath()
    return path
}

fileprivate func pathForHexagon(in rect: CGRect) -> Path {
    var path = Path()
    let w = rect.width
    let dx = w * 0.25
    path.move(to: CGPoint(x: rect.minX + dx, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - dx, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.maxX - dx, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX + dx, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
    path.closeSubpath()
    return path
}

fileprivate func drawArrowheadManual(in context: GraphicsContext, at end: CGPoint, angle: Double, color: Color, width: CGFloat) {
    let headLength: CGFloat = 12 + width
    let headAngle: CGFloat = .pi / 6
    var path = Path()
    path.move(to: end)
    path.addLine(to: CGPoint(x: end.x - headLength * cos(angle - headAngle), y: end.y - headLength * sin(angle - headAngle)))
    path.move(to: end)
    path.addLine(to: CGPoint(x: end.x - headLength * cos(angle + headAngle), y: end.y - headLength * sin(angle + headAngle)))
    context.stroke(path, with: .color(color), lineWidth: width)
}

fileprivate func drawCurvedArrow(in context: GraphicsContext, annotation: CanvasAnnotation, size: CGSize) {
    let points = annotation.points.map { 
        CGPoint(x: ($0.x * size.width) + annotation.offset.width, 
                y: ($0.y * size.height) + annotation.offset.height) 
    }
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

struct ScreenshotsSidebarView: View {
    @Bindable var state: ScreenshotEditorState
    var items: [ScreenshotItem]
    var onSnippetDrop: (NSImage) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("SCREENSHOTS")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white.opacity(0.3))
                .tracking(1.2)
                .padding(.top, 4)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ForEach(items) { item in
                        let isActive = state.imageURL.path == item.filePath
                        ThumbnailItem(item: item, isActive: isActive) {
                            // Save current annotations before switching
                            let currentPath = state.imageURL.path
                            state.allAnnotations[currentPath] = state.annotations
                            
                            state.imageURL = URL(fileURLWithPath: item.filePath)
                            state.currentImage = NSImage(contentsOf: state.imageURL)
                            state.analyzeImage()
                            state.cornerRadius = item.cornerRadius
                            state.rotation = item.rotation
                            state.activeItem = item
                            
                            // Load annotations for the new item
                            let newPath = state.imageURL.path
                            let loaded: [CanvasAnnotation] = state.allAnnotations[newPath] ?? []
                            state.annotations = loaded
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .onDrop(of: [.image, .text], isTargeted: nil) { providers in
                for provider in providers {
                    if provider.canLoadObject(ofClass: NSImage.self) {
                        provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                            if let data = data, let image = NSImage(data: data) {
                                DispatchQueue.main.async {
                                    onSnippetDrop(image)
                                }
                            }
                        }
                    } else {
                        _ = provider.loadObject(ofClass: NSString.self) { uuidString, _ in
                            if let uuidString = uuidString as? String, let uuid = UUID(uuidString: uuidString) {
                                if let snippet = state.extractedSnippets.first(where: { $0.id == uuid }) {
                                    DispatchQueue.main.async {
                                        onSnippetDrop(snippet.image)
                                    }
                                }
                            }
                        }
                    }
                }
                return true
            }
        }
        .padding(24)
        .frame(width: 200)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        .overlay(Divider().opacity(0.2), alignment: .trailing)
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
                .frame(width: 34, height: 34)
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
    @State private var showSnippetPicker = false
    
    var body: some View {
        Button(action: { 
            if tool == .shape { showShapePicker.toggle() }
            if tool == .arrow { showArrowPicker.toggle() }
            if tool == .text { showTypographyPicker.toggle() }
            if tool == .pen || tool == .marker || tool == .highlighter || tool == .blur || tool == .erase { showStrokePicker.toggle() }
            if tool == .snippet { showSnippetPicker.toggle() }
            current = tool 
        }) {
            Image(systemName: toolIcon(tool, arrowStyle: arrowStyle, shapeType: shapeType, isSolid: isSolid))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(current == tool ? .white : .white.opacity(0.4))
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(current == tool ? Color.white.opacity(0.15) : Color.white.opacity(0.05)))
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
                        Text("Avenir").tag("Avenir")
                        Text("Times New Roman").tag("Times New Roman")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 188)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("SIZE").font(.system(size: 10, weight: .bold)).opacity(0.6)
                    HStack(spacing: 12) {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        HUDSlider(value: $fontSize, range: 1...120)
                            .frame(width: 80)
                        
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                        
                        TextField("", value: $fontSize, format: .number)
                            .textFieldStyle(.plain)
                            .frame(width: 36)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.1)))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
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
                Text(current == .blur ? "BLUR SETTINGS" : (current == .erase ? "ERASER SETTINGS" : "STROKE SETTINGS"))
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(current == .blur ? "BLUR RADIUS" : (current == .erase ? "ERASER SIZE" : "WIDTH")).font(.system(size: 10, weight: .bold)).opacity(0.6)
                    HStack(spacing: 12) {
                        HUDSlider(value: $lineWidth, range: current == .blur ? 1.0...100.0 : (current == .erase ? 5.0...80.0 : 1.0...40.0))
                            .frame(minWidth: 120)
                        TextField("", value: $lineWidth, format: .number)
                            .textFieldStyle(.plain)
                            .frame(width: 40)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                }
                
                if current != .blur && current != .erase {
                    Toggle(isOn: $isDashed) {
                        Text("DASHED STROKE").font(.system(size: 10, weight: .bold))
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .padding(16)
            .frame(width: 220)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        }
        .popover(isPresented: $showSnippetPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                Text("SNIPPET MODE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
                
                HStack(spacing: 12) {
                    ForEach([ShapeType.rectangle, .circle, .triangle, .freehand], id: \.self) { type in
                        Button(action: { shapeType = type; current = .snippet; showSnippetPicker = false }) {
                            Image(systemName: snippetTypeIcon(type))
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 6).fill(shapeType == type ? Color.blue.opacity(0.2) : Color.white.opacity(0.05)))
                                .foregroundColor(shapeType == type ? .blue : .white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
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
                
                // Shape Type Rows
                VStack(alignment: .leading, spacing: 10) {
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
                    HStack(spacing: 12) {
                        ForEach([ShapeType.star, .diamond, .hexagon], id: \.self) { type in
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
        case .cursor: return "cursorarrow"
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
        case .snippet: return "scissors"
        case .erase: return "eraser"
        case .blur: return "aqi.medium"
        case .sticker: return "photo"
        }
    }
    
    private func shapeIcon(_ type: ShapeType, solid: Bool) -> String {
        switch type {
        case .rectangle: return solid ? "square.fill" : "square"
        case .circle: return solid ? "circle.fill" : "circle"
        case .triangle: return solid ? "triangle.fill" : "triangle"
        case .line: return "line.diagonal"
        case .freehand: return "scribble"
        case .star: return solid ? "star.fill" : "star"
        case .diamond: return solid ? "diamond.fill" : "diamond"
        case .hexagon: return solid ? "hexagon.fill" : "hexagon"
        }
    }
    
    private func snippetTypeIcon(_ type: ShapeType) -> String {
        switch type {
        case .rectangle: return "square.dashed"
        case .circle: return "circle.dashed"
        case .triangle: return "triangle.dashed"
        case .freehand: return "scissors"
        default: return "square.dashed"
        }
    }
}

struct CornerRadiusButton: View {
    @Binding var radius: Double
    @Bindable var state: ScreenshotEditorState
    @State private var showPopover = false
    
    var body: some View {
        Button(action: { showPopover.toggle() }) {
            Image(systemName: "square.dashed")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(showPopover ? .white : .white.opacity(0.4))
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(showPopover ? Color.white.opacity(0.15) : Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text(state.selectedAnnotationID != nil ? "OBJECT RADIUS" : "SCREENSHOT RADIUS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
                
                HStack(spacing: 12) {
                    HUDSlider(value: radiusBinding, range: 0...100)
                        .frame(minWidth: 140)
                    
                    Text("\(Int(radiusBinding.wrappedValue))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(width: 30)
                }
            }
            .padding(16)
            .frame(width: 240)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        }
    }
    
    private var radiusBinding: Binding<Double> {
        Binding(
            get: { 
                if let id = state.selectedAnnotationID, let idx = state.annotations.firstIndex(where: { $0.id == id }) {
                    return state.annotations[idx].cornerRadius
                }
                return radius 
            },
            set: { newValue in
                if let id = state.selectedAnnotationID, let idx = state.annotations.firstIndex(where: { $0.id == id }) {
                    state.annotations[idx].cornerRadius = newValue
                } else {
                    radius = newValue
                }
            }
        )
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
                .frame(width: 22, height: 22)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: 8).fill(showPicker ? Color.white.opacity(0.15) : Color.clear))
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
                .onDrag { NSItemProvider(object: item.filePath as NSString) }
                
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

// MARK: - Image Transform Overlay

struct ImageTransformOverlay: View {
    @Bindable var state: ScreenshotEditorState
    let size: CGSize

    private let handleSize: CGFloat = 14

    @State private var dragStartPanOffset: CGSize = .zero
    @State private var hasStartedDrag = false
    @State private var isHoveringPanArea = false
    @State private var isDraggingPanArea = false

    @State private var magnifyStartScaleX: CGFloat = 1.0
    @State private var magnifyStartScaleY: CGFloat = 1.0
    @State private var hasStartedMagnify = false

    // Pixel insets from normalized values
    var li: CGFloat { state.imageCropInsets.leading * size.width }
    var ri: CGFloat { state.imageCropInsets.trailing * size.width }
    var ti: CGFloat { state.imageCropInsets.top * size.height }
    var bi: CGFloat { state.imageCropInsets.bottom * size.height }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Darkened crop regions
            cropDim(rect: CGRect(x: 0, y: 0, width: li, height: size.height))
            cropDim(rect: CGRect(x: size.width - ri, y: 0, width: ri, height: size.height))
            cropDim(rect: CGRect(x: li, y: 0, width: size.width - li - ri, height: ti))
            cropDim(rect: CGRect(x: li, y: size.height - bi, width: size.width - li - ri, height: bi))

            // Active crop rect border
            Path(CGRect(x: li, y: ti, width: size.width - li - ri, height: size.height - ti - bi))
                .stroke(Color.white, lineWidth: 1.5)

            // Panning area (if zoomed in)
            if state.imageScaleX > 1.0 {
                Color.white.opacity(0.001)
                    .frame(width: size.width - li - ri, height: size.height - ti - bi)
                    .position(x: li + (size.width - li - ri)/2, y: ti + (size.height - ti - bi)/2)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("cropSpace"))
                            .onChanged { value in
                                if !hasStartedDrag {
                                    dragStartPanOffset = state.imagePanOffset
                                    hasStartedDrag = true
                                }
                                isDraggingPanArea = true
                                NSCursor.closedHand.set()
                                
                                let dx = value.translation.width
                                let dy = value.translation.height
                                
                                let normDx = (dx / state.imageScaleX) / size.width
                                let normDy = (dy / state.imageScaleY) / size.height
                                
                                let proposedX = dragStartPanOffset.width + normDx
                                let proposedY = dragStartPanOffset.height + normDy
                                
                                let S = state.imageScaleX
                                let leading = state.imageCropInsets.leading
                                let trailing = state.imageCropInsets.trailing
                                let top = state.imageCropInsets.top
                                let bottom = state.imageCropInsets.bottom
                                
                                let pxMax = 0.5 * (1.0 - 1.0 / S) + leading / S
                                let pxMin = -0.5 * (1.0 - 1.0 / S) - trailing / S
                                let pyMax = 0.5 * (1.0 - 1.0 / S) + top / S
                                let pyMin = -0.5 * (1.0 - 1.0 / S) - bottom / S
                                
                                state.imagePanOffset.width = Swift.max(pxMin, Swift.min(pxMax, proposedX))
                                state.imagePanOffset.height = Swift.max(pyMin, Swift.min(pyMax, proposedY))
                            }
                            .onEnded { _ in
                                hasStartedDrag = false
                                isDraggingPanArea = false
                                if isHoveringPanArea {
                                    NSCursor.openHand.set()
                                } else {
                                    NSCursor.arrow.set()
                                }
                            }
                    )
                    .onHover { inside in
                        isHoveringPanArea = inside
                        if inside {
                            if isDraggingPanArea {
                                NSCursor.closedHand.set()
                            } else {
                                NSCursor.openHand.set()
                            }
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
            }

            // 4 edge crop handles (orange pill) with 44pt touch areas
            cropHandle(at: CGPoint(x: li, y: ti + (size.height - ti - bi)/2), edge: .left)
            cropHandle(at: CGPoint(x: size.width - ri, y: ti + (size.height - ti - bi)/2), edge: .right)
            cropHandle(at: CGPoint(x: li + (size.width - li - ri)/2, y: ti), edge: .top)
            cropHandle(at: CGPoint(x: li + (size.width - li - ri)/2, y: size.height - bi), edge: .bottom)

            // 4 corner crop handles (white circle with orange stroke) with 44pt touch areas at cropped corners
            cornerCropHandle(at: CGPoint(x: li, y: ti), corner: .topLeft)
            cornerCropHandle(at: CGPoint(x: size.width - ri, y: ti), corner: .topRight)
            cornerCropHandle(at: CGPoint(x: li, y: size.height - bi), corner: .bottomLeft)
            cornerCropHandle(at: CGPoint(x: size.width - ri, y: size.height - bi), corner: .bottomRight)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .coordinateSpace(name: "cropSpace")
        .contentShape(Rectangle())
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    if !hasStartedMagnify {
                        magnifyStartScaleX = state.imageScaleX
                        magnifyStartScaleY = state.imageScaleY
                        hasStartedMagnify = true
                    }
                    let newScale = Swift.max(0.3, Swift.min(3.0, magnifyStartScaleX * value))
                    state.imageScaleX = newScale
                    state.imageScaleY = newScale
                    state.clampPanOffset()
                }
                .onEnded { _ in
                    hasStartedMagnify = false
                }
        )
    }

    enum CropEdge {
        case left, right, top, bottom
    }

    enum CropCorner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    @ViewBuilder
    private func cropDim(rect: CGRect) -> some View {
        if rect.width > 0 && rect.height > 0 {
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    @ViewBuilder
    private func cropHandle(at point: CGPoint, edge: CropEdge) -> some View {
        let isVertical = (edge == .top || edge == .bottom)
        Color.clear
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.orange)
                    .frame(width: isVertical ? 30 : 6, height: isVertical ? 6 : 30)
                    .shadow(color: .black.opacity(0.4), radius: 3)
            )
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("cropSpace"))
                    .onChanged { value in
                        let maxInset: CGFloat = 0.45
                        switch edge {
                        case .left:
                            state.imageCropInsets.leading = Swift.max(0, Swift.min(maxInset, value.location.x / size.width))
                        case .right:
                            state.imageCropInsets.trailing = Swift.max(0, Swift.min(maxInset, (size.width - value.location.x) / size.width))
                        case .top:
                            state.imageCropInsets.top = Swift.max(0, Swift.min(maxInset, value.location.y / size.height))
                        case .bottom:
                            state.imageCropInsets.bottom = Swift.max(0, Swift.min(maxInset, (size.height - value.location.y) / size.height))
                        }
                        state.clampPanOffset()
                    }
            )
    }

    @ViewBuilder
    private func cornerCropHandle(at point: CGPoint, corner: CropCorner) -> some View {
        Color.clear
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .overlay(
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.orange, lineWidth: 1.5))
                    .frame(width: handleSize, height: handleSize)
                    .shadow(color: .black.opacity(0.3), radius: 3)
            )
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("cropSpace"))
                    .onChanged { value in
                        let maxInset: CGFloat = 0.45
                        let R: CGFloat = size.width / size.height
                        
                        // Current state insets
                        let currentLi = state.imageCropInsets.leading * size.width
                        let currentRi = state.imageCropInsets.trailing * size.width
                        let currentTi = state.imageCropInsets.top * size.height
                        let currentBi = state.imageCropInsets.bottom * size.height
                        
                        var x = value.location.x
                        var y = value.location.y
                        
                        let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                        
                        switch corner {
                        case .topLeft:
                            let fixedX = size.width - currentRi
                            let fixedY = size.height - currentBi
                            var w = Swift.max(10, fixedX - x)
                            var h = Swift.max(10, fixedY - y)
                            
                            if isShiftPressed {
                                if w / h > R {
                                    w = h * R
                                    x = fixedX - w
                                } else {
                                    h = w / R
                                    y = fixedY - h
                                }
                            }
                            
                            state.imageCropInsets.leading = Swift.max(0, Swift.min(maxInset, x / size.width))
                            state.imageCropInsets.top = Swift.max(0, Swift.min(maxInset, y / size.height))
                            
                        case .topRight:
                            let fixedX = currentLi
                            let fixedY = size.height - currentBi
                            var w = Swift.max(10, x - fixedX)
                            var h = Swift.max(10, fixedY - y)
                            
                            if isShiftPressed {
                                if w / h > R {
                                    w = h * R
                                    x = fixedX + w
                                } else {
                                    h = w / R
                                    y = fixedY - h
                                }
                            }
                            
                            state.imageCropInsets.trailing = Swift.max(0, Swift.min(maxInset, (size.width - x) / size.width))
                            state.imageCropInsets.top = Swift.max(0, Swift.min(maxInset, y / size.height))
                            
                        case .bottomLeft:
                            let fixedX = size.width - currentRi
                            let fixedY = currentTi
                            var w = Swift.max(10, fixedX - x)
                            var h = Swift.max(10, y - fixedY)
                            
                            if isShiftPressed {
                                if w / h > R {
                                    w = h * R
                                    x = fixedX - w
                                } else {
                                    h = w / R
                                    y = fixedY + h
                                }
                            }
                            
                            state.imageCropInsets.leading = Swift.max(0, Swift.min(maxInset, x / size.width))
                            state.imageCropInsets.bottom = Swift.max(0, Swift.min(maxInset, (size.height - y) / size.height))
                            
                        case .bottomRight:
                            let fixedX = currentLi
                            let fixedY = currentTi
                            var w = Swift.max(10, x - fixedX)
                            var h = Swift.max(10, y - fixedY)
                            
                            if isShiftPressed {
                                if w / h > R {
                                    w = h * R
                                    x = fixedX + w
                                } else {
                                    h = w / R
                                    y = fixedY + h
                                }
                            }
                            
                            state.imageCropInsets.trailing = Swift.max(0, Swift.min(maxInset, (size.width - x) / size.width))
                            state.imageCropInsets.bottom = Swift.max(0, Swift.min(maxInset, (size.height - y) / size.height))
                        }
                        state.clampPanOffset()
                    }
            )
    }
}

struct TransformControlPanel: View {
    @Bindable var state: ScreenshotEditorState

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "minus.magnifyingglass").font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                Slider(value: Binding(
                    get: { (state.imageScaleX + state.imageScaleY) / 2.0 },
                    set: { val in
                        state.imageScaleX = val
                        state.imageScaleY = val
                    }
                ), in: 0.3...3.0).frame(width: 120).tint(.white)
                Image(systemName: "plus.magnifyingglass").font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                Text(String(format: "%.0f%%", ((state.imageScaleX + state.imageScaleY) / 2.0) * 100))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7)).frame(width: 34)
            }
            HStack(spacing: 8) {
                Button("Reset") {
                    withAnimation(.spring(response: 0.3)) {
                        state.resetImageTransform()
                    }
                }
                .font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.15))).buttonStyle(.plain)

                Button("Done") {
                    withAnimation(.spring(response: 0.3)) {
                        state.commitCrop()
                        state.isImageTransformMode = false
                    }
                }
                .font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(Color.white)).buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 10)
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
    
    func jpegData(compressionFactor: CGFloat = 0.9) -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
    }
    
    func cropped(to rect: CGRect) -> NSImage? {
        let croppedImage = NSImage(size: rect.size)
        croppedImage.lockFocus()
        defer { croppedImage.unlockFocus() }
        
        let sourceRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
        self.draw(in: CGRect(origin: .zero, size: rect.size), from: sourceRect, operation: .copy, fraction: 1.0)
        return croppedImage
    }
}

struct AnnotationSelectionOverlay: View {
    let rect: CGRect
    let annotation: CanvasAnnotation
    let state: ScreenshotEditorState
    let viewportSize: CGSize
    
    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.blue, lineWidth: 1.5)
                .frame(width: rect.width, height: rect.height)
            
            // Floating action toolbar above the selection box
            HStack(spacing: 4) {
                // Duplicate
                selectionAction(icon: "plus.square.on.square", color: .blue) {
                    state.duplicateSelected()
                }
                // Send Backward
                selectionAction(icon: "square.2.layers.3d.bottom.filled", color: .white) {
                    state.sendBackward()
                }
                // Bring Forward
                selectionAction(icon: "square.2.layers.3d.top.filled", color: .white) {
                    state.bringForward()
                }
                // Delete
                selectionAction(icon: "trash.fill", color: .red) {
                    state.deleteSelected()
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 8)
            .position(x: rect.width / 2, y: -30)
            
            Group {
                handle(at: .zero, index: 0) // TL
                handle(at: CGPoint(x: rect.width/2, y: 0), index: 1) // TC
                handle(at: CGPoint(x: rect.width, y: 0), index: 2) // TR
                handle(at: CGPoint(x: 0, y: rect.height/2), index: 3) // ML
                handle(at: CGPoint(x: rect.width, y: rect.height/2), index: 4) // MR
                handle(at: CGPoint(x: 0, y: rect.height), index: 5) // BL
                handle(at: CGPoint(x: rect.width/2, y: rect.height), index: 6) // BC
                handle(at: CGPoint(x: rect.width, y: rect.height), index: 7) // BR
                
                // Rotation Handle
                rotationHandle(at: CGPoint(x: rect.width/2, y: -30))
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .rotationEffect(.degrees(annotation.rotation))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func rotationHandle(at point: CGPoint) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.blue).frame(width: 1, height: 18)
            Color.clear
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .overlay(
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .background(Circle().fill(Color.white))
                )
        }
        .position(x: point.x, y: point.y + 9)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let center = CGPoint(x: rect.width/2, y: rect.height/2)
                    let current = value.location
                    let radians = atan2(current.y - center.y, current.x - center.x)
                    state.rotateAnnotation(annotation.id, degrees: Double(radians * 180 / .pi) + 90)
                }
        )
    }
    
    private func handle(at point: CGPoint, index: Int) -> some View {
        Color.clear
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .overlay(
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.blue, lineWidth: 1.5))
                    .frame(width: 10, height: 10)
            )
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if state.initialResizePoints == nil {
                            state.startResize(id: annotation.id)
                        }
                        let isShift = NSEvent.modifierFlags.contains(.shift)
                        state.resizeAnnotation(annotation.id, handleIndex: index, translation: value.translation, in: viewportSize, isShiftPressed: isShift)
                    }
                    .onEnded { _ in
                        state.initialResizePoints = nil
                    }
            )
    }
    
    @ViewBuilder
    private func selectionAction(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct HUDSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let currentX = percentage * width
            
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 4)
                
                // Active Track (Filled)
                Capsule()
                    .fill(Color.blue)
                    .frame(width: max(0, min(currentX, width)), height: 4)
                
                // Thumb Knob (Solid white circle for high visibility in HUD)
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
                    .offset(x: max(0, min(currentX - 6, width - 12)))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let locationX = gesture.location.x
                        let newPercentage = Double(max(0, min(locationX / width, 1.0)))
                        let newValue = range.lowerBound + newPercentage * (range.upperBound - range.lowerBound)
                        value = newValue
                    }
            )
        }
        .frame(height: 16)
    }
}

struct MinimalColorPicker: NSViewRepresentable {
    @Binding var selection: Color
    
    func makeNSView(context: Context) -> NSColorWell {
        let colorWell = NSColorWell()
        colorWell.alphaValue = 0.015 // Highly transparent but fully interactive and hit-testable in AppKit
        if #available(macOS 13.0, *) {
            colorWell.colorWellStyle = .minimal
        } else {
            colorWell.isBordered = false
        }
        colorWell.target = context.coordinator
        colorWell.action = #selector(Coordinator.colorChanged(_:))
        return colorWell
    }
    
    func updateNSView(_ nsView: NSColorWell, context: Context) {
        nsView.color = NSColor(selection)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: MinimalColorPicker
        
        init(_ parent: MinimalColorPicker) {
            self.parent = parent
        }
        
        @objc func colorChanged(_ sender: NSColorWell) {
            parent.selection = Color(sender.color)
        }
    }
}

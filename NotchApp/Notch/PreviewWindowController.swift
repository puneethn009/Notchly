import AppKit
import SwiftUI

class PreviewWindowController: NSWindowController {
    static let shared = PreviewWindowController()
    
    private var hostingView: NSHostingView<AnyView>?
    
    init() {
        let window = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showPreview(item: ScreenshotItem, at screenPoint: NSPoint) {
        let previewView = ScreenshotPreviewPopup(item: item)
        
        if hostingView == nil {
            hostingView = NSHostingView(rootView: AnyView(previewView))
            window?.contentView = hostingView
        } else {
            hostingView?.rootView = AnyView(previewView)
        }
        
        // Size to fit
        let size = NSSize(width: 260, height: 170)
        window?.setFrame(NSRect(x: screenPoint.x - size.width/2, 
                               y: screenPoint.y - size.height - 10, 
                               width: size.width, 
                               height: size.height), display: true)
        
        window?.alphaValue = 0
        window?.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window?.animator().alphaValue = 1
        }
    }
    
    func hidePreview() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window?.animator().alphaValue = 0
        } completionHandler: {
            self.window?.orderOut(nil)
        }
    }
}

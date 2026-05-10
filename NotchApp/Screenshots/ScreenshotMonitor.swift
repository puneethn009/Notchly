import SwiftUI
import OSLog
import SwiftData

class ScreenshotMonitor {
    static let shared = ScreenshotMonitor()
    private let logger = Logger(subsystem: "com.notchly.app", category: "ScreenshotMonitor")
    
    private var stream: FSEventStreamRef?
    private let desktopURL: URL
    private let managedURL: URL
    private var container: ModelContainer?
    
    init() {
        self.desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        
        let docs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        self.managedURL = docs.appendingPathComponent("Notchly/Screenshots", isDirectory: true)
        
        createManagedDirectoryIfNeeded()
    }
    
    func start(container: ModelContainer) {
        self.container = container
        stop()
        
        let path = desktopURL.path as CFString
        let pathsToWatch = [path] as CFArray
        
        var context = FSEventStreamContext(version: 0, info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), retain: nil, release: nil, copyDescription: nil)
        
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        
        stream = FSEventStreamCreate(
            nil,
            { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
                let monitor = Unmanaged<ScreenshotMonitor>.fromOpaque(clientCallBackInfo!).takeUnretainedValue()
                monitor.handleEvents(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            flags
        )
        
        if let stream = stream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
            logger.info("Started monitoring Desktop for screenshots")
        }
    }
    
    func stop() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }
    
    private func handleEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>) {
        let paths = UnsafeBufferPointer(start: eventPaths.assumingMemoryBound(to: UnsafePointer<Int8>.self), count: numEvents)
        
        for i in 0..<numEvents {
            let path = String(cString: paths[i])
            let flags = eventFlags[i]
            
            if (flags & UInt32(kFSEventStreamEventFlagItemCreated)) != 0 || (flags & UInt32(kFSEventStreamEventFlagItemRenamed)) != 0 {
                processPotentialScreenshot(at: path)
            }
        }
    }
    
    private func processPotentialScreenshot(at path: String) {
        let url = URL(fileURLWithPath: path)
        let filename = url.lastPathComponent
        
        let isScreenshot = filename.hasPrefix("Screenshot") || filename.hasPrefix("Screen Shot")
        let hasValidExtension = ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased())
        
        guard isScreenshot && hasValidExtension else { return }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            self.interceptScreenshot(at: url)
        }
    }
    
    private func interceptScreenshot(at sourceURL: URL) {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        
        let destinationURL = managedURL.appendingPathComponent(sourceURL.lastPathComponent)
        
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            logger.info("Intercepted screenshot: \(sourceURL.lastPathComponent) -> \(destinationURL.path)")
            
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    NotchState.shared.lastCapturedScreenshotURL = destinationURL
                    NotchState.shared.isShowingScreenshotPopup = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if NotchState.shared.lastCapturedScreenshotURL == destinationURL {
                        withAnimation {
                            NotchState.shared.isShowingScreenshotPopup = false
                        }
                    }
                }
                
                Task {
                    let result = await ScreenshotAnalyzer.shared.analyze(imageURL: destinationURL)
                    
                    await MainActor.run {
                        if let container = self.container {
                            let context = container.mainContext
                            let newItem = ScreenshotItem(
                                filename: destinationURL.lastPathComponent,
                                filePath: destinationURL.path,
                                contentType: result.contentType,
                                extractedText: result.text
                            )
                            context.insert(newItem)
                            do {
                                try context.save()
                                self.logger.info("Screenshot analysis saved to database: \(result.contentType.rawValue)")
                                print("[Screenshot] Saved to DB: \(destinationURL.lastPathComponent)")
                            } catch {
                                self.logger.error("Failed to save screenshot to database: \(error.localizedDescription)")
                                print("[Screenshot] SAVE ERROR: \(error)")
                            }
                        }
                    }
                }
            }
        } catch {
            logger.error("Failed to move screenshot: \(error.localizedDescription)")
        }
    }
    
    private func createManagedDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: managedURL.path) {
            do {
                try FileManager.default.createDirectory(at: managedURL, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create managed directory: \(error.localizedDescription)")
            }
        }
    }
}

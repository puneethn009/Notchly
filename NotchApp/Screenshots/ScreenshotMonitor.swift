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
        cleanupPendingScreenshots()
    }
    
    private func cleanupPendingScreenshots() {
        let pendingDir = managedURL.appendingPathComponent(".pending")
        guard let files = try? FileManager.default.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil) else { return }
        
        for file in files {
            // Auto-finalize any orphans found in .pending
            NotchState.shared.pendingScreenshotURL = file
            finalizePendingScreenshot(withName: "")
        }
        print("[ScreenshotMonitor] Cleaned up and indexed \(files.count) orphaned captures")
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
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
            logger.info("Started monitoring Desktop for screenshots")
        }
    }
    
    func stop() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamSetDispatchQueue(stream, nil)
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
        
        // Match both "Screenshot" and localizations like "Screen Shot", or check metadata
        let isScreenshotName = filename.hasPrefix("Screenshot") || filename.hasPrefix("Screen Shot")
        let hasValidExtension = ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased())
        
        var isScreenshot = isScreenshotName
        if !isScreenshot && hasValidExtension {
            // Check extended attribute for non-English localizations
            let attrSize = getxattr(path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0)
            if attrSize > 0 {
                isScreenshot = true
            }
        }
        
        guard isScreenshot && hasValidExtension else { return }
        
        print("[ScreenshotMonitor] Potential match detected: \(filename)")
        
        // Wait for macOS to finish writing the file
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s delay
            
            guard FileManager.default.fileExists(atPath: path) else {
                print("[ScreenshotMonitor] File disappeared before processing: \(path)")
                return
            }
            
            let pendingDir = self.managedURL.appendingPathComponent(".pending", isDirectory: true)
            try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)
            
            let tempURL = pendingDir.appendingPathComponent(filename)
            
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                try FileManager.default.moveItem(at: url, to: tempURL)
                print("[ScreenshotMonitor] Successfully moved to pending: \(tempURL.path)")
                
                await MainActor.run {
                    ScreenshotPreviewController.shared.showPreview(for: tempURL)
                    print("[ScreenshotMonitor] Triggered floating preview for: \(filename)")
                }
            } catch {
                print("[ScreenshotMonitor] ERROR moving file: \(error.localizedDescription)")
                self.logger.error("Failed to move to pending: \(error.localizedDescription)")
            }
        }
    }
    
    func finalizePendingScreenshot(withName name: String) {
        guard let sourceURL = NotchState.shared.pendingScreenshotURL else { 
            print("[ScreenshotMonitor] ERROR: No pending screenshot URL found")
            return 
        }
        
        print("[ScreenshotMonitor] Finalizing capture with name: \(name)")
        
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? sourceURL.lastPathComponent : "\(cleanName).\(sourceURL.pathExtension)"
        let destinationURL = managedURL.appendingPathComponent(finalName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            print("[ScreenshotMonitor] Finalized file moved to: \(destinationURL.path)")
            
            Task {
                await MainActor.run {
                    withAnimation {
                        NotchState.shared.pendingScreenshotURL = nil
                        NotchState.shared.lastCapturedScreenshotURL = destinationURL
                    }
                }
                
                let result = await ScreenshotAnalyzer.shared.analyze(imageURL: destinationURL)
                await MainActor.run {
                    if let container = self.container {
                        let newItem = ScreenshotItem(
                            filename: finalName,
                            filePath: destinationURL.path,
                            contentType: result.contentType,
                            extractedText: result.text
                        )
                        container.mainContext.insert(newItem)
                        try? container.mainContext.save()
                        print("[ScreenshotMonitor] DB record created for: \(finalName)")
                    }
                }
            }
        } catch {
            print("[ScreenshotMonitor] ERROR finalising file: \(error.localizedDescription)")
            logger.error("Failed to finalize screenshot: \(error.localizedDescription)")
        }
    }
    
    private func interceptScreenshot(at sourceURL: URL) {
        // This is now handled via processPotentialScreenshot -> finalize
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

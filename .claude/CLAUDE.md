# CLAUDE.md — NotchApp Project Intelligence

> This file tells Claude Code everything it needs to know about this project.
> Read this fully before writing a single line of code.

---

## What This App Is

A native macOS menu bar / notch app that provides:
- **Screenshot Intelligence** — intercept screenshots before they hit the Desktop, analyze with AI, show dynamic actions
- **Universal Clipboard Manager** — track, categorize, and search everything copied
- **Interactive Notch Layer** — expandable notch UI that hovers, expands on hover, shows quick actions
- **PiP for Any Window** — floating always-on-top mini windows for any app
- **Quick Notes + Pins** — lightweight note-taking from the notch
- **Notification Intelligence** — interactive notch-based notification previews

This is NOT an Electron app. This is NOT a menu bar icon app. The UI lives inside/around the physical notch area at the top center of the screen.

---

## Tech Stack — Never Deviate From This

```
UI Layer:        SwiftUI + AppKit hybrid
                 SwiftUI  → all panels, notch overlay, settings, gallery views
                 AppKit   → NSWindow, NSPanel, NSPasteboard, FSEvents, menu bar

Swift Version:   Swift 5.9+ (use async/await, @Observable, structured concurrency)

AI - On Device:  Apple Vision Framework → OCR, barcode, image classification
                 Apple NaturalLanguage  → text categorization, entity extraction
                 Core ML                → background removal (RMBG-1.4 model)

AI - Cloud:      Anthropic Claude API (claude-sonnet-4-6 model)
                 ONLY call Claude API for: summarize, explain code, translate,
                 extract receipt data, smart categorization edge cases
                 Strategy: Vision handles 80% of tasks free + instant.
                 Claude API is the fallback for complex understanding.

Data:            SwiftData (macOS 14+) for all persistence
                 FileManager for screenshot files in ~/Library/Application Support/NotchApp/

Networking:      URLSession only — no third party HTTP libs
```

---

## Project Structure — Maintain This Exactly

```
NotchApp/
├── NotchApp.xcodeproj
├── NotchApp/
│   ├── App/
│   │   ├── NotchAppApp.swift           # @main entry, AppDelegate setup
│   │   ├── AppDelegate.swift           # NSApplicationDelegate, menu bar, lifecycle
│   │   └── AppState.swift              # @Observable global state singleton
│   │
│   ├── Notch/
│   │   ├── NotchWindowController.swift # Creates + positions borderless NSWindow at notch
│   │   ├── NotchOverlayView.swift      # SwiftUI root — hover detection, expand animation
│   │   ├── NotchExpandedView.swift     # Full expanded panel with tab navigation
│   │   └── NotchHoverDetector.swift    # NSTrackingArea mouse enter/exit
│   │
│   ├── Screenshots/
│   │   ├── ScreenshotMonitor.swift     # FSEvents on ~/Desktop, detects new screenshots
│   │   ├── ScreenshotInterceptor.swift # Moves file from Desktop → app gallery instantly
│   │   ├── ScreenshotAnalyzer.swift    # Orchestrates Vision + Claude analysis
│   │   ├── ScreenshotGallery.swift     # SwiftUI LazyVGrid gallery with search
│   │   └── ScreenshotActionBar.swift   # Dynamic action buttons based on ContentType
│   │
│   ├── Clipboard/
│   │   ├── ClipboardMonitor.swift      # Timer polling NSPasteboard every 0.5s
│   │   ├── ClipboardItem.swift         # SwiftData model + ItemType enum
│   │   ├── ClipboardCategorizer.swift  # Regex + NL categorization
│   │   ├── ClipboardHistoryView.swift  # SwiftUI list with search + pin
│   │   └── ClipboardSearch.swift       # Full-text search across text + OCR content
│   │
│   ├── PiP/
│   │   ├── PiPWindowManager.swift      # Manages array of active PiP sessions
│   │   ├── PiPOverlayWindow.swift      # NSPanel .floating level, snap-to-corner
│   │   ├── WindowCaptureSession.swift  # ScreenCaptureKit SCStream per window
│   │   └── PiPControlsView.swift       # Opacity slider, close, resize handle
│   │
│   ├── Notes/
│   │   ├── QuickNoteView.swift         # Instant note composer inside notch
│   │   ├── PinnedFilesView.swift       # Drag-and-drop file pins
│   │   ├── StickyNoteWindow.swift      # Floating NSPanel sticky note
│   │   └── NotesStorage.swift          # SwiftData CRUD for QuickNote model
│   │
│   ├── AI/
│   │   ├── VisionAnalyzer.swift        # VNRecognizeTextRequest, VNDetectBarcodesRequest
│   │   ├── ContentClassifier.swift     # Returns ContentType enum from CGImage
│   │   ├── ClaudeAPIClient.swift       # Anthropic /v1/messages with vision support
│   │   ├── BackgroundRemover.swift     # Core ML RMBG model wrapper
│   │   └── SmartActions.swift          # ContentType → [QuickAction] mapping
│   │
│   ├── Permissions/
│   │   ├── PermissionsManager.swift    # Check + request screen recording, accessibility
│   │   └── PermissionsOnboarding.swift # First-launch SwiftUI permission flow
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift          # TabView: General, AI, Hotkeys, About
│   │   ├── HotkeyManager.swift         # KeyboardShortcuts package integration
│   │   └── PreferencesStore.swift      # Defaults package wrapper
│   │
│   └── Utilities/
│       ├── Extensions/
│       │   ├── NSImage+Extensions.swift
│       │   ├── String+Extensions.swift
│       │   └── View+Extensions.swift
│       ├── Constants.swift             # App-wide constants, directory URLs
│       └── Logger.swift               # os.Logger wrapper with subsystem
│
├── NotchAppTests/
└── Resources/
    ├── Assets.xcassets
    └── Models/                         # CoreML .mlpackage files go here
```

---

## Xcode Project Configuration — Apply This First

### Deployment Target
```
macOS 14.0 (Sonoma) minimum
```

### App Sandbox
```
DISABLED — must be OFF
Reason: FSEvents on Desktop, notch window positioning, 
        clipboard access, and ScreenCaptureKit all require no sandbox
```

### Capabilities Required
```
Hardened Runtime: ON
App Sandbox: OFF
```

### Entitlements File (NotchApp/NotchApp.entitlements)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.screen-capture</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
</dict>
</plist>
```

### Info.plist Required Keys
```xml
<!-- Hide from Dock — this is a menu bar only app -->
<key>LSUIElement</key>
<true/>

<!-- Required for ScreenCaptureKit / PiP -->
<key>NSScreenCaptureUsageDescription</key>
<string>NotchApp needs screen access to create PiP windows for any app.</string>

<!-- Required for global hotkeys -->
<key>NSAccessibilityUsageDescription</key>
<string>NotchApp needs accessibility access for system-wide keyboard shortcuts.</string>

<!-- Required for Apple Events -->
<key>NSAppleEventsUsageDescription</key>
<string>NotchApp uses Apple Events for app integration features.</string>
```

### Swift Package Dependencies
```
https://github.com/sindresorhus/KeyboardShortcuts   (global hotkeys)
https://github.com/sindresorhus/LaunchAtLogin-Modern (login item)
https://github.com/sindresorhus/Defaults             (UserDefaults wrapper)
https://github.com/sparkle-project/Sparkle           (auto-update)
```

---

## Key Technical Patterns — Always Follow These

### Notch Window Creation
```swift
// CRITICAL: window must be borderless, statusBar level, clear background
// Position at EXACT notch coordinates — top center of main screen
let screen = NSScreen.main!
let x = (screen.frame.width - notchWidth) / 2
let y = screen.frame.maxY - notchHeight  // NSScreen coords: 0 = bottom

window.level = .statusBar
window.backgroundColor = .clear
window.isOpaque = false
window.hasShadow = false
window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
window.orderFrontRegardless()
```

### Screenshot Interception Pattern
```swift
// FSEvents latency: 0.1s (100ms) for near-instant detection
// Detect by filename: macOS names them "Screenshot YYYY-MM-DD at HH.MM.SS.png"
// Immediately move to app gallery before user sees it on Desktop
// Then analyze async — never block the move
```

### Clipboard Polling Pattern
```swift
// Poll every 0.5 seconds — NSPasteboard has no push notifications
// Check NSPasteboard.general.changeCount — only process if changed
// Priority: image > file URL > string
// Cap history at 500 items
```

### PiP Window Pattern
```swift
// Use ScreenCaptureKit SCContentFilter(desktopIndependentWindow:)
// NSPanel with .floating window level for always-on-top
// Snap to corners on mouseUp with 200ms animation
// Support multiple simultaneous PiP windows
```

### Claude API Calls
```swift
// Model: claude-sonnet-4-6
// Always include image as base64 for screenshot analysis
// anthropic-version header: "2023-06-01"
// API key stored in Keychain — never in UserDefaults or hardcoded
// Always call on background Task, update UI on MainActor
```

### ContentType Enum — Central to Everything
```swift
enum ContentType {
    case photo
    case textDocument
    case uiScreenshot
    case receipt
    case codeSnippet
    case qrCode
    case table
    case mixed
}
// This drives: what actions show, what AI prompt is used, how it's stored
```

### Dynamic Actions Per ContentType
```
.codeSnippet  → [copyCode, explainCode, debugCode, openInVSCode]
.receipt      → [extractTotals, saveExpense, exportPDF, copyText]
.textDocument → [copyText, summarize, translate, convertToMarkdown, removeSensitiveData]
.photo        → [save, removeBackground, extractObjects, copyImage, share]
.qrCode       → [openURL, copyContent, save]
.uiScreenshot → [copyText, save, share, addToNotes]
```

---

## Data Models (SwiftData)

```swift
@Model class ScreenshotItem {
    var id: UUID
    var filePath: String
    var capturedAt: Date
    var contentType: String      // rawValue of ContentType
    var extractedText: String?   // OCR result from Vision
    var aiSummary: String?       // Claude summary
    var tags: [String]
    var isFavorited: Bool
}

@Model class ClipboardItem {
    var id: UUID
    var content: String
    var type: String             // text/url/code/email/color/otp/image/file
    var copiedAt: Date
    var appSource: String?       // bundle ID of source app
    var imageData: Data?
    var isPinned: Bool
}

@Model class QuickNote {
    var id: UUID
    var content: String
    var createdAt: Date
    var isPinned: Bool
    var isFloating: Bool
    var attachedScreenshotId: UUID?
}

@Model class PinnedFile {
    var id: UUID
    var filePath: String
    var pinnedAt: Date
    var customLabel: String?
}
```

---

## Build Order — Follow Sprints Sequentially

**Never jump ahead. Each sprint depends on the previous.**

### Sprint 1 — Foundation (Do This First)
```
Task 1: Configure Xcode project
        - Set deployment target macOS 14.0
        - Disable App Sandbox
        - Enable Hardened Runtime
        - Create NotchApp.entitlements with all keys
        - Add all Info.plist keys (LSUIElement, usage descriptions)
        - Add all Swift Package dependencies
        - Create full folder group structure in Xcode
        - Verify clean build (Cmd+B, zero errors)

Task 2: NotchWindowController.swift
        - Borderless NSWindow at notch position on NSScreen.main
        - Level .statusBar, clear background, no shadow
        - collectionBehavior canJoinAllSpaces + stationary
        - resizeWindow(to:) method for expand/collapse
        - Singleton pattern

Task 3: NotchOverlayView.swift + NotchExpandedView.swift
        - onHover expand animation with spring physics
        - response: 0.35, dampingFraction: 0.8
        - Collapsed: 37pt height (notch height)
        - Expanded: 280pt height
        - Tab bar: Screenshots | Clipboard | Notes | PiP
        - Calls NotchWindowController.shared.resizeWindow on hover

Task 4: AppDelegate.swift + NotchAppApp.swift
        - NSApplicationDelegate
        - LSUIElement hides Dock icon
        - Menu bar extra with NSStatusItem (right-click → Quit, Settings)
        - Start NotchWindowController.shared on launch
        - Start ClipboardMonitor.shared on launch
        - Start ScreenshotMonitor.shared on launch
```

### Sprint 2 — Screenshot Intelligence
```
Task 5: ScreenshotMonitor.swift
        - FSEventStream on ~/Desktop path
        - 100ms latency
        - Filter: filename contains "Screenshot" + .png/.jpg extension
        - On detect: call ScreenshotInterceptor

Task 6: ScreenshotInterceptor.swift
        - Move file from Desktop to ~/Library/Application Support/NotchApp/Screenshots/
        - Create directory if not exists
        - Trigger ScreenshotAnalyzer async
        - Trigger notch popup on MainActor

Task 7: ContentClassifier.swift + VisionAnalyzer.swift
        - VNDetectBarcodesRequest for QR detection
        - VNRecognizeTextRequest (fast mode) for text density
        - Code pattern heuristics (keywords: func, def, class, import...)
        - Receipt heuristics (total, $, subtax patterns)
        - Returns ContentType enum

Task 8: ScreenshotActionBar.swift
        - Horizontal ScrollView of action buttons
        - Actions array computed from ContentType
        - Each ActionButton triggers its handler async

Task 9: ScreenshotGallery.swift
        - LazyVGrid, 3 columns
        - Search bar filtering extractedText + aiSummary + tags
        - Tap → full preview with action bar
        - SwiftData @Query for ScreenshotItem
```

### Sprint 3 — Clipboard Intelligence
```
Task 10: ClipboardMonitor.swift
         - Timer 0.5s interval
         - NSPasteboard.general.changeCount tracking
         - Priority: NSImage > fileURL > string
         - Max 500 items, insert at index 0

Task 11: ClipboardCategorizer.swift
         - isURL: URL(string:).scheme == https/http
         - isEmail: regex [A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}
         - isPhone: regex starts with +, digits, dashes
         - isHexColor: starts with # + 6 hex chars
         - isOTP: 4-8 chars, all digits
         - isCode: contains Swift/Python/JS keywords
         - Default: .text

Task 12: ClipboardHistoryView.swift
         - List with sections by date
         - Category icon + preview text
         - Swipe to delete, tap to copy back to clipboard
         - Pin button

Task 13: ClipboardSearch.swift
         - Search across ClipboardItem.content
         - Also search ScreenshotItem.extractedText
         - Unified results view
```

### Sprint 4 — PiP Windows
```
Task 14: PermissionsManager.swift + PermissionsOnboarding.swift
         - Check CGPreflightScreenCaptureAccess()
         - Check AXIsProcessTrusted()
         - Request via SCShareableContent.current (triggers dialog)
         - SwiftUI onboarding shown on first launch if permissions missing

Task 15: WindowCaptureSession.swift
         - SCShareableContent.current to get window list
         - SCContentFilter(desktopIndependentWindow:)
         - SCStreamConfiguration: 30fps, retina scale
         - SCStreamOutput delegate → update PiP frame

Task 16: PiPOverlayWindow.swift
         - NSPanel, .floating level
         - isMovableByWindowBackground = true
         - canJoinAllSpaces + fullScreenAuxiliary
         - mouseUp → snapToNearestCorner() with 200ms animation
         - updateFrame(with: CGImage) for live rendering

Task 17: PiPControlsView.swift + PiPWindowManager.swift
         - Overlay controls: opacity slider, close button
         - Controls fade in on hover, fade out after 2s
         - PiPWindowManager maintains [WindowCaptureSession]
         - Stop stream + close window cleanly
```

### Sprint 5 — Notes, Hotkeys, Settings
```
Task 18: QuickNoteView.swift
         - TextEditor auto-focused on appear
         - DropZone for image/file attachment
         - Buttons: Pin | Save | Float (open as sticky)

Task 19: StickyNoteWindow.swift + NotesStorage.swift
         - NSPanel floating, yellow-ish tint background
         - Resizable, movable, always on top
         - SwiftData persist QuickNote
         - Multiple stickies supported

Task 20: HotkeyManager.swift
         - Cmd+Shift+N → open notch to Notes tab
         - Cmd+Shift+V → open notch to Clipboard tab
         - Cmd+Shift+S → open notch to Screenshots tab
         - Use KeyboardShortcuts package
         - User-customizable via Settings

Task 21: SettingsView.swift + PreferencesStore.swift
         - Tab: General (launch at login, history limits)
         - Tab: AI (Claude API key field → stored in Keychain)
         - Tab: Hotkeys (KeyboardShortcuts.Recorder views)
         - Tab: Permissions (status indicators + re-request buttons)
         - Tab: About (version, links)
```

### Sprint 6 — AI Integration + Polish
```
Task 22: ClaudeAPIClient.swift
         - POST to https://api.anthropic.com/v1/messages
         - model: claude-sonnet-4-6
         - Headers: x-api-key (from Keychain), anthropic-version: 2023-06-01
         - Vision: base64 image + text prompt in single message
         - Async/await with proper error handling

Task 23: Wire Claude into features
         - Screenshot: summarize, explain code, translate, extract receipt JSON
         - Clipboard: smart categorize ambiguous items
         - Each feature uses buildPrompt(for: ContentType) pattern

Task 24: BackgroundRemover.swift
         - Core ML RMBG-1.4 model (download from HuggingFace, add to Resources/Models/)
         - Input: CGImage → Output: CGImage with alpha mask
         - Run on background thread

Task 25: Sparkle auto-update
         - Add SUUpdater to AppDelegate
         - Add SUFeedURL to Info.plist
         - Check for updates on launch (background)
         - Show update UI non-intrusively
```

---

## Common Mistakes — Avoid These

| Mistake | Correct Approach |
|---------|-----------------|
| Using `@main` WindowGroup | Use `@main App` with `NSApplicationDelegateAdaptor` + `Settings {}` only |
| Creating window in SwiftUI | All notch/PiP windows created in AppKit (NSWindowController/NSPanel) |
| Enabling App Sandbox | Must be OFF — this is a direct-distribution app |
| Hardcoding API key | Store in Keychain via `Security` framework |
| Calling Claude API on MainActor | Always `Task { }` on background, `await MainActor.run {}` for UI updates |
| `NSPasteboard` push notifications | Don't exist — must poll with Timer |
| Using UserDefaults for sensitive data | Use Keychain for API key, Defaults package for preferences |
| Single PiP window assumption | Design PiPWindowManager for N simultaneous windows |
| Blocking file move for analysis | Move screenshot instantly, analyze async |
| Forgetting `canJoinAllSpaces` | Notch window must follow user across all Spaces |

---

## File Naming Conventions

```
Views:       *View.swift       (ScreenshotGallery.swift, ClipboardHistoryView.swift)
Controllers: *Controller.swift (NotchWindowController.swift)
Managers:    *Manager.swift    (PiPWindowManager.swift, HotkeyManager.swift)
Monitors:    *Monitor.swift    (ClipboardMonitor.swift, ScreenshotMonitor.swift)
Models:      noun only         (ClipboardItem.swift, QuickNote in NotesStorage.swift)
Clients:     *Client.swift     (ClaudeAPIClient.swift)
```

---

## What Success Looks Like Per Sprint

After Sprint 1: App launches, no Dock icon, menu bar item visible, black notch expands on hover with spring animation, collapses on mouse out. Build is clean.

After Sprint 2: Take a screenshot → it disappears from Desktop → appears in notch popup instantly → action buttons show based on content type.

After Sprint 3: Copy text/image/URL → appears in clipboard history in notch → searchable → OTPs auto-detected.

After Sprint 4: Right-click any window → "Open in PiP" → floating always-on-top mini window → snaps to corner on drag release.

After Sprint 5: Cmd+Shift+N → notch opens to note → type → float as sticky → persists after relaunch.

After Sprint 6: Receipt screenshot → Claude extracts merchant, total, items → shows structured result. Code screenshot → Claude explains it in 2-3 sentences.

---

## Distribution Target

Direct distribution (NOT App Store). Requires:
- Apple Developer ID certificate ($99/year)
- Notarization via `notarytool`
- Sparkle for auto-updates
- Hosted on GitHub Releases or own website

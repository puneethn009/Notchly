# CLAUDE.md — NotchApp Project Intelligence

> This file tells AI agents everything they need to know about this project.
> Read this fully before writing a single line of code.
> Last updated: May 2026

---

## What This App Is

A native macOS menu bar / notch app called **Notchly** that provides:
- **Interactive Notch Layer** — expandable notch UI that hovers, expands on hover, shows live modules
- **Music Player** — live artwork, playback controls, synced lyrics for Apple Music / Spotify / YouTube Music Desktop / TIDAL
- **Screenshot Intelligence** — intercept screenshots, analyze with Vision + Claude, pixel-perfect editor
- **Notchly Hub** — full-window control center to toggle notch modules and manage screenshots
- **System Monitor** — real-time CPU, RAM, network, battery in the notch
- **Timer & Stopwatch** — countdown alarms and stopwatch under the notch
- **Event Calendar** — local calendar + Notion database sync
- **Quick App Launcher** — personalized mini-dock inside the notch

This is NOT an Electron app. This is NOT a menu bar icon app. The UI lives inside/around
the physical notch area at the top center of the screen.

---

## Tech Stack — Never Deviate From This

```
UI Layer:        SwiftUI + AppKit hybrid
                 SwiftUI  → all panels, notch overlay, Hub window, settings
                 AppKit   → NSWindow, NSPanel, NSPasteboard, FSEvents, menu bar

Swift Version:   Swift 5.9+ (use async/await, @Observable, structured concurrency)

AI - On Device:  Apple Vision Framework → OCR, barcode, image classification
                 Apple NaturalLanguage  → text categorization, entity extraction

AI - Cloud:      Anthropic Claude API (claude-sonnet-4-6 model)
                 ONLY call Claude API for: summarize, explain code, translate,
                 extract receipt data, smart categorization edge cases
                 Strategy: Vision handles 80% of tasks free + instant.
                 Claude API is the fallback for complex understanding.

Data:            SwiftData (macOS 14+) for all persistence
                 FileManager for screenshot files in ~/Library/Application Support/NotchApp/

Networking:      URLSession only — no third party HTTP libs
                 Music: HTTP polling to localhost:9863 (TIDAL/YTM Desktop API)
                        Apple Events / MediaRemote for Apple Music / Spotify
```

---

## Project Structure — Current State (May 2026)

```
NotchApp/
├── NotchApp.xcodeproj
├── NotchApp/
│   ├── App/
│   │   ├── NotchAppApp.swift           # @main entry, AppDelegate setup
│   │   ├── AppDelegate.swift           # NSApplicationDelegate, menu bar, Hub launch
│   │   ├── AppState.swift              # @Observable global state singleton
│   │   └── SettingsManager.swift       # @Observable notch module toggles + preferences
│   │
│   ├── Notch/
│   │   ├── NotchWindowController.swift # Creates + positions borderless NSWindow at notch
│   │   ├── NotchOverlayView.swift      # SwiftUI root — hover detection, expand animation
│   │   ├── NotchExpandedView.swift     # Full expanded panel: music, timer, system, calendar, launcher
│   │   ├── NotchShape.swift            # Custom notch shape + outer radius tuning
│   │   ├── NotchHoverDetector.swift    # NSTrackingArea mouse enter/exit
│   │   ├── MediaPlayerManager.swift    # Multi-source media: AppleMusic/Spotify/YTM/TIDAL
│   │   ├── CalendarManager.swift       # EventKit + optional Notion database integration
│   │   ├── LauncherManager.swift       # Quick app launcher dock management
│   │   └── PreviewWindowController.swift # Floating preview window for expanded notch content
│   │
│   ├── Screenshots/
│   │   ├── ScreenshotMonitor.swift     # FSEvents on ~/Desktop, detects new screenshots
│   │   ├── CaptureManager.swift        # Coordinates capture, move, index pipeline
│   │   ├── ScreenshotAnalyzer.swift    # Orchestrates Vision + Claude analysis
│   │   ├── ScreenshotEditorWindow.swift # Full pixel-perfect editor (annotations, crop, export)
│   │   ├── ScreenshotGalleryView.swift # SwiftUI LazyVGrid gallery with search
│   │   ├── ScreenshotActionBar.swift   # Dynamic action buttons based on ContentType
│   │   └── ScreenshotFloatingPreview.swift # Floating preview panel after capture
│   │
│   ├── UI/                             # NEW — Hub window & shared UI utilities
│   │   ├── NotchlyHubView.swift        # Full-window control center (SwiftUI)
│   │   │                               #   → NotchControlsView: toggle each notch module
│   │   │                               #   → ScreenshotManagerView: grid gallery + editor launch
│   │   ├── NotchlyHubWindowController.swift # AppKit NSWindow controller for Hub
│   │   └── VisualEffectView.swift      # NSViewRepresentable wrapper for NSVisualEffectView
│   │
│   ├── Settings/
│   │   └── SettingsView.swift          # Native macOS Settings (TabView: General, Permissions, About)
│   │
│   ├── Permissions/
│   │   ├── PermissionsManager.swift    # Check + request screen recording, accessibility
│   │   └── PermissionsOnboarding.swift # First-launch SwiftUI permission flow
│   │
│   └── Resources/                      # NEW — bundled assets
│       └── (CoreML models, bundled fonts, etc.)
│
└── scratch/                            # Temporary diffs and debug files (not committed)
```

---

## Xcode Project Configuration

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
Ad-hoc codesigning for local Debug builds
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

### Hub Window — Apple Liquid Glass Pattern (CRITICAL)
```swift
// NotchlyHubWindowController.swift — assign hosting controller DIRECTLY
// Never manually size NSVisualEffectView before layout runs (0×0 frame bug)
window.backgroundColor = .clear
window.isOpaque = false
window.titlebarAppearsTransparent = true
window.contentViewController = hostingController  // ← direct, no container NSViewController

// NotchlyHubView.swift — VisualEffectView lives in SwiftUI root ZStack
// SwiftUI auto-sizes it to fill the window — no manual frame needed
var body: some View {
    ZStack {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .ignoresSafeArea()   // ← base glass layer, fills entire window
        HStack(spacing: 0) { ... }  // ← content on top
    }
    .frame(minWidth: 900, maxWidth: .infinity, minHeight: 620, maxHeight: .infinity)
}
```

### macOS Full-Row Tap Target Pattern (CRITICAL)
```swift
// Button + .buttonStyle(.plain) on macOS only hits rendered pixels (icon area)
// ❌ WRONG — text areas won't respond to taps
Button { ... } label: { HStack { Image(...); Text(...); Spacer() } }
    .buttonStyle(.plain)
    .contentShape(Rectangle())  // doesn't fully work on macOS for Text/Spacer

// ✅ CORRECT — ZStack with Color.clear as tap layer, visual HStack below
ZStack(alignment: .leading) {
    Color.clear
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { ... }              // ← handles all taps

    HStack { Image(...); Text(...); Spacer() }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .allowsHitTesting(false)           // ← visual only, no hit testing
}
.fixedSize(horizontal: false, vertical: true)  // ← prevents vertical expansion
.frame(maxWidth: .infinity)
```

### Screenshot Interception Pattern
```swift
// FSEvents latency: 0.1s (100ms) for near-instant detection
// Detect by filename: macOS names them "Screenshot YYYY-MM-DD at HH.MM.SS.png"
// Immediately move to app gallery before user sees it on Desktop
// Then analyze async — never block the move
```

### Music Player Multi-Source Detection
```swift
// Priority order for music source detection:
// 1. Apple Music / Spotify → MediaRemote framework (private, but stable)
// 2. YouTube Music Desktop App → HTTP poll http://localhost:9863/query
// 3. TIDAL Desktop → HTTP poll http://localhost:9863/query (same port as YTM)
// Console errors "Connection refused" on localhost:9863 are EXPECTED when YTM/TIDAL not running
// Never crash or alert on these failures — silently skip
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

---

## Data Models (SwiftData)

```swift
@Model class ScreenshotItem {
    var id: UUID
    var filePath: String
    var filename: String
    var capturedAt: Date
    var contentType: String      // rawValue of ContentType
    var extractedText: String?   // OCR result from Vision
    var aiSummary: String?       // Claude summary
    var tags: [String]
    var isFavorited: Bool
}
```

---

## Settings / Module Toggles (SettingsManager)

`SettingsManager` is a shared `@Observable` / `ObservableObject` singleton.
It controls which modules are visible in the notch and stores user preferences.

```swift
// Notch module visibility — all default true
var showNotchMusic: Bool
var showNotchTimer: Bool
var showNotchSystem: Bool
var showNotchCalendar: Bool
var showNotchLauncher: Bool
var showNotchScreenshots: Bool
```

The **NotchlyHub → Notch Controls** tab binds directly to these properties
via `ToggleCard` components. Changes take effect immediately in the notch.

---

## Notchly Hub Window

**Entry point:** `AppDelegate` calls `NotchlyHubWindowController.shared.show()`

The Hub is a full-size window (default 1100×700, min 900×620, freely resizable)
with an Apple Liquid Glass background (`.hudWindow` material).

**Sidebar tabs:**
- `Notch Controls` → `NotchControlsView` — toggle cards for each notch module
- `Screenshot Manager` → `ScreenshotManagerView` — searchable grid, tap to open editor

**Bottom of sidebar:** Preferences… button → opens native Settings window

---

## Sprint Status — May 2026

### ✅ Sprint 1 — Foundation (COMPLETE)
```
NotchWindowController, NotchOverlayView, NotchExpandedView, AppDelegate
Productivity Hub: Timer, SysMonitor, Media, Calendar, Launcher
```

### ✅ Sprint 2 — Screenshot Intelligence (COMPLETE)
```
ScreenshotMonitor, CaptureManager, Vision analysis pipeline
ScreenshotEditorWindow (full pixel-perfect editor with annotation tools)
ScreenshotFloatingPreview, ScreenshotActionBar, ScreenshotGalleryView
```

### ✅ Sprint 2.5 — Notchly Hub (COMPLETE)
```
NotchlyHubView, NotchlyHubWindowController, VisualEffectView
Apple Liquid Glass window design
Notch module toggles via SettingsManager
Screenshot Manager grid in Hub
```

### 🚀 Sprint 3 — Clipboard Intelligence (NEXT)
```
Task 10: ClipboardMonitor.swift   — Timer 0.5s, changeCount tracking, max 500 items
Task 11: ClipboardCategorizer.swift — URL/email/OTP/code/hex detection
Task 12: ClipboardHistoryView.swift — List by date, pin, swipe-to-delete
Task 13: ClipboardSearch.swift    — Search clipboard + screenshot OCR text
```

### Sprint 4 — PiP Windows
```
Task 14: PermissionsManager + PermissionsOnboarding
Task 15: WindowCaptureSession (ScreenCaptureKit SCStream per window)
Task 16: PiPOverlayWindow (NSPanel .floating, snap-to-corner)
Task 17: PiPControlsView + PiPWindowManager
```

### Sprint 5 — Notes, Hotkeys, Full Settings
```
Task 18: QuickNoteView
Task 19: StickyNoteWindow + NotesStorage (SwiftData)
Task 20: HotkeyManager (Cmd+Shift+N/V/S)
Task 21: Full SettingsView (AI key, hotkeys, permissions tabs)
```

### Sprint 6 — AI + Polish
```
Task 22: ClaudeAPIClient (full vision support)
Task 23: Wire Claude into screenshot + clipboard features
Task 24: BackgroundRemover (Core ML RMBG-1.4)
Task 25: Sparkle auto-update
```

---

## Common Mistakes — Avoid These

| Mistake | Correct Approach |
|---------|-----------------|
| Using `@main` WindowGroup | Use `@main App` with `NSApplicationDelegateAdaptor` + `Settings {}` only |
| Creating window in SwiftUI | All notch/PiP/Hub windows created in AppKit (NSWindowController/NSPanel) |
| Enabling App Sandbox | Must be OFF — this is a direct-distribution app |
| Hardcoding API key | Store in Keychain via `Security` framework |
| Calling Claude API on MainActor | Always `Task { }` on background, `await MainActor.run {}` for UI updates |
| `NSPasteboard` push notifications | Don't exist — must poll with Timer |
| Button+.plain for full-row tap on macOS | Use ZStack + Color.clear + onTapGesture pattern (see above) |
| Fixed SwiftUI `.frame(width:height:)` for resizable windows | Use `.frame(minWidth:maxWidth:minHeight:maxHeight:)` |
| Setting `visualEffectView.frame = visualEffectView.bounds` at init | bounds is 0×0 before layout — let SwiftUI size the VisualEffectView instead |
| `maxHeight: .infinity` on Color.clear inside VStack ZStack | Causes rows to expand and fill parent — use `.fixedSize(horizontal:false, vertical:true)` |
| Crashing/alerting on localhost:9863 connection refused | These are expected when YTM/TIDAL not running — silently ignore |
| Forgetting `canJoinAllSpaces` | Notch window must follow user across all Spaces |
| Single PiP window assumption | Design PiPWindowManager for N simultaneous windows |
| Blocking file move for analysis | Move screenshot instantly, analyze async |

---

## File Naming Conventions

```
Views:       *View.swift       (NotchlyHubView.swift, ScreenshotGalleryView.swift)
Controllers: *Controller.swift (NotchlyHubWindowController.swift)
Managers:    *Manager.swift    (SettingsManager.swift, LauncherManager.swift)
Monitors:    *Monitor.swift    (ScreenshotMonitor.swift)
Models:      noun only         (ScreenshotItem, ClipboardItem)
Clients:     *Client.swift     (ClaudeAPIClient.swift)
```

---

## Build & Verify

```bash
# Always verify after changes
xcodebuild -project NotchApp.xcodeproj -scheme NotchApp -configuration Debug build

# Expected output: ** BUILD SUCCEEDED **
# Ignore: "Metadata extraction skipped. No AppIntents.framework dependency found." (harmless)
```

---

## Distribution Target

Direct distribution (NOT App Store). Requires:
- Apple Developer ID certificate ($99/year)
- Notarization via `notarytool`
- Sparkle for auto-updates
- Hosted on GitHub Releases or own website

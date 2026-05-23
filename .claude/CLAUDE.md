# CLAUDE.md — Notchly Project Intelligence

> Read this fully before writing a single line of code.
> Last updated: May 2026

---

## What This App Is

**Notchly** — a native macOS notch + menu-bar app that wraps the physical notch
into a live productivity hub. It is NOT an Electron app. It is NOT a menu-bar-only
app. The primary UI lives inside and around the physical notch.

Current features (all shipping):
- **Interactive Notch** — expands on hover, collapses on mouse-out, spring-animated
- **Music Player** — live artwork, playback controls, synced lyrics (Apple Music / Spotify / YouTube Music Desktop / TIDAL)
- **Timer & Stopwatch** — countdown alarms + stopwatch under the notch
- **System Monitor** — CPU, RAM, network speed, disk, battery, GPU, thermal
- **Event Calendar** — local EventKit calendars + optional Notion database
- **Quick App Launcher** — pinned app mini-dock inside the notch
- **Screenshot Intelligence** — custom hotkey capture, FSEvents interception, Vision OCR, floating preview, pixel-perfect editor
- **Notchly Hub** — full-window control center: toggle notch modules + browse/edit screenshots

---

## Tech Stack — Never Deviate

```
Language:        Swift 5.9+ — use async/await, structured concurrency, @Observable
UI:              SwiftUI + AppKit hybrid
                 SwiftUI  → notch panels, Hub window, Settings, all content views
                 AppKit   → NSWindow/NSPanel creation, menu bar, FSEvents, CGS private API
Data:            SwiftData (macOS 14+) for ScreenshotItem persistence
                 @AppStorage for all user preferences (via SettingsManager)
Networking:      URLSession only — no 3rd-party HTTP
AI (on-device):  Apple Vision → OCR, barcode, content classification
AI (cloud):      Anthropic Claude API — claude-sonnet-4-6 model
                 Only for: summarize, explain code, translate, extract receipt data
Music sources:   Apple Music + Spotify → DistributedNotificationCenter + NSAppleScript
                 YouTube Music Desktop + TIDAL → HTTP poll http://localhost:9863/query
Artwork:         iTunes Search API (public REST, no auth) as fallback
Global hotkeys:  KeyboardShortcuts package (sindresorhus)
```

---

## Complete File Map — Every Swift File

```
NotchApp/
├── App/
│   ├── NotchAppApp.swift           @main entry — NSApplicationDelegateAdaptor, Settings scene
│   ├── AppDelegate.swift           NSApplicationDelegate — menu bar item, Hub launch,
│   │                               openSettings(), CaptureManager.setup()
│   ├── AppState.swift              @Observable singleton for app-wide ephemeral state
│   ├── NotchState.swift            ObservableObject — isExpanded, isHovering, selectedPage,
│   │                               isSticky, stickyType, lastCapturedScreenshotURL,
│   │                               isShowingScreenshotPopup
│   │                               Also defines: NotchPage enum (media/timer/system/calendar/
│   │                               launcher/screenshots), StickyType enum
│   ├── PersistenceController.swift SwiftData ModelContainer setup — holds ScreenshotItem schema
│   └── SettingsManager.swift       ObservableObject singleton — ALL user preferences via @AppStorage
│                                   Also defines: CustomTimer struct, DockApp struct
│                                   Key properties: showNotchMusic/Timer/System/Calendar/
│                                   Launcher/Screenshots, useAppleMusic, useSpotify,
│                                   calendarSource, notionToken/DatabaseID, enableStopwatch,
│                                   selectedAlarmSound, activeNotchPages: [NotchPage]
│
├── Notch/
│   ├── NotchWindowController.swift Creates NotchPanel (NSPanel subclass, .borderless +
│   │                               .nonactivatingPanel), positions at notch coordinates.
│   │                               Uses CGSSpaceOverlay to pin above all Spaces.
│   │                               collapsedWidth=192, collapsedHeight=29,
│   │                               expandedWidth=700, expandedHeight=200 (via NotchOverlayView)
│   ├── NotchOverlayView.swift      Root SwiftUI view — hover detection, animated width/height,
│   │                               routes to collapsed (music/timer indicators) or expanded view.
│   │                               Holds NotchShape + NotchExpandedView.
│   ├── NotchExpandedView.swift     Full expanded panel. TabView-style page switcher driven by
│   │                               NotchState.selectedPage. Hosts: media player UI + lyrics,
│   │                               timer/stopwatch, system monitor, calendar events,
│   │                               app launcher, screenshot grid.
│   ├── NotchShape.swift            Custom SwiftUI Shape for notch cutout with tunable outer radius.
│   ├── NotchHoverDetector.swift    NSTrackingArea mouse-enter/exit → sets NotchState.isHovering
│   ├── PreviewWindowController.swift Floating NSPanel for previewing expanded notch content
│   │                               when notch collapses (e.g. sticky media/timer state)
│   ├── CGSSpaceOverlay.swift       Private CGS WindowServer API wrapper. Creates a dedicated
│   │                               compositor space at Int32.max level so the notch window
│   │                               stays above ALL macOS Space-switching animations.
│   │                               Adapted from boring.notch (MIT/MPL-2.0).
│   ├── MediaPlayerManager.swift    ObservableObject singleton. Multi-source detection:
│   │                               1. Apple Music → DistributedNotificationCenter
│   │                                  (com.apple.Music.playerInfo)
│   │                               2. Spotify → DistributedNotificationCenter
│   │                                  (com.spotify.client.PlaybackStateChanged) + AppleScript
│   │                               3. YTM/TIDAL → HTTP poll localhost:9863/query (2s interval)
│   │                               Artwork: extracts gradient colors via NSImage+Color.swift.
│   │                               Published: title, artist, artworkImage, artworkColors,
│   │                               primaryArtworkColor, isPlaying, isRunning
│   ├── CalendarManager.swift       ObservableObject. EventKit (local) + optional Notion API.
│   │                               calendarSource: "local" | "notion" | "both"
│   ├── LauncherManager.swift       ObservableObject. Manages [DockApp] dock items.
│   │                               Persists via SettingsManager (Codable + @AppStorage)
│   ├── SystemMonitorManager.swift  ObservableObject. Polls every 2s via Combine Timer.
│   │                               Published: cpuUsage, ramUsage, gpuUsage, uploadSpeed,
│   │                               downloadSpeed, diskUsage, diskText, batteryHealth,
│   │                               batteryCycles, thermalPressure
│   │                               Uses: mach host_statistics, IOKit.ps, NWPathMonitor
│   ├── TimerManager.swift          ObservableObject singleton. Timer + Stopwatch state machine.
│   │                               Published: timeRemaining, isRunning, totalTime, isCompleted,
│   │                               isAlarmPlaying, stopwatchTime, isStopwatchRunning
│   │                               Computed: timeString, stopwatchString, stopwatchShortString, progress
│   └── NSImage+Color.swift         NSImage extension — extractGradientColors() using CIAreaAverage
│                                   filter to extract two dominant colors for artwork gradient glow.
│                                   Also: isTooDark computed property for primary color legibility.
│
├── Screenshots/
│   ├── ScreenshotItem.swift        @Model (SwiftData). Fields: id, filename, filePath,
│   │                               capturedAt, contentType (String), extractedText, isFavorited,
│   │                               cornerRadius (Double=12), rotation (Double=0)
│   ├── ContentType (in Analyzer)   enum: photo/textDocument/uiScreenshot/receipt/codeSnippet/
│   │                               qrCode/snippet/unknown
│   ├── ScreenshotMonitor.swift     FSEvents on ~/Desktop. Detects new screenshots by filename
│   │                               pattern (latency 0.1s). Moves file to app storage immediately,
│   │                               triggers CaptureManager pipeline. Also indexes/cleans orphans.
│   ├── CaptureManager.swift        Singleton. Registers global hotkeys (⌥⇧3 fullscreen,
│   │                               ⌥⇧4 selection) via KeyboardShortcuts package.
│   │                               Runs screencapture CLI, saves to temp, triggers pipeline.
│   ├── ScreenshotAnalyzer.swift    Vision pipeline: VNRecognizeTextRequest (OCR),
│   │                               VNDetectBarcodesRequest → ContentType classification.
│   │                               Returns AnalysisResult { text, barcodes, contentType }
│   ├── ScreenshotEditorWindow.swift Full pixel-perfect editor (3267 lines). Features:
│   │                               annotation tools (pen, shapes, text, arrows),
│   │                               crop, resize, rotation, corner radius, filters,
│   │                               export (PNG/JPEG/clipboard), undo/redo.
│   │                               NSWindowController + SwiftUI NSHostingController.
│   ├── ScreenshotFloatingPreview.swift Floating NSPanel shown immediately after capture.
│   │                               Shows thumbnail + quick actions (Edit / Dismiss).
│   │                               Auto-dismisses after timeout.
│   ├── ScreenshotGalleryView.swift SwiftUI LazyVGrid gallery. Search by filename + OCR text.
│   │                               Used inside NotchlyHub ScreenshotManagerView.
│   ├── ScreenshotActionBar.swift   Dynamic action chips based on ContentType.
│   ├── ScreenshotNamingView.swift  Compact inline naming panel shown inside the notch after
│   │                               capture — lets user name screenshot before saving.
│   └── ScreenshotPreviewPopup.swift Small popup showing screenshot thumbnail.
│                                   Uses VisualEffectView(.hudWindow, .withinWindow) for glass bg.
│
├── UI/
│   ├── NotchlyHubView.swift        Full-window SwiftUI control center (695 lines).
│   │                               Root: ZStack { VisualEffectView + HStack }
│   │                               Sidebar (220pt): nav tabs + Preferences shortcut
│   │                               Tab 1 → NotchControlsView: toggle cards per notch module
│   │                               Tab 2 → ScreenshotManagerView: searchable grid + editor launch
│   │                               Components: ToggleCard, ScreenshotGridCard
│   ├── NotchlyHubWindowController.swift AppKit NSWindowController for Hub.
│   │                               Window: .titled + .closable + .miniaturizable + .resizable
│   │                                       + .fullSizeContentView, minSize 900×620
│   │                               Glass: backgroundColor=.clear, isOpaque=false,
│   │                                      titlebarAppearsTransparent=true
│   │                               IMPORTANT: assigns hostingController directly as contentViewController
│   │                               (VisualEffectView lives in SwiftUI, not AppKit)
│   └── VisualEffectView.swift      NSViewRepresentable wrapping NSVisualEffectView.
│                                   material + blendingMode configurable. state=.active always.
│
├── Settings/
│   └── SettingsView.swift          Native macOS Settings (TabView). Tabs: General,
│                                   Media, Calendar/Notion, Hotkeys, Permissions, About.
│
├── Permissions/
│   ├── PermissionsManager.swift    CGPreflightScreenCaptureAccess, AXIsProcessTrusted checks
│   └── PermissionsOnboarding.swift First-launch SwiftUI permission request flow
│
├── AI/                             (stubs — Sprint 6)
├── Clipboard/                      (stubs — Sprint 3)
├── Notes/                          (stubs — Sprint 5)
├── PiP/                            (stubs — Sprint 4)
├── Utilities/                      (stubs — extensions, logger)
│
└── Resources/
    └── DefaultMusicThumbnail.png   Fallback artwork when no track artwork available
```

---

## Key Architecture Rules

### 1. Window Creation — Always AppKit
```swift
// All windows: NSWindowController or NSPanel created in AppKit
// SwiftUI only provides the rootView — never the window itself

// Notch window — NSPanel .nonactivatingPanel (never steals focus)
// Hub window   — NSWindow .titled + .resizable (normal app window)
// Preview      — NSPanel .nonactivatingPanel (floating, non-activating)
// Settings     — SwiftUI Settings{} scene (AppKit-managed)
```

### 2. Hub Window — Liquid Glass (CRITICAL: avoid zero-frame bug)
```swift
// ❌ BROKEN — visualEffectView.bounds = {0,0,0,0} at init time
let vev = NSVisualEffectView()
hostingController.view.frame = vev.bounds  // 0×0 → invisible window

// ✅ CORRECT — assign hosting controller directly; VisualEffectView lives in SwiftUI
window.contentViewController = hostingController

// In SwiftUI root view:
var body: some View {
    ZStack {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .ignoresSafeArea()          // auto-sizes to fill window frame
        HStack(spacing: 0) { ... }     // content on top
    }
    .frame(minWidth: 900, maxWidth: .infinity, minHeight: 620, maxHeight: .infinity)
    // ^ flexible frame = resizable window + fullscreen support
    // ^ fixed .frame(width:height:) would break resize/fullscreen
}
```

### 3. macOS Full-Row Tap Target (CRITICAL: Button+.plain is broken for text)
```swift
// ❌ BROKEN — Button+.plain only hits rendered pixels (icon area only on macOS)
Button { } label: { HStack { Image(...); Text(...); Spacer() } }
    .buttonStyle(.plain).contentShape(Rectangle())  // Text/Spacer still dead zones

// ✅ CORRECT — ZStack with Color.clear tap layer above visual HStack
ZStack(alignment: .leading) {
    Color.clear
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { /* action */ }     // catches taps everywhere

    HStack { Image(...); Text(...); Spacer() }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .allowsHitTesting(false)           // visual only — no hit testing
}
.fixedSize(horizontal: false, vertical: true)  // CRITICAL: stops rows expanding to fill parent
.frame(maxWidth: .infinity)
```

### 4. Notch Window Positioning
```swift
// NSScreen coords: y=0 is bottom. notch is top-center of main screen.
let screen = NSScreen.main!
let x = (screen.frame.width - windowWidth) / 2
let y = screen.frame.maxY - windowHeight

window.level = .statusBar
window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
window.backgroundColor = .clear
window.isOpaque = false
window.hasShadow = false
// + CGSSpaceOverlay wraps the window in a private space at Int32.max level
// so it stays above macOS Space-switching animations
```

### 5. Music Player — Multi-Source Detection Order
```swift
// 1. Apple Music → DistributedNotificationCenter (com.apple.Music.playerInfo)
//    State comes directly in notification userInfo — no AppleScript needed
// 2. Spotify → DistributedNotificationCenter (com.spotify.client.PlaybackStateChanged)
//    State requires AppleScript query for full detail
// 3. YouTube Music Desktop / TIDAL → HTTP GET http://localhost:9863/query (poll 2s)
//    ⚠️ Console "Connection refused" errors on port 9863 are EXPECTED when YTM/TIDAL
//    not running — silently swallow, never crash or alert

// Artwork: NSImage.extractGradientColors() → two CIAreaAverage colors for glow gradient
// Fallback: iTunes Search API (public, no auth) → DefaultMusicThumbnail.png
```

### 6. Screenshot Pipeline
```swift
// Hotkey capture: CaptureManager → screencapture CLI → temp file
// Desktop capture: ScreenshotMonitor (FSEvents, 0.1s latency) → detects by filename pattern
// Both paths → ScreenshotAnalyzer (Vision OCR + barcode → ContentType)
//           → ScreenshotItem (SwiftData persist)
//           → ScreenshotFloatingPreview (floating NSPanel, auto-dismiss)
//           → NotchState.isShowingScreenshotPopup = true (shows in collapsed notch)
// RULE: Move/save file FIRST, analyze ASYNC — never block the capture pipeline
```

### 7. SettingsManager — Source of Truth for All Preferences
```swift
// All prefs use @AppStorage — persisted to UserDefaults automatically
// Never duplicate preference state elsewhere — always read from SettingsManager.shared
// activeNotchPages computed property derives [NotchPage] from boolean module toggles
// NotchExpandedView reads activeNotchPages to build its tab list
```

---

## Data Model

```swift
// SwiftData — only ScreenshotItem is persisted to SwiftData
@Model class ScreenshotItem {
    @Attribute(.unique) var id: UUID
    var filename: String
    var filePath: String          // absolute path in app storage
    var capturedAt: Date
    var contentType: String       // ContentType.rawValue
    var extractedText: String?    // Vision OCR result
    var isFavorited: Bool
    var cornerRadius: Double      // default 12, editable in editor
    var rotation: Double          // default 0, editable in editor
}

// ContentType enum (in ScreenshotAnalyzer.swift)
enum ContentType: String, Codable {
    case photo, textDocument, uiScreenshot, receipt, codeSnippet, qrCode, snippet, unknown
}

// In-memory only (SettingsManager @AppStorage)
struct CustomTimer: Identifiable, Codable, Equatable { id, name, minutes, seconds }
struct DockApp: Identifiable, Codable, Equatable { name, bundleId, path }
```

---

## NotchState — Runtime State Machine

```swift
// NotchState.shared — drives all notch UI transitions
class NotchState: ObservableObject {
    var isExpanded: Bool               // notch expanded/collapsed
    var isHovering: Bool               // mouse over notch area
    var stickyType: StickyType         // .none / .timer / .media
    var isSticky: Bool                 // stays expanded without hover
    var selectedPage: NotchPage        // current tab in expanded view
    var lastCapturedScreenshotURL: URL?
    var pendingScreenshotURL: URL?
    var isShowingScreenshotPopup: Bool // shows thumbnail in collapsed notch
}

enum NotchPage: String, CaseIterable {
    case media, timer, system, calendar, launcher, screenshots
}
```

---

## Sprint Status — May 2026

### ✅ Sprint 1 — Foundation (COMPLETE)
```
NotchWindowController + CGSSpaceOverlay (stays above all Spaces)
NotchOverlayView + NotchExpandedView (hover expand/collapse, spring animation)
NotchState, AppDelegate, NotchAppApp
All 6 notch modules: MediaPlayer, Timer, SystemMonitor, Calendar, Launcher, Screenshots
```

### ✅ Sprint 2 — Screenshot Intelligence (COMPLETE)
```
ScreenshotMonitor (FSEvents), CaptureManager (global hotkeys via KeyboardShortcuts)
ScreenshotAnalyzer (Vision OCR + ContentType classification)
ScreenshotEditorWindow (full pixel-perfect editor, 3267 lines)
ScreenshotFloatingPreview, ScreenshotActionBar, ScreenshotNamingView
ScreenshotGalleryView, ScreenshotPreviewPopup
ScreenshotItem (SwiftData @Model with cornerRadius + rotation for editor)
```

### ✅ Sprint 2.5 — Notchly Hub (COMPLETE)
```
NotchlyHubView (695 lines) — Liquid Glass full-window control center
NotchlyHubWindowController — correct AppKit/SwiftUI hybrid pattern
VisualEffectView — NSViewRepresentable for SwiftUI glass backgrounds
ToggleCard — per-module notch toggle with glass card design
ScreenshotGridCard + ScreenshotManagerView — gallery in Hub
Fixed: full-row sidebar tap (ZStack+Color.clear), window resize/fullscreen,
       row height expansion (.fixedSize), Hub invisible bug (zero-frame)
```

### 🚀 Sprint 3 — Clipboard Intelligence (NEXT UP)
```
ClipboardMonitor.swift   — Timer 0.5s, NSPasteboard.changeCount, max 500 items
ClipboardItem.swift      — SwiftData model (content, type, copiedAt, appSource, isPinned)
ClipboardCategorizer.swift — URL/email/phone/hex/OTP/code detection via regex + NL
ClipboardHistoryView.swift — list by date, pin, swipe-to-delete, tap-to-recopy
ClipboardSearch.swift    — search clipboard content + screenshot OCR text
```

### Sprint 4 — PiP Windows
```
PermissionsManager + PermissionsOnboarding (screen recording, accessibility)
WindowCaptureSession (ScreenCaptureKit SCStream per window)
PiPOverlayWindow (NSPanel .floating, isMovableByWindowBackground, snap-to-corner)
PiPControlsView + PiPWindowManager (N simultaneous windows)
```

### Sprint 5 — Notes, Hotkeys, Full Settings
```
QuickNoteView, StickyNoteWindow, NotesStorage (SwiftData QuickNote model)
HotkeyManager (Cmd+Shift+N/V/S via KeyboardShortcuts)
Full SettingsView: AI key (Keychain), hotkeys tab, permissions tab
```

### Sprint 6 — Cloud AI + Polish
```
ClaudeAPIClient — POST /v1/messages, claude-sonnet-4-6, base64 image, Keychain key
Wire Claude into screenshot (summarize/explain/translate/receipt) + clipboard
BackgroundRemover — Core ML RMBG-1.4 model
Sparkle auto-update — SUUpdater in AppDelegate, SUFeedURL in Info.plist
```

---

## Common Mistakes — Never Do These

| Mistake | Correct Approach |
|---------|-----------------|
| `Button+.buttonStyle(.plain)` for full-row taps on macOS | ZStack + Color.clear + onTapGesture pattern |
| `visualEffectView.frame = visualEffectView.bounds` at init | bounds=0×0 at init — put VisualEffectView in SwiftUI instead |
| Fixed `.frame(width:height:)` on root SwiftUI view of resizable window | Use `frame(minWidth:maxWidth:minHeight:maxHeight:)` |
| `maxHeight:.infinity` on Color.clear inside ZStack in VStack | Add `.fixedSize(horizontal:false, vertical:true)` to ZStack |
| Creating windows in SwiftUI | All windows via NSWindowController/NSPanel in AppKit |
| Enabling App Sandbox | Must be OFF — FSEvents, notch positioning, clipboard require no sandbox |
| Hardcoding API key | Store in Keychain via Security framework |
| Calling Claude API on MainActor | Background Task{}, then await MainActor.run{} for UI |
| Crashing on localhost:9863 connection refused | Expected when YTM/TIDAL not running — silently ignore |
| Forgetting `canJoinAllSpaces` on notch window | Must follow user across all Spaces |
| Polling NSPasteboard with push notifications | NSPasteboard has no push — poll Timer every 0.5s |
| Blocking screenshot move for Vision analysis | Move file FIRST, analyze ASYNC |
| Using UserDefaults directly for preferences | Use SettingsManager @AppStorage properties |
| Adding new preference state outside SettingsManager | Single source of truth — always SettingsManager |
| Using NSVisualEffectView directly in SwiftUI | Use VisualEffectView.swift NSViewRepresentable wrapper |

---

## Build & Verify

```bash
xcodebuild -project NotchApp.xcodeproj -scheme NotchApp -configuration Debug build

# ✅ Expected: ** BUILD SUCCEEDED **
# ℹ️  Ignore: "Metadata extraction skipped. No AppIntents.framework" (harmless)
# ℹ️  Ignore: localhost:9863 "Connection refused" at runtime (YTM/TIDAL not running)
# ℹ️  Ignore: FSFindFolder error=-43 (deprecated macOS API, harmless)
```

---

## Distribution Target

Direct distribution (NOT App Store):
- Apple Developer ID certificate
- Notarization via `notarytool`
- Sparkle for auto-updates (Sprint 6)
- Hosted on GitHub Releases

# DESIGN.md — NotchApp UI & Visual Design Guide

> Apple macOS Tahoe 26 + Liquid Glass design standards.
> Claude Code must read this alongside CLAUDE.md before writing any UI code.

---

## Design Philosophy

This app lives at the very top of the screen, overlaying the notch. It must feel like
it belongs to macOS itself — not like a third-party app slapped on top. The guiding
principle is: **invisible until needed, delightful when present.**

Three words to design every screen against:
- **Weightless** — nothing feels heavy or intrusive
- **Intelligent** — UI reacts to content, not just user input
- **Native** — indistinguishable from a first-party Apple experience

---

## Apple Design Language: Liquid Glass (macOS Tahoe 26)

This app targets macOS 14+ but should adopt Liquid Glass aesthetics fully.
Liquid Glass is Apple's biggest design evolution since iOS 7, introduced at WWDC 2025.

### What Liquid Glass Is
- A translucent digital meta-material that **bends and refracts light** (not just blurs it)
- Creates real depth and hierarchy between content and controls
- Adapts dynamically to whatever is behind it — light, dark, colorful backgrounds
- Makes UI feel like frosted glass floating above content

### The Golden Rule
```
Liquid Glass = Navigation layer ONLY
Content = Always flat, never glass
```

Glass floats ABOVE content. Content sits BELOW glass. Never mix.

### What Gets Glass in This App
```
✅ Glass:                          ❌ Never Glass:
- Notch expanded panel             - Screenshot thumbnails
- Floating action buttons          - Clipboard list items
- PiP window controls overlay      - Note text content
- Tab bar inside notch             - Gallery grid cards
- Hover tooltip chips              - Settings form rows
- Quick action buttons             - Search results
```

---

## SwiftUI Implementation — Liquid Glass

### Basic Glass Effect
```swift
// Floating action button — use .glassEffect()
Button("Copy Text") { }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .glassEffect(.regular.interactive())

// Panel background — use .ultraThinMaterial
RoundedRectangle(cornerRadius: 20)
    .fill(.ultraThinMaterial)
```

### Always Wrap Multiple Glass Elements in GlassEffectContainer
```swift
// ✅ CORRECT — shared sampling, consistent appearance, better performance
GlassEffectContainer(spacing: 24) {
    HStack(spacing: 12) {
        ActionButton(label: "Copy", icon: "doc.on.doc")
            .glassEffect(.regular.interactive())
        ActionButton(label: "Share", icon: "square.and.arrow.up")
            .glassEffect(.regular.interactive())
        ActionButton(label: "Summarize", icon: "text.quote")
            .glassEffect(.regular.interactive())
    }
}

// ❌ WRONG — never stack glass without container
VStack {
    HeaderView().glassEffect()
    ContentView().glassEffect()  // Glass on glass = broken
}
```

### Morphing Glass (Notch Expand Animation)
```swift
// Use glassEffectID for fluid shape transitions
struct NotchOverlayView: View {
    @State private var isExpanded = false
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer {
            if isExpanded {
                ExpandedPanelView()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                    .glassEffectID("notchPanel", in: glassNamespace)
            } else {
                CollapsedNotchView()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                    .glassEffectID("notchPanel", in: glassNamespace)
            }
        }
    }
}
```

### Materials Hierarchy (Use in This Order)
```swift
.ultraThinMaterial    // Notch panel background — most transparent
.thinMaterial         // PiP window background
.regularMaterial      // Popover, sheet backgrounds
.thickMaterial        // Settings window sidebar
.ultraThickMaterial   // Modal overlays — most opaque
```

---

## Colors

### Never Hardcode Colors — Always Use Semantic Colors
```swift
// ✅ CORRECT — adapts to light/dark mode automatically
Color.primary           // Main text
Color.secondary         // Secondary text, labels
Color.tertiaryLabel     // Placeholder, hints
Color.separator         // Dividers
Color.background        // Base backgrounds (avoid — use materials instead)
Color.secondaryBackground

// System accent
Color.accentColor       // Buttons, interactive elements

// Semantic status colors
Color.green             // Success, saved, active
Color.orange            // Warning, processing
Color.red               // Error, delete
Color.blue              // Links, selected state
```

### Content Type Colors — Clipboard + Screenshot Badge Tints
```swift
// Each content type gets a tinted glass badge — subtle, not loud
extension ContentType {
    var tintColor: Color {
        switch self {
        case .codeSnippet:   return .purple
        case .receipt:       return .green
        case .textDocument:  return .blue
        case .photo:         return .orange
        case .qrCode:        return .indigo
        case .uiScreenshot:  return .teal
        case .table:         return .cyan
        case .mixed:         return .secondary
        }
    }

    var iconName: String {
        switch self {
        case .codeSnippet:   return "chevron.left.forwardslash.chevron.right"
        case .receipt:       return "receipt"
        case .textDocument:  return "doc.text"
        case .photo:         return "photo"
        case .qrCode:        return "qrcode"
        case .uiScreenshot:  return "macwindow"
        case .table:         return "tablecells"
        case .mixed:         return "square.grid.2x2"
        }
    }
}
```

### Dark Mode
- This app must look **better** in dark mode — it lives at the top of the screen near the black notch
- The notch panel should feel like an extension of the physical black notch
- Use `.ultraThinMaterial` with black tint for the collapsed notch base
- In light mode, the expanded panel uses vibrancy to pick up the desktop wallpaper color

---

## Typography — SF Pro Only

```swift
// Title — expanded notch section headers
.font(.system(size: 13, weight: .semibold, design: .rounded))

// Body — clipboard item text, note content
.font(.system(size: 13, weight: .regular))

// Caption — timestamps, app source labels, badge text
.font(.system(size: 11, weight: .medium))
.foregroundStyle(.secondary)

// Monospace — code snippets, OTPs, hex colors
.font(.system(size: 12, weight: .regular, design: .monospaced))

// Large title — empty state headings
.font(.system(size: 20, weight: .semibold, design: .rounded))
```

### Typography Rules
- **Never** use fonts below 11pt — accessibility minimum
- **Always** support Dynamic Type where possible
- Code content → always `.monospaced` design
- OTPs → always `.monospaced`, extra letter-spacing
- Timestamps → always `.secondary` foreground, 11pt

---

## Spacing & Layout

### The 4pt Grid System
All spacing is multiples of 4:
```
4pt   — micro gaps, icon-to-label spacing
8pt   — tight padding inside chips/badges
12pt  — standard inner padding
16pt  — panel content padding
20pt  — section spacing
24pt  — major section gaps
32pt  — between large groups
```

### Notch Panel Dimensions
```
Collapsed height:   37pt  (matches physical notch)
Collapsed width:    200pt (centered over notch)
Expanded height:    300pt (smooth spring to this)
Expanded width:     380pt (expands outward symmetrically)
Panel corner radius: 20pt (expanded) / 0pt (collapsed, flush with notch)
Content padding:    16pt all sides
```

### PiP Window Dimensions
```
Default size:       400 x 280pt
Minimum size:       240 x 160pt
Maximum size:       800 x 600pt
Corner radius:      12pt
Control bar height: 36pt (shown on hover)
Snap margin:        16pt from screen edges
```

### Screenshot Gallery
```
Columns:            3 (fixed)
Thumbnail size:     120 x 90pt
Grid spacing:       8pt
Corner radius:      8pt
```

### Clipboard History Row
```
Row height:         52pt
Icon size:          28 x 28pt (rounded square, 6pt radius)
Icon-text gap:      10pt
Text max lines:     2 (truncated with ellipsis)
Timestamp:          trailing, 11pt secondary
```

---

## Corner Radius System

```swift
// Consistent radius tokens — use these, never arbitrary values
enum Radius {
    static let chip:    CGFloat = 8    // Action buttons, badges
    static let card:    CGFloat = 12   // PiP window, gallery thumbnails
    static let panel:   CGFloat = 16   // Popovers, settings sections
    static let notch:   CGFloat = 20   // Expanded notch panel
    static let sheet:   CGFloat = 24   // Bottom sheets, modal panels
}
```

---

## Animation System

### Spring Physics — Use These Constants Everywhere
```swift
// Notch expand/collapse — primary animation
.animation(
    .spring(response: 0.35, dampingFraction: 0.80),
    value: isExpanded
)

// Action button hover — subtle lift
.animation(
    .spring(response: 0.25, dampingFraction: 0.75),
    value: isHovered
)

// PiP snap-to-corner
.animation(
    .spring(response: 0.30, dampingFraction: 0.85),
    value: cornerPosition
)

// Content appear transitions
.animation(
    .spring(response: 0.40, dampingFraction: 0.90),
    value: isVisible
)
```

### Transition Patterns
```swift
// Notch content appearing
.transition(
    .opacity
    .combined(with: .scale(scale: 0.95, anchor: .top))
)

// List item insert
.transition(.asymmetric(
    insertion: .push(from: .top).combined(with: .opacity),
    removal: .push(from: .bottom).combined(with: .opacity)
))

// Action bar slide up
.transition(
    .move(edge: .bottom)
    .combined(with: .opacity)
)
```

### What NOT to Do With Animation
```swift
// ❌ Never use .easeInOut for notch interactions — feels mechanical
.animation(.easeInOut(duration: 0.3), value: isExpanded)

// ❌ Never animate layout changes without spring
withAnimation(.linear) { ... }

// ✅ Always spring, always
withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { ... }
```

---

## Iconography — SF Symbols Only

Never use custom icons where an SF Symbol exists. SF Symbols automatically match
system weight, scale, and adapt to color.

```swift
// Always use hierarchical or palette rendering for colored icons
Image(systemName: "doc.on.doc")
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(Color.accentColor)

// For content type icons — use palette rendering with tint
Image(systemName: contentType.iconName)
    .symbolRenderingMode(.palette)
    .foregroundStyle(contentType.tintColor, contentType.tintColor.opacity(0.2))
```

### Key Icons Used in This App
```
Screenshots:     photo.on.rectangle.angled
Clipboard:       clipboard
Notes:           note.text
PiP:             pip
Code:            chevron.left.forwardslash.chevron.right
Receipt:         receipt
QR Code:         qrcode.viewfinder
Copy:            doc.on.doc
Share:           square.and.arrow.up
Delete:          trash
Pin:             pin
Favorite:        heart
Search:          magnifyingglass
Settings:        gearshape
AI/Summarize:    text.quote
Translate:       globe
Background remove: person.crop.rectangle
Explain:         lightbulb
```

### Symbol Weight
```swift
// Match symbol weight to context
.font(.system(size: 14, weight: .medium))  // Action buttons
.font(.system(size: 12, weight: .regular)) // List icons
.font(.system(size: 16, weight: .semibold)) // Tab bar icons
```

---

## Component Design Specs

### Action Button (ScreenshotActionBar)
```swift
struct ActionButton: View {
    let label: String
    let icon: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 12, weight: .medium))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular.interactive())
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
// Wrap multiple ActionButtons in GlassEffectContainer
```

### Clipboard Row
```swift
struct ClipboardRow: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 10) {
            // Type icon badge
            RoundedRectangle(cornerRadius: 6)
                .fill(item.contentType.tintColor.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: item.contentType.iconName)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(item.contentType.tintColor)
                        .font(.system(size: 13, weight: .medium))
                )

            // Content preview
            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewText)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(item.relativeTime)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Pin indicator (if pinned)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
```

### Screenshot Thumbnail
```swift
struct ScreenshotThumbnail: View {
    let item: ScreenshotItem
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            AsyncImage(url: item.imageURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(width: 120, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Content type badge (bottom left)
            Image(systemName: item.contentTypeEnum.iconName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(4)
                .background(item.contentTypeEnum.tintColor, in: RoundedRectangle(cornerRadius: 4))
                .padding(5)
                .opacity(isHovered ? 1 : 0.7)
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 8 : 4)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
```

### Tab Bar (Inside Notch Panel)
```swift
// Compact pill-style tab selector
struct NotchTabBar: View {
    @Binding var selectedTab: NotchTab
    @Namespace private var tabNamespace

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(NotchTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                            Text(tab.label)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .frame(width: 72, height: 40)
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        selectedTab == tab ? .regular.interactive() : .regular,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .glassEffectID(tab.id, in: tabNamespace)
                }
            }
        }
    }
}
```

### Empty State
```swift
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.quaternary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
```

---

## Notch Panel — Visual Layers

```
Layer 0 (bottom): Desktop wallpaper / whatever is on screen
Layer 1:          .ultraThinMaterial panel background — picks up wallpaper color
Layer 2:          Content (list, gallery, text — NO glass here)
Layer 3 (top):    Glass controls — tab bar, action buttons, search
```

The panel itself should look like a frosted island floating at the top of the screen,
with the physical notch seamlessly blending into its top edge.

### Notch Collapsed State
```swift
// Matches physical notch exactly
RoundedRectangle(cornerRadius: 0)
    .fill(Color.black)
    .frame(width: 200, height: 37)
    // No shadow, no border — must look like the real notch
```

### Notch Expanded State
```swift
ZStack(alignment: .top) {
    // Frosted glass background
    RoundedRectangle(cornerRadius: 20)
        .fill(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)

    // Subtle border to catch light
    RoundedRectangle(cornerRadius: 20)
        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)

    // Content
    VStack(spacing: 0) {
        // Notch cutout (black, top)
        Color.black.frame(height: 37)

        // Tab bar + content
        NotchExpandedView()
            .padding(.top, 8)
    }
}
```

---

## PiP Window Design

```swift
// Always on top, always clean
// Controls fade in on hover, fade out after 2 seconds

struct PiPWindowLayout: View {
    @State private var showControls = false

    var body: some View {
        ZStack {
            // Live window content
            LiveWindowView()
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Control overlay — only on hover
            if showControls {
                VStack {
                    Spacer()
                    // Bottom control bar
                    GlassEffectContainer {
                        HStack(spacing: 8) {
                            PiPControlButton(icon: "minus.circle")
                            Slider(value: $opacity, in: 0.3...1.0)
                                .frame(width: 80)
                            PiPControlButton(icon: "xmark.circle")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular)
                    }
                    .padding(8)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                showControls = hovering
            }
        }
    }
}
```

---

## Settings Window

Follow native macOS Settings style exactly:
- Use `Settings {}` scene in SwiftUI
- `TabView` with SF Symbol icons for each tab
- Form-based layout with `Section` groupings
- No custom backgrounds — let macOS handle it
- Sidebar style on macOS 13+ (`.tabViewStyle(.sidebarAdaptable)`)

```swift
Settings {
    TabView {
        GeneralSettingsView()
            .tabItem { Label("General", systemImage: "gearshape") }

        AISettingsView()
            .tabItem { Label("AI", systemImage: "sparkles") }

        HotkeysSettingsView()
            .tabItem { Label("Shortcuts", systemImage: "keyboard") }

        PermissionsSettingsView()
            .tabItem { Label("Permissions", systemImage: "lock.shield") }

        AboutView()
            .tabItem { Label("About", systemImage: "info.circle") }
    }
    .frame(width: 520, height: 400)
}
```

---

## Accessibility

```swift
// Every interactive element must have:
Button("Copy Text") { }
    .accessibilityLabel("Copy extracted text to clipboard")
    .accessibilityHint("Double-click to copy")

// Images must have descriptions
Image(systemName: "photo")
    .accessibilityLabel("Screenshot thumbnail")
    .accessibilityHidden(false)

// Support Reduce Motion
@Environment(\.accessibilityReduceMotion) var reduceMotion

var animation: Animation {
    reduceMotion
        ? .easeInOut(duration: 0.1)
        : .spring(response: 0.35, dampingFraction: 0.8)
}

// Support Increase Contrast
@Environment(\.colorSchemeContrast) var contrast
// When .increased: use .primary instead of .secondary for important text
```

---

## What NOT to Do — Anti-Patterns

| ❌ Don't | ✅ Do Instead |
|----------|--------------|
| Hardcode colors (`Color(hex: "#1C1C1E")`) | Use semantic colors (`Color.primary`) |
| Use custom fonts | SF Pro only — `.system(size:weight:design:)` |
| Stack glass on glass | Use `GlassEffectContainer` |
| Apply `.glassEffect()` to list content | Glass on navigation layer only |
| Use arbitrary corner radii | Use the `Radius` token enum |
| Animate with `.easeInOut` | Always use `.spring()` |
| Show all actions at once | Prioritize top 4, scroll for more |
| Use `NSVisualEffectView` directly in SwiftUI | Use `.ultraThinMaterial` modifier |
| Make PiP window activating | `.nonactivatingPanel` only — never steal focus |
| Custom alert dialogs | Native SwiftUI `.alert()` modifier |
| Fixed window sizes in Settings | `frame(minWidth:maxWidth:)` with flexibility |

---

## Checklist — Before Any UI PR

- [ ] Does it use semantic colors (not hardcoded hex)?
- [ ] Is glass ONLY on navigation/floating elements?
- [ ] Are multiple glass buttons inside `GlassEffectContainer`?
- [ ] Do all animations use `.spring()` physics?
- [ ] Are SF Symbols used with `.hierarchical` or `.palette` rendering?
- [ ] Does it look good in both light and dark mode?
- [ ] Does it respect `accessibilityReduceMotion`?
- [ ] Are all interactive elements labeled for VoiceOver?
- [ ] Is spacing on the 4pt grid?
- [ ] Does the notch panel feel like it belongs to the OS?

---

*Follow Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/*
*Liquid Glass reference: https://developer.apple.com/design/whats-new/*

---

## Notchly Hub Window — Implemented Design (May 2026)

The Hub is a resizable full-size window (default 1100×700) with Apple Liquid Glass aesthetics.

### Window Layering
```
Layer 0: Desktop wallpaper (blurred + sampled through NSVisualEffectView)
Layer 1: NSVisualEffectView .hudWindow material — root glass layer (full window)
Layer 2: Sidebar (220pt wide) — Color.black.opacity(0.18) dark glass overlay
Layer 3: Main content — Color.clear (glass shows through)
Layer 4: Cards, toggles, thumbnails — subtle white-opacity fills on glass
```

### Sidebar Design
```swift
VStack { ... }
    .frame(width: 220)
    .background(Color.black.opacity(0.18))   // dark tint over glass
    .overlay(
        HStack {
            Spacer()
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1)             // hairline divider, right edge
        }
    )
```

### Nav Row Design (Full-Row Clickable)
```swift
// IMPORTANT: Use ZStack + Color.clear pattern — not Button — for macOS full-row taps
ZStack(alignment: .leading) {
    Color.clear
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { currentTab = tab }

    HStack(spacing: 12) {
        Image(systemName: tab.icon)
            .font(.system(size: 14, weight: .bold))
            .frame(width: 20)
            .foregroundColor(currentTab == tab ? .white : .white.opacity(0.5))
        Text(tab.rawValue)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(currentTab == tab ? .white : .white.opacity(0.7))
            .lineLimit(1)
        Spacer()
        if currentTab == tab {
            Circle().fill(Color.blue).frame(width: 5, height: 5)
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .allowsHitTesting(false)
}
.fixedSize(horizontal: false, vertical: true)   // ← critical: prevents row height expansion
.frame(maxWidth: .infinity)
.background(
    RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(isActive ? Color.white.opacity(0.08) : Color.clear)
)
```

### Toggle Card Design (ToggleCard)
```swift
// Glass card — monochrome, no neon borders
VStack(alignment: .leading, spacing: 14) {
    HStack(alignment: .top) {
        // Icon badge — tinted glass square
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(iconColor.opacity(0.09))
                .frame(width: 38, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(iconColor.opacity(0.15), lineWidth: 1)
                )
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
        }
        Spacer()
        Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden().controlSize(.small)
    }
    VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.white)
        Text(subtitle).font(.system(size: 11)).foregroundColor(.white.opacity(0.45)).lineLimit(2)
    }
}
.padding(20)
.background(RoundedRectangle(cornerRadius: 14).fill(cardBackground))
.overlay(RoundedRectangle(cornerRadius: 14).stroke(cardBorderColor, lineWidth: 1))
.shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)

// State-driven computed properties (avoid inline ternaries for compiler performance):
private var cardBackground: Color {
    isHovered ? Color.white.opacity(0.06) : isOn ? Color.white.opacity(0.04) : Color.white.opacity(0.015)
}
private var cardBorderColor: Color {
    isHovered ? Color.white.opacity(0.18) : isOn ? Color.white.opacity(0.12) : Color.white.opacity(0.06)
}
```

### Screenshot Grid Card Design
```swift
// Permanent glass backing — not just on hover
.background(
    RoundedRectangle(cornerRadius: 12)
        .fill(isHovered ? Color.white.opacity(0.04) : Color.white.opacity(0.015))
)
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(isHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.06), lineWidth: 1)
)
.shadow(color: Color.black.opacity(isHovered ? 0.16 : 0.08), radius: isHovered ? 10 : 4, x: 0, y: isHovered ? 5 : 2)
```

### Hub Anti-Patterns
```
❌ Never use NSVisualEffectView manually in AppKit before SwiftUI layout runs
   (bounds = 0×0 at init → hosting view gets zero frame → invisible window)
❌ Never use Button+.buttonStyle(.plain) for full-row taps in macOS sidebar
   (only icon pixels respond, text and spacer areas are dead zones)
❌ Never use maxHeight: .infinity on Color.clear inside a ZStack in a VStack
   (causes rows to expand and fill entire available height)
❌ Never use fixed .frame(width:height:) on the root SwiftUI view of a resizable window
   (prevents resize and fullscreen — use minWidth/maxWidth instead)
❌ Never stack neon/saturated borders on module cards
   (use unified white-opacity borders for professional glass aesthetics)
```


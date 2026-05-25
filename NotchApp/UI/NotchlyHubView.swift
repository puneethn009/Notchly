import SwiftUI
import SwiftData

struct NotchlyHubView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var settings = SettingsManager.shared
    @Query(sort: \ScreenshotItem.capturedAt, order: .reverse) private var items: [ScreenshotItem]
    
    @State private var currentTab: HubTab = .notchControls
    @State private var searchText: String = ""
    @State private var hoverTab: HubTab? = nil
    
    enum HubTab: String, CaseIterable, Identifiable {
        case notchControls = "Notch Controls"
        case screenshotManager = "Screenshot Manager"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .notchControls: return "app.badge"
            case .screenshotManager: return "square.grid.2x2.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Root glass layer — auto-sizes to full window, no 0×0 bug
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
        HStack(spacing: 0) {
            // SIDEBAR
            VStack(alignment: .leading, spacing: 0) {
                // Header Brand Logo
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: -2) {
                        Text("Notchly")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("STUDIO HUB")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(1.5)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)
                .padding(.bottom, 30)
                
                // Navigation Options
                VStack(spacing: 4) {
                    ForEach(HubTab.allCases) { tab in
                        ZStack(alignment: .leading) {
                            // Tap target — fixed 44pt height, full width
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        currentTab = tab
                                    }
                                }
                            
                            // Visual row — drives ZStack height
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
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 5, height: 5)
                                        .shadow(color: Color.blue.opacity(0.6), radius: 3)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                        }
                        .fixedSize(horizontal: false, vertical: true) // height driven by content, never expands
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(currentTab == tab ? Color.white.opacity(0.08) : (hoverTab == tab ? Color.white.opacity(0.03) : Color.clear))
                        )
                        .onHover { isHovered in
                            hoverTab = isHovered ? tab : nil
                        }
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                // BOTTOM PREFERENCES SHORTCUT
                VStack(spacing: 8) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    
                    Button(action: {
                        AppDelegate.shared?.openSettings(nil)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Preferences…")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .frame(width: 220)
            .background(Color.black.opacity(0.18))
            .overlay(
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                }
            )
            
            // MAIN DETAIL VIEW
            ZStack {
                Color.clear
                    .ignoresSafeArea()
                
                // Subtle liquid glass metallic flare
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.blue.opacity(0.03))
                            .frame(width: 600, height: 600)
                            .blur(radius: 150)
                            .offset(x: -180, y: -180)
                        Spacer()
                    }
                    Spacer()
                }
                .ignoresSafeArea()
                
                switch currentTab {
                case .notchControls:
                    NotchControlsView(settings: settings)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                case .screenshotManager:
                    ScreenshotManagerView(items: items, searchText: $searchText, onSelect: { url in
                        ScreenshotEditorWindowController.shared.open(with: url)
                    }, onDelete: { item in
                        deleteScreenshotItem(item)
                    })
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        } // end ZStack
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 620, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenScreenshotManager"))) { _ in
            currentTab = .screenshotManager
        }
    }


    
    private func deleteScreenshotItem(_ item: ScreenshotItem) {
        NSWorkspace.shared.recycle([URL(fileURLWithPath: item.filePath)]) { _, _ in
            DispatchQueue.main.async {
                modelContext.delete(item)
                try? modelContext.save()
            }
        }
    }
}

// MARK: - NOTCH CONTROLS PANEL
struct NotchControlsView: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notch Modules")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Customize exactly which sections are active and interactive inside your screen's notch.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // NOTCH OVERVIEW MOCKUP
                VStack(spacing: 0) {
                    // Laptop Top Bezel
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.03))
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                        
                        // Active modules indicator lights in mock notch
                        VStack(spacing: 8) {
                            // Mock Notch itself
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.black)
                                    .frame(width: 260, height: 35)
                                
                                HStack(spacing: 16) {
                                    if settings.showNotchMusic {
                                        Image(systemName: "music.note")
                                            .foregroundColor(.pink)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    if settings.showNotchTimer {
                                        Image(systemName: "timer")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    if settings.showNotchSystem {
                                        Image(systemName: "cpu")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    if settings.showNotchCalendar {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.green)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    if settings.showNotchLauncher {
                                        Image(systemName: "square.grid.2x2")
                                            .foregroundColor(.purple)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    if settings.showNotchScreenshots {
                                        Image(systemName: "camera.viewfinder")
                                            .foregroundColor(.cyan)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    if settings.showNotchGame {
                                        Image(systemName: "gamecontroller")
                                            .foregroundColor(Color(hue: 0.07, saturation: 0.88, brightness: 1.0))
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                }
                            }
                            
                            Text("Mock Dynamic Live Notch Status")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.top, 10)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.bottom, 10)
                
                // TOGGLES GRID
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                    ToggleCard(
                        title: "Music Player",
                        subtitle: "Control Apple Music / Spotify with media keys & live artwork",
                        icon: "music.note",
                        iconColor: .pink,
                        isOn: $settings.showNotchMusic
                    )
                    
                    ToggleCard(
                        title: "Timer & Stopwatch",
                        subtitle: "Manage countdown alarms & stopwatch directly under the notch",
                        icon: "timer",
                        iconColor: .orange,
                        isOn: $settings.showNotchTimer
                    )
                    
                    ToggleCard(
                        title: "System Monitor",
                        subtitle: "View real-time CPU, RAM, Disk, and Network speeds",
                        icon: "cpu",
                        iconColor: .blue,
                        isOn: $settings.showNotchSystem
                    )
                    
                    ToggleCard(
                        title: "Event Calendar",
                        subtitle: "Sync with your Apple Calendar for upcoming schedule info",
                        icon: "calendar",
                        iconColor: .green,
                        isOn: $settings.showNotchCalendar
                    )
                    
                    ToggleCard(
                        title: "Quick App Launcher",
                        subtitle: "A personalized mini-dock for high-speed app launches",
                        icon: "square.grid.2x2",
                        iconColor: .purple,
                        isOn: $settings.showNotchLauncher
                    )
                    
                    ToggleCard(
                        title: "Screenshot Manager",
                        subtitle: "Browse captured screenshots history in the notch",
                        icon: "camera.viewfinder",
                        iconColor: .cyan,
                        isOn: $settings.showNotchScreenshots
                    )

                    ToggleCard(
                        title: "Notch Breaker",
                        subtitle: "A retro Breakout game — move your mouse to control the paddle",
                        icon: "gamecontroller",
                        iconColor: Color(hue: 0.07, saturation: 0.88, brightness: 1.0),
                        isOn: $settings.showNotchGame
                    )
                }
            }
            .padding(.top, 52)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - TOGGLE CARD COMPONENT
struct ToggleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool
    
    @State private var isHovered: Bool = false
    
    private var cardBackground: Color {
        if isHovered {
            return Color.white.opacity(0.06)
        } else if isOn {
            return Color.white.opacity(0.04)
        } else {
            return Color.white.opacity(0.015)
        }
    }
    
    private var cardBorderColor: Color {
        if isHovered {
            return Color.white.opacity(0.18)
        } else if isOn {
            return Color.white.opacity(0.12)
        } else {
            return Color.white.opacity(0.06)
        }
    }
    
    private var shadowOpacity: Double {
        isHovered ? 0.22 : 0.12
    }
    
    private var shadowRadius: CGFloat {
        isHovered ? 12 : 6
    }
    
    private var shadowY: CGFloat {
        isHovered ? 6 : 3
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                // Elegant glass-like circle wrapper for icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.09))
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(iconColor.opacity(0.15), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Spacer()
                
                // Dynamic Toggle
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
                    .frame(height: 32, alignment: .topLeading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
        .scaleEffect(isHovered ? 1.012 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
        .onHover { hover in
            isHovered = hover
        }
    }
}

// MARK: - SCREENSHOT MANAGER PANEL
struct ScreenshotManagerView: View {
    let items: [ScreenshotItem]
    @Binding var searchText: String
    let onSelect: (URL) -> Void
    let onDelete: (ScreenshotItem) -> Void
    
    var filteredItems: [ScreenshotItem] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { item in
                item.filename.localizedCaseInsensitiveContains(searchText) ||
                (item.extractedText?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                item.contentType.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // TOP BAR WITH SEARCH
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Screenshot Studio")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("View and select screenshots to edit in the pixel-perfect canvas.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Search Input Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.4))
                    
                    TextField("Search file name or OCR text...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .frame(width: 320)
            }
            .padding(.horizontal, 40)
            .padding(.top, 52)
            .padding(.bottom, 20)
            
            // MAIN GRID CONTENT
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.12))
                    
                    Text(searchText.isEmpty ? "No Screenshots Saved" : "No Matches Found")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(searchText.isEmpty ? "Captured screenshots will show up here automatically." : "Try clearing your query or typing something else.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)
                    ], spacing: 20) {
                        ForEach(filteredItems) { item in
                            ScreenshotGridCard(item: item, onSelect: onSelect, onDelete: onDelete)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - SCREENSHOT GRID CARD
struct ScreenshotGridCard: View {
    let item: ScreenshotItem
    let onSelect: (URL) -> Void
    let onDelete: (ScreenshotItem) -> Void
    
    @State private var isHovered: Bool = false
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: item.capturedAt)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail container
            ZStack(alignment: .topTrailing) {
                if let image = NSImage(contentsOfFile: item.filePath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 190, height: 120)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 190, height: 120)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.1))
                        )
                }
                
                // Actions layer on hover
                if isHovered {
                    VStack {
                        HStack {
                            // Category Icon
                            Image(systemName: iconForType(item.contentType))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.black.opacity(0.75).clipShape(Circle()))
                            
                            Spacer()
                            
                            // Delete Button
                            Button(action: {
                                onDelete(item)
                            }) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.red.opacity(0.85).clipShape(Circle()))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                        
                        // Edit Overlay Button
                        Button(action: {
                            onSelect(URL(fileURLWithPath: item.filePath))
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.pencil")
                                Text("Edit Image")
                            }
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.clipShape(Capsule()))
                            .shadow(radius: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .frame(width: 190, height: 120)
                    .background(Color.black.opacity(0.4).cornerRadius(8))
                    .transition(.opacity)
                }
            }
            .frame(width: 190, height: 120)
            
            // Metadata info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                
                if let ocr = item.extractedText, !ocr.isEmpty {
                    Text(ocr)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.25))
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 190)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.white.opacity(0.04) : Color.white.opacity(0.015))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.16 : 0.08), radius: isHovered ? 10 : 4, x: 0, y: isHovered ? 5 : 2)
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onTapGesture {
            onSelect(URL(fileURLWithPath: item.filePath))
        }
        .onHover { hover in
            isHovered = hover
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch ContentType(rawValue: type) {
        case .qrCode: return "qrcode"
        case .receipt: return "scroll"
        case .codeSnippet: return "chevron.left.forwardslash.chevron.right"
        case .uiScreenshot: return "macwindow"
        case .textDocument: return "doc.text"
        default: return "photo"
        }
    }
}



import SwiftUI
import AppKit
import IOKit.ps

enum BatteryState {
    case battery
    case charging
    case pluggedIn
}

@Observable
class BatteryManager {
    var batteryPercentage: Int = 100
    var state: BatteryState = .battery
    private var timer: Timer?
    
    init() {
        updateBattery()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBattery()
        }
    }
    
    func updateBattery() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        var foundPercentage = 100
        var foundState: BatteryState = .battery
        
        for ps in sources {
            let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as! [String: Any]
            if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
                foundPercentage = capacity
            }
            
            let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            let powerState = info[kIOPSPowerSourceStateKey] as? String
            
            if powerState == kIOPSACPowerValue {
                if isCharging {
                    foundState = .charging
                } else {
                    foundState = .pluggedIn
                }
            }
        }
        
        DispatchQueue.main.async {
            self.batteryPercentage = foundPercentage
            self.state = foundState
        }
    }
}

@Observable
// Multi-source Now Playing manager.
// Cascade: MediaRemote (restricted on macOS 14+) → Spotify → Apple Music → Browser mediaSession
class MediaPlayerManager {
    var title: String = ""
    var artist: String = ""
    var positionStr: String = "0:00"
    var durationStr: String = "0:00"
    var progress: Double = 0.0
    var isPlaying: Bool = false
    var isRunning: Bool = false
    var artworkImage: NSImage? = nil

    private var timer: Timer?
    private var activeSource: String? = nil // "Spotify", "Music", or browser app name
    private var activeSourceIsBrowser: Bool = false
    private var activeSourceIsSafari: Bool = false
    init() {
        fetchNowPlaying()

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchNowPlaying()
        }

        // React instantly when any app starts/stops playing
        let dc = DistributedNotificationCenter.default()
        for name in [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
        ] {
            dc.addObserver(forName: NSNotification.Name(name), object: nil, queue: .main) { [weak self] _ in
                self?.fetchNowPlaying()
            }
        }
    }

    func fetchNowPlaying() {
        fetchViaScripting()
    }

    // MARK: - Scripting cascade

    private func fetchViaScripting() {
        let showNowPlaying = UserDefaults.standard.bool(forKey: "showNowPlaying")
        if !showNowPlaying {
            Task { @MainActor in self.isRunning = false; self.isPlaying = false }; return
        }

        Task { [weak self] in
            guard let self = self else { return }

            let enableSpotify = UserDefaults.standard.bool(forKey: "enableSpotify")
            let enableMusic = UserDefaults.standard.bool(forKey: "enableAppleMusic")

            // 1 — Spotify
            if enableSpotify && self.isRunning("com.spotify.client") {
                if let info = await self.spotifyInfo() {
                    await MainActor.run {
                        self.activeSource = "Spotify"
                        self.activeSourceIsBrowser = false
                        self.apply(info)
                    }; return
                }
            }

            // 2 — Apple Music
            if enableMusic && self.isRunning("com.apple.Music") {
                if let info = await self.appleMusicInfo() {
                    await MainActor.run {
                        self.activeSource = "Music"
                        self.activeSourceIsBrowser = false
                        self.apply(info)
                    }; return
                }
            }

            // 3 — Browsers
            let browsers: [(id: String, name: String, isSafari: Bool)] = [
                ("com.google.Chrome",           "Google Chrome", false),
                ("company.thebrowser.Browser",  "Arc",           false),
                ("com.brave.Browser",           "Brave Browser", false),
                ("com.microsoft.edgemac",       "Microsoft Edge",false),
                ("com.operasoftware.Opera",     "Opera",         false),
                ("org.mozilla.firefox",         "Firefox",       false),
                ("com.apple.Safari",            "Safari",        true),
            ]
            for browser in browsers {
                if self.isRunning(browser.id) {
                    if let info = await self.browserSession(app: browser.name, isSafari: browser.isSafari) {
                        await MainActor.run {
                            self.activeSource = browser.name
                            self.activeSourceIsBrowser = true
                            self.activeSourceIsSafari = browser.isSafari
                            self.apply(info)
                        }; return
                    }
                }
            }

            await MainActor.run {
                self.activeSource = nil
                self.isRunning = false
                self.isPlaying = false
            }
        }
    }

    private func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    struct Info { var title: String; var artist: String; var isPlaying: Bool; var duration: Double = 0; var elapsed: Double = 0 }


    private func apply(_ i: Info) {
        title = i.title; artist = i.artist; isPlaying = i.isPlaying; isRunning = true
        progress = i.duration > 0 ? i.elapsed / i.duration : 0
        positionStr = formatTime(i.elapsed); durationStr = formatTime(i.duration)
        print("[NowPlaying] Source: \(activeSource ?? "Unknown") | Playing: \(title)")
    }

    // MARK: - Spotify

    private func spotifyInfo() async -> Info? {
        let src = """
        tell application "Spotify"
            if it is running then
                try
                    if player state is playing or player state is paused then
                        set t to name of current track
                        set a to artist of current track
                        set p to (player state is playing)
                        set d to duration of current track / 1000.0
                        set e to player position
                        return t & "|||" & a & "|||" & (p as string) & "|||" & (d as string) & "|||" & (e as string)
                    end if
                on error
                    return ""
                end try
            end if
        end tell
        return ""
        """
        guard let r = await script(src), !r.isEmpty else { return nil }
        let p = r.components(separatedBy: "|||")
        guard p.count == 5 else { return nil }
        return Info(title: p[0], artist: p[1], isPlaying: p[2] == "true", duration: Double(p[3]) ?? 0, elapsed: Double(p[4]) ?? 0)
    }

    // MARK: - Apple Music

    private func appleMusicInfo() async -> Info? {
        let src = """
        tell application "Music"
            if it is running then
                try
                    set ps to player state
                    if ps is playing or ps is paused then
                        if not (exists current track) then return "ERR:no_track"
                        set cur to current track
                        set t to name of cur
                        set a to ""
                        try
                            set a to artist of cur
                        on error
                            try
                                set a to album of cur
                            end try
                        end try
                        set p to (ps is playing)
                        set d to duration of cur
                        set e to player position
                        return (t as string) & "|||" & (a as string) & "|||" & (p as string) & "|||" & (d as string) & "|||" & (e as string)
                    else
                        return "ERR:not_playing_or_paused"
                    end if
                on error errText number errNum
                    if errNum is -1728 then return "ERR:no_track"
                    return "ERR:" & errText & "(" & errNum & ")"
                end try
            end if
        end tell
        return ""
        """
        guard let r = await script(src), !r.isEmpty else { return nil }
        if r.hasPrefix("ERR:") {
            if r != "ERR:no_track" && r != "ERR:not_playing_or_paused" {
                print("[NowPlaying] Music script error: \(r)")
            }
            return nil
        }
        let p = r.components(separatedBy: "|||")
        guard p.count == 5 else { return nil }
        return Info(title: p[0], artist: p[1], isPlaying: p[2] == "true", duration: Double(p[3]) ?? 0, elapsed: Double(p[4]) ?? 0)
    }

    // MARK: - Browser via navigator.mediaSession
    // Websites (YouTube, Spotify Web, etc.) call navigator.mediaSession.metadata = new MediaMetadata(...)
    // This is the SAME data that macOS Control Center displays for browser Now Playing.

    private func browserSession(app: String, isSafari: Bool) async -> Info? {
        let js = #"(function(){var m=window.navigator&&window.navigator.mediaSession;if(!m||!m.metadata||!m.metadata.title)return"";var s=m.playbackState||"none";return m.metadata.title+"|||"+(m.metadata.artist||m.metadata.album||"")+"|||"+s})()"#

        // Escape quotes for AppleScript string literal
        let escapedJS = js.replacingOccurrences(of: "\"", with: "\\\"")

        let src: String
        if isSafari {
            src = """
            tell application "Safari"
                if it is running then
                    try
                        set r to do JavaScript "\(escapedJS)" in current tab of front window
                        return r
                    end try
                end if
            end tell
            return ""
            """
        } else {
            src = """
            tell application "\(app)"
                if it is running then
                    try
                        set r to execute front window's active tab javascript "\(escapedJS)"
                        return r
                    end try
                end if
            end tell
            return ""
            """
        }
        guard let r = await script(src), !r.isEmpty else { return nil }
        let p = r.components(separatedBy: "|||")
        guard p.count >= 1, !p[0].isEmpty else { return nil }
        let playing = p.count >= 3 ? p[2] == "playing" : false
        return Info(title: p[0], artist: p.count >= 2 ? p[1] : "", isPlaying: playing)
    }

    // MARK: - Script runner
    // Uses NSAppleScript so TCC correctly attributes requests to NotchApp's bundle,
    // triggering the "NotchApp wants to control [App]" permission prompt.
    // (Using Process+osascript attributes requests to /usr/bin/osascript instead,
    //  which can cause silent denials on macOS 14+.)
    private func script(_ source: String) async -> String? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
                if let err = error {
                    print("[NowPlaying] AppleScript error: \(err["NSAppleScriptErrorMessage"] ?? err)")
                    cont.resume(returning: nil)
                } else {
                    let str = result?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
                    cont.resume(returning: str?.isEmpty == false ? str : nil)
                }
            }
        }
    }

    // MARK: - Utilities

    func formatTime(_ t: Double) -> String {
        let s = Int(t); return String(format: "%d:%02d", s / 60, s % 60)
    }

    func playPause() {
        guard let source = activeSource else { return }
        let cmd: String
        if activeSourceIsBrowser {
            let js = "var v=document.querySelector('video, audio'); if(v) { v.paused ? v.play() : v.pause(); }"
            let escapedJS = js.replacingOccurrences(of: "\"", with: "\\\"")
            if activeSourceIsSafari {
                cmd = "tell application \"Safari\" to do JavaScript \"\(escapedJS)\" in current tab of front window"
            } else {
                cmd = "tell application \"\(source)\" to execute front window's active tab javascript \"\(escapedJS)\""
            }
        } else {
            cmd = "tell application \"\(source)\" to playpause"
        }
        
        Task {
            await script(cmd)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.fetchNowPlaying() }
        }
    }

    func nextTrack() {
        guard let source = activeSource else { return }
        let cmd: String
        if activeSourceIsBrowser {
            // Browsers usually don't have a standardized JS next. Generic key fallback.
            cmd = "tell application \"System Events\" to key code 124 using command down" 
        } else {
            cmd = "tell application \"\(source)\" to next track"
        }
        Task { await script(cmd); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.fetchNowPlaying() } }
    }

    func prevTrack() {
        guard let source = activeSource else { return }
        let cmd: String
        if activeSourceIsBrowser {
            cmd = "tell application \"System Events\" to key code 123 using command down"
        } else {
            cmd = "tell application \"\(source)\" to previous track"
        }
        Task { await script(cmd); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.fetchNowPlaying() } }
    }
}



struct NotchExpandedView: View {
    @Environment(\.openSettings) private var openSettings
    @State private var batteryManager = BatteryManager()
    @State private var mediaManager = MediaPlayerManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Spacer()
                
                HStack(spacing: 16) {
                    if #available(macOS 14.0, *) {
                        SettingsLink {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            if #available(macOS 13.0, *) {
                                NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)
                            } else {
                                NSApp.sendAction(Selector("showPreferencesWindow:"), to: nil, from: nil)
                            }
                        }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(batteryManager.batteryPercentage)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        
                        MacBatteryIcon(percentage: batteryManager.batteryPercentage, state: batteryManager.state)
                    }
                }
                .font(.system(size: 14))
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
            Spacer()
            
            // Centered Media Player
            if mediaManager.isRunning {
                HStack(alignment: .top, spacing: 20) {
                    // Album Art (real artwork from MediaRemote, fallback to placeholder)
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.purple, .black, .gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Group {
                                    if let img = mediaManager.artworkImage {
                                        Image(nsImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Path { path in
                                            path.move(to: CGPoint(x: 10, y: 70))
                                            path.addCurve(to: CGPoint(x: 90, y: 30), control1: CGPoint(x: 40, y: 100), control2: CGPoint(x: 60, y: 0))
                                        }.stroke(Color.white.opacity(0.6), lineWidth: 2)
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: mediaManager.isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .foregroundColor(.pink)
                                    .font(.system(size: 12))
                            )
                            .offset(x: 8, y: 8)
                    }
                    
                    // Track Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mediaManager.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(mediaManager.artist)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Progress Bar
                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: max(0, geo.size.width * CGFloat(mediaManager.progress)), height: 4)
                                }
                            }
                            .frame(height: 4)
                            
                            HStack {
                                Text(mediaManager.positionStr)
                                Spacer()
                                Text(mediaManager.durationStr)
                            }
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Controls
                        HStack(spacing: 24) {
                            Spacer()
                            Button(action: { mediaManager.prevTrack() }) {
                                Image(systemName: "backward.fill")
                            }.buttonStyle(.plain)
                            
                            Button(action: { mediaManager.playPause() }) {
                                Image(systemName: mediaManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24))
                            }.buttonStyle(.plain)
                            
                            Button(action: { mediaManager.nextTrack() }) {
                                Image(systemName: "forward.fill")
                            }.buttonStyle(.plain)
                            
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                    }
                    .frame(width: 200, height: 100)
                }
                .padding(.bottom, 20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("No Media Playing")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 30)
            }
            
            Spacer()
        }
    }
}

struct MacBatteryIcon: View {
    var percentage: Int
    var state: BatteryState
    
    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .center) {
                // Outer shell
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .frame(width: 22, height: 11)
                
                // Inner fill (aligned left)
                HStack {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(percentage <= 20 && state != .charging ? Color.red : Color.white)
                        .frame(width: max(0, min(19, (CGFloat(percentage) / 100.0) * 19)), height: 7)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 1.5)
                
                // Overlay icons
                if state == .charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(Color.black)
                } else if state == .pluggedIn {
                    Image(systemName: "powerplug.fill")
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(Color.black)
                }
            }
            .frame(width: 22, height: 11)
            
            // Battery tip
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.5))
                .frame(width: 1.5, height: 4)
        }
    }
}

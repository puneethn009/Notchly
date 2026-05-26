import SwiftUI
import Combine
import AppKit

// MARK: - AppleScript Helper
private enum AS {
    @discardableResult
    static func run(_ s: String) async -> NSAppleEventDescriptor? {
        await withCheckedContinuation { cont in
            Task.detached(priority: .userInitiated) {
                let script = NSAppleScript(source: s)
                var err: NSDictionary?
                let r = script?.executeAndReturnError(&err)
                cont.resume(returning: err == nil ? r : nil)
            }
        }
    }
}

// MARK: - MediaPlayerManager
// Architecture: DistributedNotificationCenter triggers → AppleScript for Spotify state
// Apple Music state comes directly from notification userInfo (no AppleScript needed)
// Artwork fetched from iTunes Search API (public, no permissions needed)
class MediaPlayerManager: ObservableObject {

    // MARK: Published
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var artworkImage: NSImage? = nil {
        didSet {
            if let image = artworkImage {
                let colors = image.extractGradientColors()
                self.artworkColors = colors
                let primary = colors[0]
                // If the color is too dark, use white instead
                self.primaryArtworkColor = primary.isTooDark ? .white : primary
            } else {
                self.artworkColors = [.gray.opacity(0.1), .black.opacity(0.4)]
                self.primaryArtworkColor = .white
            }
        }
    }
    @Published var artworkColors: [Color] = [.gray.opacity(0.1), .black.opacity(0.4)]
    @Published var primaryArtworkColor: Color = .white
    @Published var isPlaying: Bool = false {
        didSet {
            updateStickyState()
        }
    }
    @Published var isRunning: Bool = false
    @Published var progress: Double = 0.0
    @Published var positionStr: String = "0:00"
    @Published var durationStr: String = "0:00"
    @Published var totalDuration: Double = 0
    @Published var activeSource: String = "System"
    @Published var isMuted: Bool = false
    @Published var queue: [TrackInfo] = []
    @Published var lyrics: String = ""
    @Published var syncedLyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int = 0

    struct TrackInfo: Identifiable { let id = UUID(); let title: String; let artist: String }
    struct LyricLine: Identifiable { let id = UUID(); let time: Double; let duration: Double; let text: String }

    static let shared = MediaPlayerManager()

    private var lastElapsedTime: Double = 0
    private var lastTimestamp: Date = Date()
    private var lastTrackID: String = ""
    private var progressTimer: Timer?
    private var lyricsTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var ytmTimer: Timer?
    private var ytmConsecutiveFailures: Int = 0
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Start
    func start() {
        setupNotifications()
        // Initial Spotify check (Music will update via notification when track changes)
        Task { await fetchSpotifyState() }
        startProgressTimer()
        startSyncTimer()
        startYTMTracker()
        refreshMuteState()
        
        // Listen for setting changes to immediately stop tracking if disabled
        SettingsManager.shared.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    if !SettingsManager.shared.useAppleMusic && self?.activeSource == "Music" {
                        self?.isPlaying = false
                        self?.isRunning = false
                    }
                    if !SettingsManager.shared.useSpotify && self?.activeSource == "Spotify" {
                        self?.isPlaying = false
                        self?.isRunning = false
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Distributed Notifications (no MRMediaRemote, no XPC blocks)
    private func setupNotifications() {
        let dc = DistributedNotificationCenter.default()

        // Apple Music: userInfo has Name, Artist, Player State, Total Time, Elapsed Time
        // This fires on play, pause, skip — and the userInfo always has full track data
        dc.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil, queue: .main
        ) { [weak self] notification in
            self?.handleMusicNotification(notification)
        }

        // Spotify: fires on every state change; we fetch full state via AppleScript after
        dc.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in
            guard NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.spotify.client").count > 0 else {
                DispatchQueue.main.async {
                    if self?.activeSource == "Spotify" {
                        self?.isPlaying = false
                        self?.isRunning = false
                    }
                }
                return
            }
            Task { await self?.fetchSpotifyState() }
        }
    }

    // MARK: - Apple Music (from notification userInfo — no AppleScript needed)
    private func handleMusicNotification(_ notification: Notification) {
        guard SettingsManager.shared.useAppleMusic else { return }
        guard let info = notification.userInfo else { return }

        let trackName   = info["Name"] as? String ?? ""
        let trackArtist = info["Artist"] as? String ?? ""
        let state       = info["Player State"] as? String ?? "Stopped"
        let playing     = state == "Playing"

        // Smart unit detection: Total Time is always ms; Elapsed Time may be s or ms
        // If elapsedRaw > dur (seconds), it must be in milliseconds — divide it
        let dur = (info["Total Time"] as? Double ?? 0) / 1000.0
        let elapsedRaw = info["Elapsed Time"] as? Double ?? 0
        let pos = elapsedRaw > dur && dur > 0 ? elapsedRaw / 1000.0 : elapsedRaw

        guard !trackName.isEmpty else {
            if state == "Stopped" {
                DispatchQueue.main.async { self.isPlaying = false; self.isRunning = false }
            }
            return
        }

        let trackID = "Music:\(trackName):\(trackArtist)"
        let changed = trackID != lastTrackID

        DispatchQueue.main.async {
            self.title    = trackName
            self.artist   = trackArtist
            self.isPlaying = playing
            self.isRunning = true
            self.activeSource = "Music"
            self.totalDuration = dur
            self.lastElapsedTime = pos  // Use notification position directly — fast for seeks
            self.lastTimestamp = Date()
            self.updateProgress(pos: pos, dur: dur)

            if changed {
                self.artworkImage = nil
                self.lyrics = ""
                self.syncedLyrics = []
                self.currentLyricIndex = 0
            }
        }

        if changed {
            lastTrackID = trackID
            fetchArtworkFromiTunes(title: trackName, artist: trackArtist)
            fetchLyrics(title: trackName, artist: trackArtist)

            // Only use AppleScript on NEW TRACK START for accurate initial position
            // (not on every seek/play/pause — AppleScript is too slow for rapid seeks)
            Task {
                if let d = await AS.run("tell application \"Music\" to if running then return player position") {
                    let actualPos = d.doubleValue
                    if actualPos > 0 {
                        await MainActor.run {
                            self.lastElapsedTime = actualPos
                            self.lastTimestamp = Date()
                            self.updateProgress(pos: actualPos, dur: self.totalDuration)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Spotify (AppleScript fetch after notification)
    private func fetchSpotifyState() async {
        guard SettingsManager.shared.useSpotify else { return }
        let script = """
        tell application "Spotify"
            if running then
                try
                    set pState to player state is playing
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tPos to player position
                    set tDur to (duration of current track) / 1000
                    set artURL to artwork url of current track
                    return {pState, tName, tArtist, tPos, tDur, artURL}
                on error
                    return {}
                end try
            end if
        end tell
        """
        guard let d = await AS.run(script), d.numberOfItems >= 5 else { return }

        let playing = d.atIndex(1)?.booleanValue ?? false
        let tName   = d.atIndex(2)?.stringValue ?? ""
        let tArtist = d.atIndex(3)?.stringValue ?? ""
        let pos     = d.atIndex(4)?.doubleValue ?? 0
        let dur     = d.atIndex(5)?.doubleValue ?? 0
        let artURL  = (d.atIndex(6)?.stringValue ?? "").replacingOccurrences(of: "missing value", with: "")

        guard !tName.isEmpty else { return }
        // Don't override Music if it's actively playing
        if activeSource == "Music" && isPlaying && !playing { return }

        let trackID = "Spotify:\(tName):\(tArtist)"
        let changed = trackID != lastTrackID

        await MainActor.run {
            self.title    = tName
            self.artist   = tArtist
            self.isPlaying = playing
            self.isRunning = true
            self.activeSource = "Spotify"
            self.totalDuration = dur
            self.lastElapsedTime = pos
            self.lastTimestamp = Date()
            self.updateProgress(pos: pos, dur: dur)

            if changed {
                self.artworkImage = nil
                self.lyrics = ""
                self.syncedLyrics = []
                self.currentLyricIndex = 0
            }
        }

        if changed {
            lastTrackID = trackID
            // Spotify provides direct artwork URL — use it, fall back to iTunes API
            if !artURL.isEmpty {
                downloadArtwork(url: artURL)
            } else {
                fetchArtworkFromiTunes(title: tName, artist: tArtist)
            }
            fetchLyrics(title: tName, artist: tArtist)
        }
    }

    // MARK: - Artwork via iTunes Search API (public, free, no permissions)
    private func fetchArtworkFromiTunes(title: String, artist: String) {
        artworkTask?.cancel()
        artworkTask = Task {
            let query = "\(artist) \(title)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            guard !query.isEmpty,
                  let url = URL(string: "https://itunes.apple.com/search?term=\(query)&entity=song&limit=5")
            else { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let results = json["results"] as? [[String: Any]],
                      let first = results.first,
                      var artURLStr = first["artworkUrl100"] as? String else { return }

                // Upgrade to 600x600 from 100x100
                artURLStr = artURLStr.replacingOccurrences(of: "100x100bb", with: "600x600bb")

                guard let artURL = URL(string: artURLStr) else { return }
                let (imgData, _) = try await URLSession.shared.data(from: artURL)
                guard !Task.isCancelled, let img = NSImage(data: imgData) else { return }
                await MainActor.run { 
                    self.artworkImage = img 
                }
            } catch {}
        }
    }

    // MARK: - Artwork direct download (for Spotify URLs)
    private func downloadArtwork(url: String) {
        artworkTask?.cancel()
        artworkTask = Task {
            guard let u = URL(string: url) else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: u)
                guard !Task.isCancelled, let img = NSImage(data: data) else { return }
                await MainActor.run { 
                    self.artworkImage = img 
                }
            } catch {}
        }
    }

    // MARK: - Lyrics via lrclib.net
    private func fetchLyrics(title: String, artist: String) {
        lyricsTask?.cancel()
        lyricsTask = Task {
            guard let eTitle  = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let eArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://lrclib.net/api/search?track_name=\(eTitle)&artist_name=\(eArtist)")
            else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let first = arr.first else { return }
                let plain  = stripLRCHeaders(first["plainLyrics"]  as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let synced = (first["syncedLyrics"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let parsed = parseLRC(synced)
                await MainActor.run {
                    self.syncedLyrics = parsed.map { LyricLine(time: $0.0, duration: 3.0, text: $0.1) }
                    // Use plain lyrics if available; otherwise extract clean text from LRC lines
                    // NEVER set lyrics to raw LRC format (contains [00:12.34] timestamps)
                    if !plain.isEmpty {
                        self.lyrics = plain
                    } else if !parsed.isEmpty {
                        self.lyrics = parsed.map { $0.1 }.joined(separator: "\n")
                    } else {
                        self.lyrics = ""
                    }
                }
            } catch {}
        }
    }

    // Strip LRC header tags like [ar:Artist], [al:Album], [by:Creator] from lyrics
    private func stripLRCHeaders(_ text: String) -> String {
        let headerPattern = try? NSRegularExpression(pattern: #"^\[[a-zA-Z]+:[^\]]*\]\s*$"#)
        let lines = text.components(separatedBy: "\n")
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return true }
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            return headerPattern?.firstMatch(in: trimmed, range: range) == nil
        }
        return filtered.joined(separator: "\n")
    }

    private func parseLRC(_ lrc: String) -> [(Double, String)] {
        var result: [(Double, String)] = []
        guard let re = try? NSRegularExpression(pattern: #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,2}))?\]"#) else { return [] }
        for line in lrc.split(separator: "\n").map(String.init) {
            let ns = line as NSString
            if let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
                let min = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let sec = Double(ns.substring(with: m.range(at: 2))) ?? 0
                let cs  = m.range(at: 3).location != NSNotFound ? Double(ns.substring(with: m.range(at: 3))) ?? 0 : 0
                let t   = min * 60 + sec + cs / 100
                let txt = ns.substring(from: m.range.location + m.range.length).trimmingCharacters(in: .whitespaces)
                if !txt.isEmpty { result.append((t, txt)) }
            }
        }
        return result.sorted { $0.0 < $1.0 }
    }

    // MARK: - Progress & Sync Timers
    private var syncTimer: Timer?

    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            let source = self.activeSource
            Task.detached {
                let script: String
                if source == "Spotify" {
                    script = "tell application \"Spotify\" to if running then return player position"
                } else if source == "Music" {
                    script = "tell application \"Music\" to if running then return player position"
                } else {
                    return
                }

                if let d = await AS.run(script) {
                    let actualPos = d.doubleValue
                    if actualPos >= 0 {
                        await MainActor.run {
                            let expectedPos = self.lastElapsedTime + Date().timeIntervalSince(self.lastTimestamp)
                            // If difference is > 1.5 seconds, user definitely seeked
                            if abs(expectedPos - actualPos) > 1.5 {
                                self.lastElapsedTime = actualPos
                                self.lastTimestamp = Date()
                                self.updateProgress(pos: actualPos, dur: self.totalDuration)

                                self.updateLyricIndex(for: actualPos)
                            }
                        }
                    }
                }
            }
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, self.totalDuration > 0 else { return }
            let pos = min(self.lastElapsedTime + Date().timeIntervalSince(self.lastTimestamp), self.totalDuration)
            DispatchQueue.main.async {
                self.updateProgress(pos: pos, dur: self.totalDuration)
                self.updateLyricIndex(for: pos)
            }
        }
    }

    private func updateLyricIndex(for pos: Double) {
        if !self.syncedLyrics.isEmpty {
            let idx = self.syncedLyrics.lastIndex { $0.time <= pos } ?? 0
            if idx != self.currentLyricIndex { self.currentLyricIndex = idx }
        }
    }

    private func updateProgress(pos: Double, dur: Double) {
        progress    = dur > 0 ? min(1.0, pos / dur) : 0
        positionStr = fmt(pos)
        durationStr = fmt(dur)
    }

    // MARK: - Playback Controls (AppleScript — proven to work)
    func playPause() { Task {
        if activeSource == "Spotify" { await AS.run("tell application \"Spotify\" to playpause") }
        else if activeSource == "YouTubeMusic" { await sendYTMCommand("track-play-pause") }
        else { await AS.run("tell application \"Music\" to playpause") }
    }}
    func nextTrack() { Task {
        if activeSource == "Spotify" { await AS.run("tell application \"Spotify\" to next track") }
        else if activeSource == "YouTubeMusic" { await sendYTMCommand("track-next") }
        else { await AS.run("tell application \"Music\" to next track") }
    }}
    func prevTrack() { Task {
        if activeSource == "Spotify" { await AS.run("tell application \"Spotify\" to previous track") }
        else if activeSource == "YouTubeMusic" { await sendYTMCommand("track-previous") }
        else { await AS.run("tell application \"Music\" to previous track") }
    }}
    func toggleMute() { Task {
        await AS.run("set volume output muted (not (output muted of (get volume settings)))")
        refreshMuteState()
    }}
    func refreshMuteState() { Task {
        if let r = await AS.run("output muted of (get volume settings)") {
            let muted = r.booleanValue
            await MainActor.run { self.isMuted = muted }
        }
    }}

    // MARK: - YouTube Music (ytmdesktop.app) Integration
    private func startYTMTracker() {
        ytmTimer?.invalidate()
        ytmTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let backoff = min(60, 1 << min(6, self.ytmConsecutiveFailures))
            if Int(Date().timeIntervalSince1970) % backoff == 0 {
                Task { await self.fetchYTMState() }
            }
        }
    }

    private func fetchYTMState() async {
        guard let url = URL(string: "http://localhost:9863/query") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { self.ytmConsecutiveFailures += 1 }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let player = json["player"] as? [String: Any],
               let track = player["track"] as? [String: Any] {
                
                let isPaused = player["isPaused"] as? Bool ?? true
                let position = player["seekbarCurrentPosition"] as? Double ?? 0
                let title = track["title"] as? String ?? ""
                let artist = track["author"] as? String ?? ""
                let duration = track["duration"] as? Double ?? 0
                let coverUrl = track["cover"] as? String ?? ""

                await MainActor.run {
                    self.ytmConsecutiveFailures = 0
                    // Only take over if Apple Music / Spotify are not actively playing
                    if self.activeSource != "YouTubeMusic" && self.isPlaying {
                        if self.activeSource == "Music" || self.activeSource == "Spotify" {
                            if !isPaused { return } // Yield to native players
                        }
                    }

                    if !title.isEmpty {
                        self.activeSource = "YouTubeMusic"
                        self.isRunning = true
                        
                        if title != self.title || artist != self.artist {
                            self.title = title
                            self.artist = artist
                            self.totalDuration = duration
                            self.durationStr = self.fmt(duration)
                            self.fetchLyrics(title: title, artist: artist)
                            
                            if let artUrl = URL(string: coverUrl) {
                                self.artworkTask?.cancel()
                                self.artworkTask = Task {
                                    if let (data, _) = try? await URLSession.shared.data(from: artUrl), let img = NSImage(data: data) {
                                        await MainActor.run { self.artworkImage = img }
                                    }
                                }
                            }
                        }
                        
                        self.isPlaying = !isPaused
                        
                        // Handle sync (allow 2 second drift)
                        let expectedPos = self.lastElapsedTime + Date().timeIntervalSince(self.lastTimestamp)
                        let drift = abs(expectedPos - position)
                        if drift > 2.0 || !self.isPlaying {
                            self.lastElapsedTime = position
                            self.lastTimestamp = Date()
                            self.updateProgress(pos: position, dur: self.totalDuration)
                            self.updateLyricIndex(for: position)
                        }
                    }
                }
            }
        } catch {
            // YTM Not running or remote control disabled
            await MainActor.run {
                self.ytmConsecutiveFailures += 1
                if self.activeSource == "YouTubeMusic" {
                    self.isPlaying = false
                    self.isRunning = false
                }
            }
        }
    }

    private func sendYTMCommand(_ command: String) async {
        guard let url = URL(string: "http://localhost:9863/query/command") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["command": command]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }

    private func updateStickyState() {
        DispatchQueue.main.async {
            if self.isPlaying {
                // If a timer is already running, don't override it (timer takes priority)
                if !TimerManager.shared.isRunning && !TimerManager.shared.isStopwatchRunning {
                    NotchState.shared.stickyType = .media
                    if !NotchState.shared.isSticky {
                        withAnimation(.spring()) {
                            NotchState.shared.isSticky = true
                        }
                    }
                }
            } else {
                // If we are the one currently occupying the sticky slot, release it
                if NotchState.shared.stickyType == .media {
                    withAnimation(.spring()) {
                        NotchState.shared.isSticky = false
                    }
                }
            }
        }
    }

    private func fmt(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let i = Int(s); return String(format: "%d:%02d", i / 60, i % 60)
    }
}

extension Color {
    var isTooDark: Bool {
        let nsColor = NSColor(self)
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var brg: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getHue(&hue, saturation: &sat, brightness: &brg, alpha: &alpha)
        return brg < 0.35 // Threshold for "too dark"
    }
}

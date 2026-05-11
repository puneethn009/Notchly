import SwiftUI
import Combine
import AppKit

class MediaPlayerManager: ObservableObject {
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var positionStr: String = "0:00"
    @Published var durationStr: String = "0:00"
    @Published var progress: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var isRunning: Bool = false
    @Published var isMuted: Bool = false
    @Published var artworkImage: NSImage? = nil
    @Published var activeSource: String? = nil
    @Published var lyrics: String = ""
    @Published var syncedLyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int = 0
    @Published var queue: [TrackInfo] = []
    
    struct LyricLine: Identifiable {
        let id = UUID()
        let time: Double
        let text: String
    }
    
    struct TrackInfo: Identifiable {
        let id = UUID()
        let title: String
        let artist: String
    }
    
    static let shared = MediaPlayerManager()
    private var timer: Timer?

    private init() {
        // Initial detection
        fetchNowPlaying()
        
        // Periodic sync for progress bar
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchNowPlaying()
        }

        // Live updates for track changes
        let dc = DistributedNotificationCenter.default()
        dc.addObserver(forName: NSNotification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { [weak self] n in
            self?.handleSystemNotification(n, source: "Music")
        }
        dc.addObserver(forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] n in
            self?.handleSystemNotification(n, source: "Spotify")
        }
    }

    private func handleSystemNotification(_ notification: Notification, source: String) {
        guard let userInfo = notification.userInfo else { return }
        let newTitle = userInfo["Name"] as? String ?? userInfo["track name"] as? String ?? ""
        let newArtist = userInfo["Artist"] as? String ?? userInfo["artist"] as? String ?? ""
        let state = userInfo["Player State"] as? String ?? userInfo["playback state"] as? String ?? ""
        
        DispatchQueue.main.async {
            if newTitle != self.title || newArtist != self.artist {
                self.lyrics = ""
                self.syncedLyrics = []
                self.currentLyricIndex = 0
            }
            
            self.title = newTitle
            self.artist = newArtist
            self.isPlaying = (state == "Playing")
            self.activeSource = source
            self.isRunning = !newTitle.isEmpty
            self.updateStickyState()
            self.fetchDetailedInfo()
        }
    }

    func fetchNowPlaying() {
        // Check both players via AppleScript for initial state
        Task {
            let settings = SettingsManager.shared
            if settings.useAppleMusic, let music = await getMusicInfo() {
                updateWithInfo(music, source: "Music")
            } else if settings.useSpotify, let spotify = await getSpotifyInfo() {
                updateWithInfo(spotify, source: "Spotify")
            }
        }
    }
    
    private func updateWithInfo(_ info: [String: Any], source: String) {
        DispatchQueue.main.async {
            let newTitle = info["title"] as? String ?? ""
            let newArtist = info["artist"] as? String ?? ""
            let trackChanged = (newTitle != self.title || newArtist != self.artist)
            
            self.title = newTitle
            self.artist = newArtist
            self.isPlaying = info["isPlaying"] as? Bool ?? false
            self.progress = info["progress"] as? Double ?? 0.0
            self.positionStr = info["position"] as? String ?? "0:00"
            self.durationStr = info["duration"] as? String ?? "0:00"
            self.activeSource = source
            self.isRunning = !self.title.isEmpty
            self.updateStickyState()
            
            // Sync lyrics position if we have time data
            if let posSeconds = info["posSeconds"] as? Double {
                self.updateLyricsPosition(currentTime: posSeconds)
            }
            
            if let newLyrics = info["lyrics"] as? String, !newLyrics.isEmpty {
                self.lyrics = newLyrics
            } else if trackChanged {
                self.lyrics = ""
            }
            
            if let q = info["queue"] as? [[String: String]] {
                self.queue = q.map { TrackInfo(title: $0["title"] ?? "", artist: $0["artist"] ?? "") }
            }
            
            // Handle Artwork
            if let artUrl = info["artworkUrl"] as? String, let url = URL(string: artUrl) {
                self.downloadArtwork(from: url)
            } else if source == "Music" {
                self.fetchMusicArtwork()
            } else if source == "Spotify" && self.artworkImage == nil {
                 // Fallback if no URL
                 self.artworkImage = nil
            }
            
            // Check mute state
            let script = "output volume of (get volume settings)"
            if let volStr = self.runScriptSync(script), let vol = Int(volStr) {
                self.isMuted = (vol == 0)
            }
        }
    }
    
    private func downloadArtwork(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self?.artworkImage = image
                }
            }
        }.resume()
    }
    
    private func fetchMusicArtwork() {
        let scriptSource = """
        tell application "Music"
            if (count of artworks of current track) > 0 then
                set art to artwork 1 of current track
                return raw data of art
            end if
        end tell
        """
        
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if error == nil {
                self.artworkImage = NSImage(data: result.data)
            }
        }
    }

    private func fetchDetailedInfo() {
        Task {
            if activeSource == "Music", let info = await getMusicInfo() { updateWithInfo(info, source: "Music") }
            if activeSource == "Spotify", let info = await getSpotifyInfo() { updateWithInfo(info, source: "Spotify") }
        }
    }

    private func updateStickyState() {
        DispatchQueue.main.async {
            if self.isPlaying && !NotchState.shared.isExpanded && !TimerManager.shared.isRunning {
                NotchState.shared.stickyType = .media
                NotchState.shared.isSticky = true
            } else if !self.isPlaying && NotchState.shared.stickyType == .media {
                NotchState.shared.isSticky = false
            }
        }
    }

    // MARK: - Controls
    func playPause() {
        let script = activeSource == "Spotify" ? "tell application \"Spotify\" to playpause" : "tell application \"Music\" to playpause"
        runScript(script)
    }

    func nextTrack() {
        let script = activeSource == "Spotify" ? "tell application \"Spotify\" to next track" : "tell application \"Music\" to next track"
        runScript(script)
    }

    func prevTrack() {
        let script = activeSource == "Spotify" ? "tell application \"Spotify\" to previous track" : "tell application \"Music\" to previous track"
        runScript(script)
    }
    
    func toggleMute() {
        // System-wide mute is most reliable
        let script = "set curVolume to output volume of (get volume settings)\nif curVolume > 0 then\nset volume output volume 0\nelse\nset volume output volume 50\nend if"
        runScript(script)
    }

    private func runScript(_ s: String) {
        if let script = NSAppleScript(source: s) {
            script.executeAndReturnError(nil)
            // Trigger an immediate fetch to update UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.fetchNowPlaying() }
        }
    }

    // MARK: - AppleScript Getters
    private func getMusicInfo() async -> [String: Any]? {
        let src = """
        tell application "Music"
            if running then
                set t to name of current track
                set a to artist of current track
                set p to player state is playing
                set dur to duration of current track
                set pos to player position
                set lyr to ""
                try
                    set lyr to lyrics of current track
                end try
                
                set qNames to ""
                set qArtists to ""
                try
                    set qPlaylist to current playlist
                    set qTracks to tracks of qPlaylist
                    set trackCount to count of qTracks
                    set currentIndex to (index of current track) + 1
                    
                    set endRange to currentIndex + 5
                    if endRange > trackCount then set endRange to trackCount
                    
                    if currentIndex <= trackCount then
                        repeat with i from currentIndex to endRange
                            set trk to item i of qTracks
                            set qNames to qNames & (name of trk as string) & "###"
                            set qArtists to qArtists & (artist of trk as string) & "###"
                        end repeat
                    end if
                end try
                
                return t & "|||" & a & "|||" & (p as string) & "|||" & (dur as string) & "|||" & (pos as string) & "|||" & lyr & "|||" & qNames & "|||" & qArtists
            end if
        end tell
        """
        guard let res = runScriptSync(src) else { return nil }
        let parts = res.components(separatedBy: "|||")
        guard parts.count >= 5 else { return nil }
        
        let dur = Double(parts[3]) ?? 1.0
        let pos = Double(parts[4]) ?? 0.0
        
        var q: [[String: String]] = []
        if parts.count >= 8 {
            let names = parts[6].components(separatedBy: "###").filter { !$0.isEmpty }
            let artists = parts[7].components(separatedBy: "###").filter { !$0.isEmpty }
            for i in 0..<min(names.count, artists.count) {
                q.append(["title": names[i], "artist": artists[i]])
            }
        }
        
        return [
            "title": parts[0],
            "artist": parts[1],
            "isPlaying": parts[2] == "true",
            "progress": pos / dur,
            "duration": formatTime(dur),
            "position": formatTime(pos),
            "posSeconds": pos,
            "lyrics": parts.count > 5 ? parts[5] : "",
            "queue": q
        ]
    }

    private func getSpotifyInfo() async -> [String: Any]? {
        let src = """
        tell application "Spotify"
            if running then
                set t to name of current track
                set a to artist of current track
                set p to player state is playing
                set dur to (duration of current track) / 1000
                set pos to player position
                set art to artwork url of current track
                return t & "|||" & a & "|||" & (p as string) & "|||" & (dur as string) & "|||" & (pos as string) & "|||" & art
            end if
        end tell
        """
        guard let res = runScriptSync(src) else { return nil }
        let parts = res.components(separatedBy: "|||")
        guard parts.count >= 5 else { return nil }
        
        let dur = Double(parts[3]) ?? 1.0
        let pos = Double(parts[4]) ?? 0.0
        
        let title = parts[0]
        let artist = parts[1]
        
        // Fetch lyrics externally since Spotify doesn't provide them
        fetchExternalLyrics(title: title, artist: artist)
        
        return [
            "title": title,
            "artist": artist,
            "isPlaying": parts[2] == "true",
            "progress": pos / dur,
            "duration": formatTime(dur),
            "position": formatTime(pos),
            "posSeconds": pos,
            "artworkUrl": parts.count > 5 ? parts[5] : ""
        ]
    }

    private func fetchExternalLyrics(title: String, artist: String) {
        guard !title.isEmpty && !artist.isEmpty else { return }
        
        // Don't re-fetch if we already have these lyrics
        if self.title == title && !self.lyrics.isEmpty { return }
        
        let urlString = "https://lrclib.net/api/get?artist_name=\(artist)&track_name=\(title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let plainLyrics = json["plainLyrics"] as? String ?? ""
                    let lrcLyrics = json["syncedLyrics"] as? String ?? ""
                    
                    DispatchQueue.main.async {
                        self?.lyrics = plainLyrics
                        if !lrcLyrics.isEmpty {
                            self?.parseLRC(lrcLyrics)
                        } else {
                            self?.syncedLyrics = []
                        }
                    }
                }
            } catch {
                print("Lyric fetch error: \(error)")
            }
        }.resume()
    }

    private func parseLRC(_ lrc: String) {
        var lines: [LyricLine] = []
        let pattern = "\\[(\\d+):(\\d+\\.?\\d*)\\](.*)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        let nsString = lrc as NSString
        let matches = regex?.matches(in: lrc, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches {
            if match.numberOfRanges >= 4 {
                let min = Double(nsString.substring(with: match.range(at: 1))) ?? 0
                let sec = Double(nsString.substring(with: match.range(at: 2))) ?? 0
                let text = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
                
                let totalSeconds = min * 60 + sec
                lines.append(LyricLine(time: totalSeconds, text: text))
            }
        }
        
        var finalLines: [LyricLine] = []
        let sorted = lines.sorted { $0.time < $1.time }
        
        // Add intro marker if first lyric is delayed > 3s
        if let first = sorted.first, first.time > 3.0 {
            finalLines.append(LyricLine(time: 0.0, text: "INSTRUMENTAL_BREAK"))
        }
        
        // Insert instrumental markers for gaps > 6 seconds
        for i in 0..<sorted.count {
            finalLines.append(sorted[i])
            if i < sorted.count - 1 {
                let currentEnd = sorted[i].time
                let nextStart = sorted[i+1].time
                if nextStart - currentEnd > 6.0 {
                    // Place it at the midpoint of the gap
                    let midPoint = currentEnd + (nextStart - currentEnd) / 2.0
                    finalLines.append(LyricLine(time: midPoint, text: "INSTRUMENTAL_BREAK"))
                }
            }
        }
        
        self.syncedLyrics = finalLines
    }

    private func updateLyricsPosition(currentTime: Double) {
        guard !syncedLyrics.isEmpty else { return }
        
        var index = 0
        for (i, line) in syncedLyrics.enumerated() {
            if line.time <= currentTime {
                index = i
            } else {
                break
            }
        }
        
        if self.currentLyricIndex != index {
            DispatchQueue.main.async {
                self.currentLyricIndex = index
            }
        }
    }

    private func runScriptSync(_ s: String) -> String? {
        if let script = NSAppleScript(source: s) {
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if error == nil { return result.stringValue }
        }
        return nil
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

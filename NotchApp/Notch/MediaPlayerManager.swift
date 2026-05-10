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
    @Published var isSystemMuted: Bool = false
    @Published var artworkImage: NSImage? = nil
    @Published var activeSource: String? = nil
    
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
            if let music = await getMusicInfo() {
                updateWithInfo(music, source: "Music")
            } else if let spotify = await getSpotifyInfo() {
                updateWithInfo(spotify, source: "Spotify")
            }
        }
    }
    
    private func updateWithInfo(_ info: [String: Any], source: String) {
        DispatchQueue.main.async {
            self.title = info["title"] as? String ?? ""
            self.artist = info["artist"] as? String ?? ""
            self.isPlaying = info["isPlaying"] as? Bool ?? false
            self.progress = info["progress"] as? Double ?? 0.0
            self.positionStr = info["position"] as? String ?? "0:00"
            self.durationStr = info["duration"] as? String ?? "0:00"
            self.activeSource = source
            self.isRunning = !self.title.isEmpty
            self.updateStickyState()
            
            // Check mute state
            let script = "output volume of (get volume settings)"
            if let volStr = self.runScriptSync(script), let vol = Int(volStr) {
                self.isSystemMuted = (vol == 0)
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
                return t & "|||" & a & "|||" & (p as string) & "|||" & (dur as string) & "|||" & (pos as string)
            end if
        end tell
        """
        guard let res = runScriptSync(src) else { return nil }
        let parts = res.components(separatedBy: "|||")
        guard parts.count == 5 else { return nil }
        
        let dur = Double(parts[3]) ?? 1.0
        let pos = Double(parts[4]) ?? 0.0
        return [
            "title": parts[0],
            "artist": parts[1],
            "isPlaying": parts[2] == "true",
            "progress": pos / dur,
            "duration": formatTime(dur),
            "position": formatTime(pos)
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
                return t & "|||" & a & "|||" & (p as string) & "|||" & (dur as string) & "|||" & (pos as string)
            end if
        end tell
        """
        guard let res = runScriptSync(src) else { return nil }
        let parts = res.components(separatedBy: "|||")
        guard parts.count == 5 else { return nil }
        
        let dur = Double(parts[3]) ?? 1.0
        let pos = Double(parts[4]) ?? 0.0
        return [
            "title": parts[0],
            "artist": parts[1],
            "isPlaying": parts[2] == "true",
            "progress": pos / dur,
            "duration": formatTime(dur),
            "position": formatTime(pos)
        ]
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

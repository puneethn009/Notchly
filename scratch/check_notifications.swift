import Foundation

print("Listening for Apple Music & Spotify notifications... (Press Ctrl+C to stop)")

let dc = DistributedNotificationCenter.default()

dc.addObserver(forName: NSNotification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { notification in
    print("\n[Music Notification]")
    print("UserInfo: \(notification.userInfo ?? [:])")
}

dc.addObserver(forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { notification in
    print("\n[Spotify Notification]")
    print("UserInfo: \(notification.userInfo ?? [:])")
}

RunLoop.main.run()

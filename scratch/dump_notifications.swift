import Foundation

print("Dumping ALL Distributed Notifications for 10 seconds...")
print("Play music in Music.app or Browser now!")

let dc = DistributedNotificationCenter.default()
dc.addObserver(forName: nil, object: nil, queue: .main) { notification in
    let name = notification.name.rawValue
    if name.contains("Music") || name.contains("Player") || name.contains("Track") || name.contains("Playback") || name.contains("Media") {
        print("\n[NOTIFICATION] \(name)")
        if let userInfo = notification.userInfo {
            print("UserInfo: \(userInfo)")
        }
    }
}

let timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
    print("\nAudit Complete.")
    exit(0)
}

RunLoop.main.run()

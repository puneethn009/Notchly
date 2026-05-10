import Foundation

@_silgen_name("MRMediaRemoteGetNowPlayingInfo")
func MRMediaRemoteGetNowPlayingInfo(_ queue: DispatchQueue, _ completion: @escaping ([String: Any]) -> Void)

@_silgen_name("MRMediaRemoteGetNowPlayingApplicationIsPlaying")
func MRMediaRemoteGetNowPlayingApplicationIsPlaying(_ queue: DispatchQueue, _ completion: @escaping (Bool) -> Void)

let group = DispatchGroup()
group.enter()

MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { info in
    print("Info: \(info)")
    group.leave()
}

group.wait()

import Foundation

let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
if let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
    typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    let function = unsafeBitCast(pointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
    
    let group = DispatchGroup()
    group.enter()
    
    function(DispatchQueue.global()) { info in
        print("Media Info: \(info)")
        group.leave()
    }
    
    group.wait()
} else {
    print("Failed to load function pointer")
}

// CGSSpace.swift
// Adapted from boring.notch (TheBoredTeam/boring.notch) — MIT/MPL-2.0
// Original: https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/private/CGSSpace.swift
//
// Creates a dedicated WindowServer compositor space at an absolute level,
// completely independent of the macOS "Desktop Spaces" system.
// At level Int32.max, this space sits ABOVE the space-switching animation layer,
// making windows in it appear fixed to the screen glass (like hardware notch).

import AppKit

// MARK: — Private CGS API declarations (undocumented WindowServer calls)
fileprivate typealias CGSConnectionID = UInt
fileprivate typealias CGSSpaceID = UInt64

@_silgen_name("_CGSDefaultConnection")
fileprivate func _CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSSpaceCreate")
fileprivate func CGSSpaceCreate(_ cid: CGSConnectionID, _ flag: Int, _ options: NSDictionary?) -> CGSSpaceID

@_silgen_name("CGSSpaceDestroy")
fileprivate func CGSSpaceDestroy(_ cid: CGSConnectionID, _ space: CGSSpaceID)

@_silgen_name("CGSSpaceSetAbsoluteLevel")
fileprivate func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)

@_silgen_name("CGSAddWindowsToSpaces")
fileprivate func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

@_silgen_name("CGSRemoveWindowsFromSpaces")
fileprivate func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

@_silgen_name("CGSShowSpaces")
fileprivate func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)

@_silgen_name("CGSHideSpaces")
fileprivate func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)


// MARK: — CGSSpace wrapper

/// A dedicated WindowServer compositing space at an absolute level.
/// Windows added here are rendered above the macOS space-switching animation,
/// so they appear fixed to the physical screen regardless of which Desktop
/// space the user is on.
final class CGSSpaceOverlay {
    private let identifier: CGSSpaceID

    // The set of windows to render in this overlay space.
    // KVO-driven: adding/removing windows automatically calls the CGS API.
    var windows: Set<NSWindow> = [] {
        didSet {
            let removed = oldValue.subtracting(windows)
            let added = windows.subtracting(oldValue)
            if !removed.isEmpty {
                CGSRemoveWindowsFromSpaces(
                    _CGSDefaultConnection(),
                    removed.map { $0.windowNumber } as NSArray,
                    [identifier]
                )
            }
            if !added.isEmpty {
                CGSAddWindowsToSpaces(
                    _CGSDefaultConnection(),
                    added.map { $0.windowNumber } as NSArray,
                    [identifier]
                )
            }
        }
    }

    /// - Parameter level: Compositor level. Use `Int(Int32.max)` to sit above everything.
    init(level: Int = Int(Int32.max)) {
        // flag 0x1 must be 1, otherwise Finder draws desktop icons over the space
        identifier = CGSSpaceCreate(_CGSDefaultConnection(), 0x1, nil)
        CGSSpaceSetAbsoluteLevel(_CGSDefaultConnection(), identifier, level)
        CGSShowSpaces(_CGSDefaultConnection(), [identifier])
    }

    deinit {
        if !windows.isEmpty {
            CGSRemoveWindowsFromSpaces(
                _CGSDefaultConnection(),
                windows.map { $0.windowNumber } as NSArray,
                [identifier]
            )
        }
        CGSHideSpaces(_CGSDefaultConnection(), [identifier])
        CGSSpaceDestroy(_CGSDefaultConnection(), identifier)
    }
}


// MARK: — Singleton

/// Manages the single overlay CGSSpace that the NotchWindow lives in.
/// Must be torn down on app exit: call `NotchSpaceManager.shared.tearDown()`.
final class NotchSpaceManager {
    static let shared = NotchSpaceManager()

    // Level Int32.max = 2147483647. This is the same value boring.notch uses.
    let space = CGSSpaceOverlay(level: Int(Int32.max))

    private init() {}

    func tearDown() {
        // Remove all windows before the space is destroyed on deinit
        space.windows.removeAll()
    }
}

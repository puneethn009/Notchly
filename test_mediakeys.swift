import Cocoa
import CoreGraphics

func myCGEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        CGEvent.tapEnable(tap: refcon!.assumingMemoryBound(to: CFMachPort.self).pointee, enable: true)
        return Unmanaged.passUnretained(event)
    }

    if type == .systemDefined {
        guard let nsevent = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }
        
        // Data1 contains the key code and key state
        let data1 = nsevent.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = (data1 & 0x0000FFFF)
        let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA
        
        let NX_KEYTYPE_SOUND_UP = 0
        let NX_KEYTYPE_SOUND_DOWN = 1
        let NX_KEYTYPE_MUTE = 7
        let NX_KEYTYPE_ILLUMINATION_UP = 21
        let NX_KEYTYPE_ILLUMINATION_DOWN = 22
        let NX_KEYTYPE_BRIGHTNESS_UP = 2
        let NX_KEYTYPE_BRIGHTNESS_DOWN = 3
        
        if keyState {
            print("Pressed key: \(keyCode)")
            if [NX_KEYTYPE_SOUND_UP, NX_KEYTYPE_SOUND_DOWN, NX_KEYTYPE_MUTE, NX_KEYTYPE_BRIGHTNESS_UP, NX_KEYTYPE_BRIGHTNESS_DOWN].contains(Int(keyCode)) {
                print("Intercepted media key! Blocking...")
                return nil // Block the event
            }
        }
    }

    return Unmanaged.passUnretained(event)
}

guard let eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(1 << CGEventType.systemDefined.rawValue),
    callback: myCGEventCallback,
    userInfo: nil
) else {
    print("Failed to create event tap. Make sure to run with Accessibility permissions.")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)

print("Listening for media keys. Press Ctrl+C to stop.")
CFRunLoopRun()

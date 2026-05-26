import Cocoa
import CoreGraphics
import CoreAudio
import AVFoundation

class MediaKeyInterceptor {
    static let shared = MediaKeyInterceptor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private init() { }
    
    func start() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        if !isTrusted {
            print("WARNING: Accessibility permissions are not granted. The MediaKeyInterceptor will not work.")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permissions Required"
                alert.informativeText = "NotchApp needs Accessibility permissions to intercept media keys. Please enable it in System Settings > Privacy & Security > Accessibility."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        
        let NX_SYSDEFINED: UInt32 = 14
        
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap, // Active tap to ensure we get the event before OS consumes it
            eventsOfInterest: CGEventMask(1 << NX_SYSDEFINED),
            callback: { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? in
                
                let NX_SYSDEFINED: UInt32 = 14
                if type.rawValue == NX_SYSDEFINED, let refcon = refcon {
                    let mySelf = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                    let consumed = mySelf.handleSystemDefinedEvent(event)
                    
                    // If we successfully consumed a volume/brightness key, we return nil
                    // to completely block macOS from seeing it, killing the Apple default square HUD.
                    if consumed {
                        return nil
                    }
                }
                
                // Allow all other keys to pass through normally
                return Unmanaged.passUnretained(event)
            },
            userInfo: pointer
        ) else {
            print("Failed to create event tap. Make sure app has Accessibility permissions.")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Failed to Bind Keyboard"
                alert.informativeText = "macOS denied the CGEventTap. If Accessibility is already ON, you MUST delete NotchApp using the minus (-) button and re-add it to reset the signature."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "I Understand")
                alert.runModal()
            }
            return
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = self.runLoopSource {
            CFRunLoopAddSource(RunLoop.main.getCFRunLoop(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func handleSystemDefinedEvent(_ event: CGEvent) -> Bool {
        guard let nsevent = NSEvent(cgEvent: event) else { return false }
        
        let data1 = nsevent.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = (data1 & 0x0000FFFF)
        let isKeyDown = ((keyFlags & 0xFF00) >> 8) == 0xA
        
        guard isKeyDown else { return false } // Only trigger on key down
        
        let NX_KEYTYPE_SOUND_UP: Int32 = 0
        let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
        let NX_KEYTYPE_MUTE: Int32 = 7
        let NX_KEYTYPE_BRIGHTNESS_UP: Int32 = 2
        let NX_KEYTYPE_BRIGHTNESS_DOWN: Int32 = 3
        
        switch Int32(keyCode) {
        case NX_KEYTYPE_SOUND_UP:
            let newVol = min(getSystemVolume() + 0.0625, 1.0)
            setSystemVolume(newVol)
            DispatchQueue.main.async {
                HUDState.shared.showHUD(type: .volume, value: newVol)
            }
            return true
            
        case NX_KEYTYPE_SOUND_DOWN:
            let newVol = max(getSystemVolume() - 0.0625, 0.0)
            setSystemVolume(newVol)
            DispatchQueue.main.async {
                HUDState.shared.showHUD(type: .volume, value: newVol)
            }
            return true
            
        case NX_KEYTYPE_BRIGHTNESS_UP:
            let newBright = min(getSystemBrightness() + 0.0625, 1.0)
            setSystemBrightness(newBright)
            DispatchQueue.main.async {
                HUDState.shared.showHUD(type: .brightness, value: newBright)
            }
            return true
            
        case NX_KEYTYPE_BRIGHTNESS_DOWN:
            let newBright = max(getSystemBrightness() - 0.0625, 0.0)
            setSystemBrightness(newBright)
            DispatchQueue.main.async {
                HUDState.shared.showHUD(type: .brightness, value: newBright)
            }
            return true
            
        case NX_KEYTYPE_MUTE:
            let newVol: Float = getSystemVolume() > 0 ? 0.0 : 0.5
            setSystemVolume(newVol)
            DispatchQueue.main.async {
                HUDState.shared.showHUD(type: .volume, value: newVol)
            }
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - Hardware Control
    
    private func getSystemVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var getDefaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &getDefaultOutputDevicePropertyAddress,
            0,
            nil,
            &defaultOutputDeviceIDSize,
            &defaultOutputDeviceID
        )
        
        guard result == noErr else { return 0.5 }
        
        var volume: Float32 = 0.0
        var volumeSize = UInt32(MemoryLayout<Float32>.size)
        var volumePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &volumePropertyAddress,
            0,
            nil,
            &volumeSize,
            &volume
        )
        
        return volume
    }

    private func setSystemVolume(_ volume: Float) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &defaultOutputDeviceIDSize, &defaultOutputDeviceID) == noErr else { return }
        
        var volumePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var newVolume: Float32 = volume
        let volumeSize = UInt32(MemoryLayout<Float32>.size)
        
        AudioObjectSetPropertyData(defaultOutputDeviceID, &volumePropertyAddress, 0, nil, volumeSize, &newVolume)
    }
    
    private func getSystemBrightness() -> Float {
        let display = CGMainDisplayID()
        var brightness: Float = 0.0
        
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
        if let handle = handle, let sym = dlsym(handle, "DisplayServicesGetBrightness") {
            typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int
            let getBrightness = unsafeBitCast(sym, to: GetBrightnessFunc.self)
            _ = getBrightness(display, &brightness)
            dlclose(handle)
        }
        
        return brightness
    }
    
    private func setSystemBrightness(_ brightness: Float) {
        let display = CGMainDisplayID()
        
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
        if let handle = handle, let sym = dlsym(handle, "DisplayServicesSetBrightness") {
            typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int
            let setBrightness = unsafeBitCast(sym, to: SetBrightnessFunc.self)
            _ = setBrightness(display, brightness)
            dlclose(handle)
        }
    }
}

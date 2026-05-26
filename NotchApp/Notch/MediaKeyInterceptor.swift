import Cocoa
import CoreGraphics
import CoreAudio
import AudioToolbox
import IOKit

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
            // You could potentially show an NSAlert here as well
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
                    mySelf.handleSystemDefinedEvent(event)
                }
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: pointer
        ) else {
            print("Failed to create event tap. Make sure app has Accessibility permissions.")
            return
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = self.runLoopSource {
            CFRunLoopAddSource(RunLoop.main.getCFRunLoop(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func handleSystemDefinedEvent(_ event: CGEvent) {
        guard let nsevent = NSEvent(cgEvent: event) else { return }
        
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
            let key = Int(keyCode)
            if key == NX_KEYTYPE_SOUND_UP || key == NX_KEYTYPE_SOUND_DOWN || key == NX_KEYTYPE_MUTE {
                // Wait a tiny bit for the OS to actually apply the volume change before reading it
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let vol = self.getSystemVolume()
                    HUDState.shared.showHUD(type: .volume, value: vol)
                }
            } else if key == NX_KEYTYPE_BRIGHTNESS_UP || key == NX_KEYTYPE_BRIGHTNESS_DOWN {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let br = self.getSystemBrightness()
                    HUDState.shared.showHUD(type: .brightness, value: br)
                }
            }
        }
    }
    
    private func getSystemVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var getDefaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &getDefaultOutputDevicePropertyAddress, 0, nil, &defaultOutputDeviceIDSize, &defaultOutputDeviceID)
        
        var volumePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var volume: Float32 = 0.0
        var volumeSize = UInt32(MemoryLayout.size(ofValue: volume))
        
        let status = AudioObjectGetPropertyData(defaultOutputDeviceID, &volumePropertyAddress, 0, nil, &volumeSize, &volume)
        if status != noErr {
            // Fallback if unable to read (e.g. external DAC)
            return 0.5
        }
        
        return volume
    }
    
    private func getSystemBrightness() -> Float {
        let kIODisplayBrightnessKey = "brightness"
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
        
        if result == kIOReturnSuccess {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var brightness: Float = 0.0
                let status = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
                IOObjectRelease(service)
                if status == kIOReturnSuccess {
                    return brightness
                }
                service = IOIteratorNext(iterator)
            }
        }
        return 0.5 // Default fallback if not supported (e.g. external monitor)
    }
}

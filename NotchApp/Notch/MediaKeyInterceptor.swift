import Cocoa
import CoreAudio
import AudioToolbox
import IOKit

class MediaKeyInterceptor {
    static let shared = MediaKeyInterceptor()
    
    private var globalEventMonitor: Any?
    
    private init() { }
    
    func start() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.handleSystemDefinedEvent(event)
        }
        
        // Also listen to local events if the app is focused
        NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.handleSystemDefinedEvent(event)
            return event
        }
    }
    
    private func handleSystemDefinedEvent(_ event: NSEvent) {
        let data1 = event.data1
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

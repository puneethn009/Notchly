import Foundation
import IOKit.ps

let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
for ps in sources {
    let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as! [String: Any]
    if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
        print("Capacity: \(capacity)")
    }
    if let charging = info[kIOPSIsChargingKey] as? Bool {
        print("Charging: \(charging)")
    }
    if let state = info[kIOPSPowerSourceStateKey] as? String {
        print("State: \(state)")
    }
}

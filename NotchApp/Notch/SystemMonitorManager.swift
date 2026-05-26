import Foundation
import Combine
import IOKit.ps

class SystemMonitorManager: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var ramUsage: Double = 0
    @Published var gpuUsage: Double = 0
    @Published var uploadSpeed: String = "0 Kb/s"
    @Published var downloadSpeed: String = "0 Kb/s"
    @Published var diskUsage: Double = 0
    @Published var diskText: String = "0/0 GB"
    @Published var batteryHealth: Int = 100
    @Published var batteryCycles: Int = 0
    @Published var thermalPressure: String = "Nominal"
    
    private var timer: AnyCancellable?
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    
    init() {
        start()
    }
    
    func start() {
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStats()
            }
    }
    
    private func updateStats() {
        cpuUsage = getCPUUsage()
        ramUsage = getMemoryUsage()
        gpuUsage = getGPUUsage()
        updateNetworkSpeeds()
        updateDiskUsage()
        updateThermalPressure()
        updateBatteryHealth()
    }
    
    private func getCPUUsage() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        let user = Double(cpuInfo.cpu_ticks.0)
        let system = Double(cpuInfo.cpu_ticks.1)
        let idle = Double(cpuInfo.cpu_ticks.2)
        let total = user + system + idle
        
        return (user + system) / total
    }
    
    private func getMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        let free = Double(stats.free_count)
        let active = Double(stats.active_count)
        let inactive = Double(stats.inactive_count)
        let wire = Double(stats.wire_count)
        let total = free + active + inactive + wire
        
        return (active + wire) / total
    }
    
    private func getGPUUsage() -> Double {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
        if result != KERN_SUCCESS { return 0 }
        
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                if let usage = stats["Device Utilization %"] as? Int {
                    IOObjectRelease(service)
                    return Double(usage) / 100.0
                } else if let usage = stats["Utilization %"] as? Int {
                    IOObjectRelease(service)
                    return Double(usage) / 100.0
                }
            }
            let nextService = IOIteratorNext(iterator)
            IOObjectRelease(service)
            service = nextService
        }
        return 0
    }
    
    private func updateDiskUsage() {
        let fileManager = FileManager.default
        let path = NSHomeDirectory()
        
        do {
            let values = try fileManager.attributesOfFileSystem(forPath: path)
            if let total = values[.systemSize] as? Int64,
               let free = values[.systemFreeSize] as? Int64 {
                let used = total - free
                diskUsage = Double(used) / Double(total)
                
                let usedGB = used / (1024 * 1024 * 1024)
                let totalGB = total / (1024 * 1024 * 1024)
                diskText = "\(usedGB)/\(totalGB) GB"
            }
        } catch {
            print("Error disk usage: \(error)")
        }
    }
    
    private func updateThermalPressure() {
        let level = ProcessInfo.processInfo.thermalState
        switch level {
        case .nominal: thermalPressure = "Nominal"
        case .fair: thermalPressure = "Fair"
        case .serious: thermalPressure = "Serious"
        case .critical: thermalPressure = "Critical"
        @unknown default: thermalPressure = "Unknown"
        }
    }
    
    private func updateBatteryHealth() {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"), &iterator)
        if result == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            var service = IOIteratorNext(iterator)
            while service != 0 {
                if let cycleCount = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                    batteryCycles = cycleCount
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
        }
    }
    
    private func updateNetworkSpeeds() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            
            if let addrPtr = interface.ifa_addr {
                let addr = addrPtr.pointee
                
                if addr.sa_family == UInt8(AF_LINK) {
                    let name = String(cString: interface.ifa_name)
                    // Ignore local loopback, AWDL, and bridge interfaces
                    if !name.hasPrefix("lo") && !name.hasPrefix("awdl") && !name.hasPrefix("bridge") {
                        if let dataPtr = interface.ifa_data {
                            let data = dataPtr.assumingMemoryBound(to: if_data.self)
                            totalIn += UInt64(data.pointee.ifi_ibytes)
                            totalOut += UInt64(data.pointee.ifi_obytes)
                        }
                    }
                }
            }
            ptr = interface.ifa_next
        }
        
        if lastBytesIn > 0 {
            // Guard against overflow/wrap-around
            let diffIn = totalIn >= lastBytesIn ? totalIn - lastBytesIn : 0
            let diffOut = totalOut >= lastBytesOut ? totalOut - lastBytesOut : 0
            downloadSpeed = formatSpeed(diffIn / 2) // 2 sec interval
            uploadSpeed = formatSpeed(diffOut / 2)
        }
        
        lastBytesIn = totalIn
        lastBytesOut = totalOut
    }
    
    private func formatSpeed(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb > 1024 {
            return String(format: "%.1f Mb/s", kb / 1024.0)
        }
        return String(format: "%.0f Kb/s", kb)
    }
}

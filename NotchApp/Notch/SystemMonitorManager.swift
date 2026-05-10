import Foundation
import Combine

class SystemMonitorManager: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var ramUsage: Double = 0
    @Published var uploadSpeed: String = "0 Kb/s"
    @Published var downloadSpeed: String = "0 Kb/s"
    
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
        updateNetworkSpeeds()
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
    
    private func updateNetworkSpeeds() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let addr = interface.ifa_addr.pointee
            
            if addr.sa_family == UInt8(AF_LINK) {
                let data = interface.ifa_data.assumingMemoryBound(to: if_data.self)
                totalIn += UInt64(data.pointee.ifi_ibytes)
                totalOut += UInt64(data.pointee.ifi_obytes)
            }
            ptr = interface.ifa_next
        }
        
        if lastBytesIn > 0 {
            let diffIn = totalIn - lastBytesIn
            let diffOut = totalOut - lastBytesOut
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

import Foundation
import IOKit

/// Utilisation GPU (0–100 %) lue dans les statistiques des accélérateurs graphiques.
enum GPUUsage {
    static func read() -> Int? {
        var it: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &it) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(it) }
        var best: Int?
        while case let svc = IOIteratorNext(it), svc != 0 {
            defer { IOObjectRelease(svc) }
            guard let p = IORegistryEntryCreateCFProperty(svc, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
                  let v = (p["Device Utilization %"] as? NSNumber)?.intValue else { continue }
            best = max(best ?? 0, v)
        }
        return best.map { min(100, max(0, $0)) }
    }
}

/// Swap utilisé et alloué, en Go (fichiers d'échange sur le SSD interne).
enum SwapUsage {
    static func read() -> (usedGB: Double, totalGB: Double)? {
        var x = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &x, &size, nil, 0) == 0 else { return nil }
        let gb = 1_073_741_824.0
        return (Double(x.xsu_used) / gb, Double(x.xsu_total) / gb)
    }
}

/// Mémoire vive utilisée (comme le Moniteur d'activité : app + câblée + compressée).
enum RAMUsage {
    static func read() -> (percent: Int, usedGB: Double, totalGB: Double)? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard r == KERN_SUCCESS else { return nil }
        let page = Double(vm_kernel_page_size)
        let used = Double(UInt64(stats.internal_page_count) - UInt64(stats.purgeable_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let gb = 1_073_741_824.0
        return (min(100, Int((used / total * 100).rounded())), used / gb, total / gb)
    }
}

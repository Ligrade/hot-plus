import Foundation

/// Charge CPU globale (0–100 %), calculée entre deux lectures des compteurs du noyau.
final class CPUUsage {
    private var last: (busy: UInt64, total: UInt64)?

    func read() -> Int? {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)) }

        var busy: UInt64 = 0, total: UInt64 = 0
        let stride = Int(CPU_STATE_MAX)
        for i in 0..<Int(count) {
            let u = UInt64(info[i * stride + Int(CPU_STATE_USER)])
            let s = UInt64(info[i * stride + Int(CPU_STATE_SYSTEM)])
            let n = UInt64(info[i * stride + Int(CPU_STATE_NICE)])
            let idle = UInt64(info[i * stride + Int(CPU_STATE_IDLE)])
            busy += u + s + n
            total += u + s + n + idle
        }
        defer { last = (busy, total) }
        guard let p = last, total > p.total else { return nil }
        let pct = Double(busy &- p.busy) / Double(total - p.total) * 100
        return min(100, max(0, Int(pct.rounded())))
    }
}

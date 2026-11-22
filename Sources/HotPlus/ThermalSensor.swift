import Foundation
import IOKit

/// Température lue sans sudo.
/// - Apple Silicon : capteurs HID privés (page 0xff00, usage 5) → « PMU tdie* » (SoC/CPU).
/// - Intel : SMC (AppleSMC) → TC0P / TC0D / TCXC…
/// - Sinon : `nil` (l'app retombe sur la pression thermique seule).
struct Reading {
    var max: Double
    var average: Double
}

final class ThermalSensor {
    static let isAppleSilicon: Bool = {
        var v: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &v, &size, nil, 0) == 0 && v == 1
    }()

    private var hidClient: CFTypeRef?
    private var smc: SMCReader?

    init() {
        if Self.isAppleSilicon {
            if let c = IOHIDEventSystemClientCreate(kCFAllocatorDefault)?.takeRetainedValue() {
                let match: [String: Int] = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5]
                _ = IOHIDEventSystemClientSetMatching(c, match as CFDictionary)
                hidClient = c
            }
        } else {
            smc = SMCReader()
        }
    }

    func read() -> Reading? {
        let values = Self.isAppleSilicon ? readHID() : readSMC()
        let ok = values.filter { $0 > 5 && $0 < 150 }
        guard let m = ok.max() else { return nil }
        return Reading(max: m, average: ok.reduce(0, +) / Double(ok.count))
    }

    private func readHID() -> [Double] {
        guard let client = hidClient,
              let list = IOHIDEventSystemClientCopyServices(client)?.takeRetainedValue() as [AnyObject]?
        else { return [] }
        var out: [Double] = []
        for s in list {
            guard let name = IOHIDServiceClientCopyProperty(s, "Product" as CFString)?
                .takeRetainedValue() as? String, name.contains("tdie") else { continue }
            if let e = IOHIDServiceClientCopyEvent(s, 15, 0, 0)?.takeRetainedValue() {
                out.append(IOHIDEventGetFloatValue(e, 15 << 16))
            }
        }
        return out
    }

    private func readSMC() -> [Double] {
        guard let smc else { return [] }
        return ["TC0P", "TC0D", "TC0E", "TC0F", "TCXC", "TC1C", "TC2C", "TC3C", "TC4C"]
            .compactMap { smc.temperature($0) }
    }
}

// MARK: - API HID privées (IOKit)

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ a: CFAllocator?) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ c: CFTypeRef, _ m: CFDictionary) -> Int32
@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ c: CFTypeRef) -> Unmanaged<CFArray>?
@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ s: CFTypeRef, _ k: CFString) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ s: CFTypeRef, _ t: Int64, _ o: Int32, _ o2: Int64) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ e: CFTypeRef, _ f: Int32) -> Double

// MARK: - SMC (Intel)

private struct SMCVersion { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0; var release: UInt16 = 0 }
private struct SMCPLimit { var version: UInt16 = 0, length: UInt16 = 0; var cpu: UInt32 = 0, gpu: UInt32 = 0, mem: UInt32 = 0 }
private struct SMCKeyInfo { var dataSize: UInt32 = 0; var dataType: UInt32 = 0; var dataAttributes: UInt8 = 0 }
private typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                              UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                              UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                              UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
private struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimit = SMCPLimit()
    var keyInfo = SMCKeyInfo()
    var result: UInt8 = 0, status: UInt8 = 0, data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

private final class SMCReader {
    private var conn: io_connect_t = 0

    init?() {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard svc != 0 else { return nil }
        defer { IOObjectRelease(svc) }
        guard IOServiceOpen(svc, mach_task_self_, 0, &conn) == kIOReturnSuccess else { return nil }
    }
    deinit { if conn != 0 { IOServiceClose(conn) } }

    private func call(_ input: inout SMCKeyData) -> SMCKeyData? {
        var out = SMCKeyData()
        var outSize = MemoryLayout<SMCKeyData>.stride
        let r = IOConnectCallStructMethod(conn, 2, &input, MemoryLayout<SMCKeyData>.stride, &out, &outSize)
        return r == kIOReturnSuccess && out.result == 0 ? out : nil
    }

    func temperature(_ key: String) -> Double? {
        let k = key.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        var inp = SMCKeyData(); inp.key = k; inp.data8 = 9
        guard let info = call(&inp) else { return nil }
        var rd = SMCKeyData(); rd.key = k; rd.keyInfo.dataSize = info.keyInfo.dataSize; rd.data8 = 5
        guard let o = call(&rd) else { return nil }
        let b = withUnsafeBytes(of: o.bytes) { Array($0) }
        switch info.keyInfo.dataType {
        case 0x73703738: // "sp78"
            return Double(Int16(bitPattern: UInt16(b[0]) << 8 | UInt16(b[1]))) / 256
        case 0x666c7420: // "flt "
            return Double(Float(bitPattern: UInt32(b[3]) << 24 | UInt32(b[2]) << 16 | UInt32(b[1]) << 8 | UInt32(b[0])))
        default: return nil
        }
    }
}

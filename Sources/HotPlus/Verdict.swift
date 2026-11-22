import Foundation

enum Level: Int {
    case normal, warm, hot, critical

    var tip: L { [L.tipNormal, .tipWarm, .tipHot, .tipCritical][rawValue] }
    var label: L { [L.levelNormal, .levelWarm, .levelHot, .levelCritical][rawValue] }

    /// Seuils (°C) sur la température max des capteurs SoC/CPU.
    /// Apple Silicon : tourne couramment 40-70 °C en charge, limite autour de 100-105 °C.
    /// Intel : plus chaud au repos et plafonne vers 100 °C.
    static func from(celsius t: Double) -> Level {
        let (warm, hot, crit): (Double, Double, Double) = ThermalSensor.isAppleSilicon ? (65, 85, 100) : (70, 90, 100)
        if t >= crit { return .critical }
        if t >= hot { return .hot }
        if t >= warm { return .warm }
        return .normal
    }
}

enum Pressure {
    case nominal, fair, serious, critical

    init(_ s: ProcessInfo.ThermalState) {
        switch s {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }
    var tip: L { switch self { case .nominal: return .tipPNominal; case .fair: return .tipPFair; case .serious: return .tipPSerious; case .critical: return .tipPCritical } }
    var label: L { switch self { case .nominal: return .pNominal; case .fair: return .pFair; case .serious: return .pSerious; case .critical: return .pCritical } }
}

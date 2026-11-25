import Foundation
import Combine

/// Lit la température au rythme choisi et suit la pression thermique du système.
final class Monitor: ObservableObject {
    @Published private(set) var reading: Reading?
    @Published private(set) var cpu: Int?
    @Published private(set) var gpu: Int?
    @Published private(set) var ram: (percent: Int, usedGB: Double, totalGB: Double)?
    @Published private(set) var swap: (usedGB: Double, totalGB: Double)?
    @Published private(set) var hog: AppEnergy.Hog?
    /// Charge CPU globale, popover ouvert : même cadence (2 s) et même lissage que le CPU des apps, pour que « restant » colle au Top 5.
    @Published private(set) var liveCPU: Int?
    @Published private(set) var liveWatts: Double?
    @Published private(set) var liveRAM: (percent: Int, usedGB: Double, totalGB: Double)?
    /// Page « Top 5 » affichée dans le popover (nil : page principale). Les valeurs se mettent à jour toutes les 2 s.
    @Published var topPage: AppEnergy.Resource? { didSet { if topPage != oldValue { tops = []; refreshTop() } } }
    @Published private(set) var tops: [AppEnergy.Top] = []
    @Published private(set) var topReady = false
    @Published private(set) var pressure = Pressure(ProcessInfo.processInfo.thermalState)

    private let sensor = ThermalSensor()
    private let cpuUsage = CPUUsage()
    private let liveUsage = CPUUsage()
    private var liveEMA: Double?
    private let energy = AppEnergy()
    private var hogTimer: Timer?

    /// Suivi des apps gourmandes, activé seulement pendant que le popover est ouvert (minuterie dédiée, cadence fixe).
    var watchApps = false {
        didSet {
            guard watchApps != oldValue else { return }
            hogTimer?.invalidate(); hogTimer = nil
            energy.reset()
            hog = nil
            topPage = nil
            liveCPU = nil; liveEMA = nil; liveRAM = nil; liveWatts = nil
            guard watchApps else { return }
            _ = energy.read() // première mesure, la suivante donne l'écart
            _ = liveUsage.read()
            let t = Timer(timeInterval: AppEnergy.interval, repeats: true) { [weak self] _ in self?.updateHog() }
            t.tolerance = 0.2
            RunLoop.main.add(t, forMode: .common)
            hogTimer = t
        }
    }

    private func refreshTop() {
        guard let r = topPage else { return }
        topReady = r == .ram || energy.ready
        let t = energy.top(r)
        if t != tops { tops = t }
    }

    private func updateHog() {
        guard watchApps else { return }
        if let c = liveUsage.read() {
            let e = liveEMA.map { $0 + 0.4 * (Double(c) - $0) } ?? Double(c) // même alpha que AppEnergy
            liveEMA = e; liveCPU = Int(e.rounded())
        }
        liveRAM = RAMUsage.read()
        liveWatts = SystemPower.read()
        let h = energy.read()
        hog = h // valeurs mises à jour toutes les 2 s
        refreshTop()
    }
    private var timer: Timer?
    private var bag = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in self?.pressure = Pressure(ProcessInfo.processInfo.thermalState) }
            .store(in: &bag)
        Settings.shared.$interval.removeDuplicates().sink { [weak self] s in self?.schedule(s) }.store(in: &bag)
    }

    var level: Level? { reading.map { Level.from(celsius: $0.max) } }

    private func schedule(_ seconds: Int) {
        timer?.invalidate()
        refresh()
        let t = Timer(timeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in self?.refresh() }
        t.tolerance = TimeInterval(seconds) * 0.3 // laisse macOS regrouper les réveils
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func refresh() {
        reading = sensor.read()
        cpu = cpuUsage.read() ?? cpu
        gpu = GPUUsage.read()
        ram = RAMUsage.read()
        swap = SwapUsage.read()
    }
}

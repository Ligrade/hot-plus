import Foundation
import Combine

/// Lit la température au rythme choisi et suit la pression thermique du système.
final class Monitor: ObservableObject {
    @Published private(set) var reading: Reading?
    @Published private(set) var cpu: Int?
    @Published private(set) var gpu: Int?
    @Published private(set) var ram: (percent: Int, usedGB: Double, totalGB: Double)?
    @Published private(set) var pressure = Pressure(ProcessInfo.processInfo.thermalState)

    private let sensor = ThermalSensor()
    private let cpuUsage = CPUUsage()
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
    }
}

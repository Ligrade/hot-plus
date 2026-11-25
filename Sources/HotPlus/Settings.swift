import Foundation
import Combine
import ServiceManagement

enum TempUnit: String, CaseIterable { case celsius, fahrenheit }
enum BarStyle: String, CaseIterable { case iconAndTemp, tempOnly, iconOnly }
enum AppLanguage: String, CaseIterable { case system, en, fr }

let appVersion = "1.2"
let repoURL = URL(string: "https://github.com/Ligrade/hot-plus")!

final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var unit: TempUnit { didSet { d.set(unit.rawValue, forKey: "unit") } }
    @Published var barStyle: BarStyle { didSet { d.set(barStyle.rawValue, forKey: "barStyle") } }
    @Published var interval: Int { didSet { d.set(interval, forKey: "interval") } }
    @Published var language: AppLanguage { didSet { d.set(language.rawValue, forKey: "language") } }
    @Published var showSwap: Bool { didSet { d.set(showSwap, forKey: "showSwap") } } // désactivé par défaut
    @Published var launchAtLogin: Bool
    @Published var loginMessage: L?

    private init() {
        unit = TempUnit(rawValue: d.string(forKey: "unit") ?? "") ?? .celsius
        barStyle = BarStyle(rawValue: d.string(forKey: "barStyle") ?? "") ?? .iconAndTemp
        let i = d.integer(forKey: "interval")
        interval = [1, 3, 5, 10].contains(i) ? i : 3
        language = AppLanguage(rawValue: d.string(forKey: "language") ?? "") ?? .system
        showSwap = d.bool(forKey: "showSwap")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ on: Bool) {
        loginMessage = nil
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("HotPlus: launch at login failed: \(error)")
            let inApps = Bundle.main.bundlePath.hasPrefix("/Applications/")
            loginMessage = on ? (inApps ? .loginError : .loginNeedsApplications) : .loginError
        }
        let st = SMAppService.mainApp.status
        if on && st == .requiresApproval { loginMessage = .loginNeedsApproval }
        launchAtLogin = st == .enabled
    }

    var lang: String {
        switch language {
        case .en: return "en"
        case .fr: return "fr"
        case .system: return Locale.preferredLanguages.first?.hasPrefix("fr") == true ? "fr" : "en"
        }
    }

    func t(_ key: L) -> String { key.text(lang) }

    func format(_ celsius: Double) -> String {
        switch unit {
        case .celsius: return "\(Int(celsius.rounded()))°C"
        case .fahrenheit: return "\(Int((celsius * 9 / 5 + 32).rounded()))°F"
        }
    }
}

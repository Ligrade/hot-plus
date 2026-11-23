import Foundation

/// Textes localisés (EN/FR), résolus à l'exécution pour permettre le changement de langue à chaud.
enum L {
    case about, settings, quit
    case temperature, verdict, pressure, noSensor, noSensorHint
    case levelNormal, levelWarm, levelHot, levelCritical
    case pNominal, pFair, pSerious, pCritical
    case unit, interval, launchAtLogin, language, langSystem
    case seconds(Int)
    case aboutText, openSource, byline, github
    case barStyle, barIconTemp, barTempOnly, barIconOnly
    case settingsTitle, aboutTitle
    case loginNeedsApplications, loginNeedsApproval, loginError
    case tipNormal, tipWarm, tipHot, tipCritical
    case tipPNominal, tipPFair, tipPSerious, tipPCritical
    case usage, cpu, gpu, ram
    case appHog(String), appHogTool(String, String), gigabytes
    case topSubtitle, live, remaining, measuring, nothingToShow, cpuCaption, ramCaption
    case sectionDisplay, sectionGeneral, sourceHint

    func text(_ l: String) -> String {
        let fr = l == "fr"
        switch self {
        case .about: return fr ? "À propos de Hot +" : "About Hot +"
        case .settings: return fr ? "Réglages…" : "Settings…"
        case .quit: return fr ? "Quitter" : "Quit"
        case .temperature: return fr ? "Température" : "Temperature"
        case .verdict: return fr ? "Verdict" : "Verdict"
        case .pressure: return fr ? "Pression thermique" : "Thermal pressure"
        case .noSensor: return fr ? "Indisponible" : "Unavailable"
        case .noSensorHint: return fr ? "Capteurs illisibles sur ce Mac : seule la pression thermique est affichée."
                                      : "Sensors unreadable on this Mac: only thermal pressure is shown."
        case .levelNormal: return fr ? "Normale" : "Normal"
        case .levelWarm: return fr ? "Tiède" : "Warm"
        case .levelHot: return fr ? "Chaud" : "Hot"
        case .levelCritical: return fr ? "Critique" : "Critical"
        case .pNominal: return fr ? "Nominale" : "Nominal"
        case .pFair: return fr ? "Modérée" : "Fair"
        case .pSerious: return fr ? "Élevée" : "Serious"
        case .pCritical: return fr ? "Critique" : "Critical"
        case .unit: return fr ? "Unité" : "Unit"
        case .interval: return fr ? "Rafraîchissement" : "Refresh rate"
        case .launchAtLogin: return fr ? "Lancer au démarrage" : "Launch at login"
        case .language: return fr ? "Langue" : "Language"
        case .langSystem: return fr ? "Système" : "System"
        case .seconds(let n): return "\(n) s"
        case .aboutText: return fr ? "Hot + surveille la température de votre Mac depuis la barre de menus et vous dit s'il chauffe."
                                   : "Hot + watches your Mac's temperature from the menu bar and tells you if it's running hot."
        case .openSource: return fr ? "Version open source, libre d'utilisation (free for use)."
                                    : "Open-source version, free for use."
        case .byline: return "v\(appVersion) · By Ligrade"
        case .github: return fr ? "Voir sur GitHub" : "View on GitHub"
        case .loginNeedsApplications: return fr ? "Placez l'app dans Applications, puis réessayez." : "Move the app to Applications, then try again."
        case .loginNeedsApproval: return fr ? "Approuvez Hot + dans Réglages Système > Éléments de connexion." : "Approve Hot + in System Settings > Login Items."
        case .loginError: return fr ? "Impossible de modifier le lancement au démarrage." : "Couldn't change launch at login."
        case .barStyle: return fr ? "Affichage dans la barre de menus" : "Menu bar display"
        case .barIconTemp: return fr ? "Icône + température" : "Icon + temperature"
        case .barTempOnly: return fr ? "Température seule" : "Temperature only"
        case .barIconOnly: return fr ? "Icône seule" : "Icon only"
        case .settingsTitle: return fr ? "Réglages de Hot +" : "Hot + Settings"
        case .aboutTitle: return fr ? "À propos de Hot +" : "About Hot +"
        case .tipNormal: return fr ? "Tout va bien, votre Mac est au frais." : "All good, your Mac is running cool."
        case .tipWarm: return fr ? "Ça chauffe un peu, rien d'inquiétant." : "Getting warm, nothing to worry about."
        case .tipHot: return fr ? "Il chauffe : allégez la charge si possible." : "Running hot: ease the workload if you can."
        case .tipCritical: return fr ? "Trop chaud : fermez les apps lourdes." : "Too hot: close heavy apps."
        case .tipPNominal: return fr ? "Aucun ralentissement." : "No throttling."
        case .tipPFair: return fr ? "Le système commence à s'adapter." : "The system is starting to adapt."
        case .tipPSerious: return fr ? "Performances réduites pour refroidir." : "Performance reduced to cool down."
        case .tipPCritical: return fr ? "Ralentissement maximal du Mac." : "Maximum slowdown in effect."
        case .usage: return fr ? "Utilisation" : "Usage"
        case .topSubtitle: return fr ? "Les 5 apps qui en utilisent le plus" : "The 5 apps using the most"
        case .live: return fr ? "En direct" : "Live"
        case .remaining: return fr ? "restant" : "left"
        case .cpuCaption: return fr ? "En % de tout le processeur, mis à jour toutes les 2 s." : "As % of the whole processor, updated every 2 s."
        case .ramCaption: return fr ? "Mémoire de chaque app et de ses processus, mise à jour toutes les 2 s." : "Memory of each app and its processes, updated every 2 s."
        case .measuring: return fr ? "Mesure en cours…" : "Measuring…"
        case .nothingToShow: return fr ? "Rien à signaler" : "Nothing to show"
        case .gigabytes: return fr ? "Go" : "GB"
        case .appHog(let n): return fr ? "\(n) consomme beaucoup en ce moment." : "\(n) is using a lot of energy right now."
        case .appHogTool(let t, let a): return fr ? "\(t) (dans \(a)) consomme beaucoup en ce moment." : "\(t) (in \(a)) is using a lot of energy right now."
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .ram: return fr ? "RAM" : "RAM"
        case .sectionDisplay: return fr ? "Affichage" : "Display"
        case .sectionGeneral: return fr ? "Général" : "General"
        case .sourceHint: return fr ? "Mesure : capteurs du SoC/CPU, sans droits administrateur." : "Source: SoC/CPU sensors, no admin rights needed."
        }
    }
}

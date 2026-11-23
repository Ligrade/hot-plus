import AppKit
import Darwin

/// Repère l'application qui consomme le plus d'énergie en ce moment.
/// Source principale : les « coalitions » du noyau, le même regroupement que l'onglet Énergie du Moniteur d'activité
/// (une app, ses XPC et helpers, et les processus qu'elle lance, même déjà terminés). Énergie CPU (pondérée cœurs P/E),
/// GPU et ANE, plus un petit coût par réveil. Secours : temps CPU par processus si l'API privée disparaît.
/// Ne tourne que pendant que le popover est ouvert, pour rester léger.
final class AppEnergy {
    struct Hog: Equatable {
        let name: String   // app hôte
        let tool: String?  // outil réel lancé dedans (terminal, IDE), ex. « Claude Code »
        let pid: pid_t     // app hôte, pour l'icône
        var watts: Double  // estimation lissée, hors égalité : la valeur bouge sans cesse
        var cpu: Int = 0       // % de tout le processeur (comme la ligne CPU), lissé
        var gpu: Int? = nil    // % du GPU, lissé (nil sans coalitions)
        var ramGB: Double? = nil // mémoire de l'app et de ses processus
        static func == (a: Hog, b: Hog) -> Bool { a.pid == b.pid && a.name == b.name && a.tool == b.tool }
    }

    /// Nombre de cœurs : les % d'un cœur sont divisés par ce nombre pour être sur la même base que la ligne CPU.
    static let cores = Double(max(1, ProcessInfo.processInfo.activeProcessorCount))
    /// Cadence de mesure, popover ouvert.
    static let interval: TimeInterval = 2
    /// Seuils en mW, avec hystérésis. `yes` sur un cœur P ≈ 5 W ; 40 % d'un cœur ≈ 1,5 W (calibré sur un Mac M).
    static let enterMW = 1500.0, exitMW = 900.0
    /// Secours sans coalitions : 1 % d'un cœur ≈ 37,5 mW, pour garder les mêmes seuils.
    private static let mWPerCorePercent = 37.5
    /// Lissage (moyenne glissante exponentielle) : l'énergie GPU arrive par paquets.
    private static let alpha = 0.4
    /// Apps où l'on nomme l'outil réel qui tourne dedans.
    private static let hosts: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.zed.Zed", "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92" /* Cursor */, "dev.warp.Warp-Stable", "com.mitchellh.ghostty",
        "com.anthropic.claudefordesktop",
    ]
    private static let shells: Set<String> = ["zsh", "bash", "sh", "fish", "login", "disclaimer", "tmux", "screen", "sudo", "env", "nohup"]

    private let log = ProcessInfo.processInfo.environment["HOTPLUS_LOG"] != nil
    private let timebase: Double = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return Double(tb.numer) / Double(tb.denom)
    }()
    private typealias CRU = @convention(c) (UInt64, UnsafeMutableRawPointer, Int) -> Int32
    private let cru: CRU? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "coalition_info_resource_usage").map { unsafeBitCast($0, to: CRU.self) }
    private var layoutOK = true
    private typealias RespFn = @convention(c) (pid_t) -> pid_t
    private let responsible: RespFn? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid").map { unsafeBitCast($0, to: RespFn.self) }

    private struct Coal { let nJ, wakeups, cpu, gpuNs: UInt64 }
    private struct Proc { let cpu, nJ, start: UInt64 }
    private var lastCoal: [UInt64: Coal] = [:]   // par coalition
    private var lastProc: [pid_t: Proc] = [:]    // par processus (secours)
    private var lastTime: UInt64 = 0
    private var ema: [pid_t: Double] = [:]       // mW lissés, par app
    private var use: [pid_t: (cpu: Double, gpu: Double?)] = [:] // % bruts de la mesure, par app
    private var useEMA: [pid_t: (cpu: Double, gpu: Double?)] = [:] // % lissés, par app
    private var lastToolProc: [pid_t: Proc] = [:] // par processus, dans les apps hôtes
    private var toolEMA: [pid_t: [String: Double]] = [:] // mW lissés, par app hôte puis par outil
    private var toolCache: [pid_t: (start: UInt64, tool: String?)] = [:]
    private var shown: Hog?
    private var streak: (pid: pid_t, n: Int)?

    func reset() {
        lastCoal = [:]; lastProc = [:]; lastToolProc = [:]; lastTime = 0
        ema = [:]; use = [:]; useEMA = [:]; toolEMA = [:]; toolCache = [:]; shown = nil; streak = nil
    }

    /// Fait une mesure et renvoie l'app à signaler (nil sous le seuil ou à la première lecture).
    func read() -> Hog? {
        let now = mach_absolute_time()
        let me = getpid()
        var apps: [pid_t: NSRunningApplication] = [:]
        for a in NSWorkspace.shared.runningApplications where a.activationPolicy != .prohibited && a.processIdentifier > 0 && a.processIdentifier != me {
            apps[a.processIdentifier] = a
        }
        let elapsed = lastTime > 0 && now > lastTime ? Double(now - lastTime) * timebase : 0 // ns
        defer { lastTime = now }

        // mW par app sur l'intervalle (coalitions, sinon secours par processus).
        var perApp: [pid_t: Double] = [:]
        var detail: [pid_t: String] = [:]
        use = [:]
        if let coal = coalitionPass(apps: apps, elapsed: elapsed, detail: &detail) {
            perApp = coal
        } else {
            perApp = fallbackPass(apps: apps, elapsed: elapsed, me: me)
        }
        toolPass(apps: apps, elapsed: elapsed, me: me)
        guard elapsed > 0 else { return nil }

        // Une app absente de la mesure (inactive, coalition non lue) compte 0 : sinon sa dernière valeur resterait figée.
        for pid in Set(ema.keys).union(perApp.keys) {
            let mW = perApp[pid] ?? 0
            ema[pid] = ema[pid].map { $0 + Self.alpha * (mW - $0) } ?? mW
        }
        ema = ema.filter { apps[$0.key] != nil }
        for pid in Set(useEMA.keys).union(use.keys) {
            let u = use[pid] ?? (0, useEMA[pid]?.gpu == nil ? nil : 0)
            let o = useEMA[pid] ?? u
            let gpu = u.gpu.map { g in (o.gpu ?? g) + Self.alpha * (g - (o.gpu ?? g)) }
            useEMA[pid] = (o.cpu + Self.alpha * (u.cpu - o.cpu), gpu)
        }
        useEMA = useEMA.filter { apps[$0.key] != nil }
        guard let top = ema.max(by: { $0.value < $1.value }), let app = apps[top.key] else { return nil }

        // Outil réel dans un terminal ou un IDE.
        let tool = mainTool(of: top.key, keep: shown?.pid == top.key ? shown?.tool : nil)

        // Hystérésis : 2 mesures au-dessus du seuil pour apparaître (1 si très net), sous le seuil bas pour disparaître.
        streak = top.value >= Self.enterMW ? (top.key, streak?.pid == top.key ? streak!.n + 1 : 1) : nil
        var candidate = Hog(name: app.localizedName ?? "?", tool: tool, pid: top.key, watts: top.value / 1000)
        if let u = useEMA[top.key] {
            candidate.cpu = Int((u.cpu / Self.cores).rounded())
            candidate.gpu = u.gpu.map { Int(min(100, $0).rounded()) }
        }
        if let s = shown, let e = ema[s.pid], e >= Self.exitMW, apps[s.pid] != nil {
            // On garde l'app signalée, sauf si une autre la dépasse nettement.
            if top.key != s.pid, top.value > e * 1.5, (streak?.n ?? 0) >= 2 { shown = candidate }
            else if top.key == s.pid { shown = candidate } else {
                shown?.watts = e / 1000
                if let u = useEMA[s.pid] { shown?.cpu = Int((u.cpu / Self.cores).rounded()); shown?.gpu = u.gpu.map { Int(min(100, $0).rounded()) } }
            }
        } else if let st = streak, st.n >= 2 || top.value >= 2 * Self.enterMW {
            shown = candidate
        } else {
            shown = nil
        }

        // Mémoire : seulement pour l'app affichée (une passe sur les processus).
        if let s = shown { shown?.ramGB = ram(of: s.pid) }

        if log {
            let raw = perApp[top.key] ?? 0
            let toolText = tool.map { " [\($0)]" } ?? ""
            let d = detail[top.key].map { " " + $0 } ?? ""
            print(String(format: "hog: %@%@ %.2f W (lissé %.2f W)%@ → %@", candidate.name, toolText, raw / 1000, top.value / 1000, d,
                         shown.map { "affiché : \($0.tool ?? $0.name)" } ?? "rien")); fflush(stdout)
        }
        return shown
    }

    // MARK: Coalitions

    /// mW par app (clé : pid de l'app). nil si l'API des coalitions est indisponible.
    private func coalitionPass(apps: [pid_t: NSRunningApplication], elapsed: Double, detail: inout [pid_t: String]) -> [pid_t: Double]? {
        guard cru != nil, layoutOK else { return nil }
        var out: [pid_t: Double] = [:], seen: [UInt64: Coal] = [:]
        // Les apps « regular » d'abord : si une coalition est partagée, c'est elle qui la représente.
        // Ordre stable (puis par pid) : la même app représente toujours une coalition partagée.
        let sorted = apps.values.sorted {
            let r0 = $0.activationPolicy == .regular ? 0 : 1, r1 = $1.activationPolicy == .regular ? 0 : 1
            return r0 != r1 ? r0 < r1 : $0.processIdentifier < $1.processIdentifier
        }
        for a in sorted {
            guard let cid = Self.coalitionID(a.processIdentifier), seen[cid] == nil else { continue }
            guard let s = sample(cid) else {
                if layoutOK { continue } // coalition disparue (app qui quitte) : on l'ignore
                return nil // mise en page inattendue : secours
            }
            seen[cid] = s
            guard elapsed > 0, let p = lastCoal[cid] else { continue }
            // Compteurs censés croître : un recul donnerait un écart géant par débordement, on le compte 0.
            let dE = s.nJ >= p.nJ ? s.nJ - p.nJ : 0, dW = s.wakeups >= p.wakeups ? s.wakeups - p.wakeups : 0
            let mW = Double(dE) / elapsed * 1000 + 0.2 * Double(dW) / elapsed * 1e9
            out[a.processIdentifier] = mW
            let cpu = Double(s.cpu >= p.cpu ? s.cpu - p.cpu : 0) * timebase / elapsed * 100
            let gpu = Double(s.gpuNs >= p.gpuNs ? s.gpuNs - p.gpuNs : 0) / elapsed * 100
            use[a.processIdentifier] = (cpu, gpu)
            if log { detail[a.processIdentifier] = String(format: "CPU %.0f %% GPU %.0f %%", cpu, gpu) }
        }
        lastCoal = seen
        return out
    }

    private static func coalitionID(_ pid: pid_t) -> UInt64? {
        var buf = (UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0)) // proc_pidcoalitioninfo, 40 octets
        let r = withUnsafeMutableBytes(of: &buf) { proc_pidinfo(pid, 20 /* PROC_PIDCOALITIONINFO */, 0, $0.baseAddress, 40) }
        return r == 40 && buf.0 > 1 ? buf.0 : nil // [0] = coalition « resource » ; 1 = launchd et les démons, ignorée
    }

    private func sample(_ cid: UInt64) -> Coal? {
        guard let cru else { return nil }
        var u = [UInt64](repeating: 0, count: 128) // tampon large : le noyau copie min(taille, sizeof)
        guard u.withUnsafeMutableBytes({ cru(cid, $0.baseAddress!, $0.count) }) == 0 else { return nil }
        guard u[23] == 7 else { layoutOK = false; return nil } // garde-fou de mise en page : sinon secours définitif
        // [11] énergie CPU, [41] GPU, [39] ANE (nJ) ; [4]+[5] réveils ; [3] temps CPU (ticks mach) ; [8] temps GPU (ns)
        return Coal(nJ: u[11] &+ u[41] &+ u[39], wakeups: u[4] &+ u[5], cpu: u[3], gpuNs: u[8])
    }

    // MARK: Processus

    /// Écart d'un processus depuis la mesure précédente (temps CPU en ticks mach, énergie en nJ).
    /// Un processus né entre deux mesures compte en entier ; un pid réutilisé est traité comme neuf.
    private func procDelta(_ pid: pid_t, last: [pid_t: Proc], into next: inout [pid_t: Proc]) -> (cpu: UInt64, nJ: UInt64)? {
        var info = rusage_info_v6()
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V6, $0) }
        }
        guard r == 0 else { return nil }
        let s = Proc(cpu: info.ri_user_time + info.ri_system_time, nJ: info.ri_energy_nj, start: info.ri_proc_start_abstime)
        next[pid] = s
        if let p = last[pid], p.start == s.start { return (s.cpu &- min(p.cpu, s.cpu), s.nJ &- min(p.nJ, s.nJ)) }
        return lastTime > 0 && s.start > lastTime ? (s.cpu, s.nJ) : nil
    }

    /// Secours : temps CPU par processus, regroupé par app, converti en mW équivalents.
    private func fallbackPass(apps: [pid_t: NSRunningApplication], elapsed: Double, me: pid_t) -> [pid_t: Double] {
        var next: [pid_t: Proc] = [:], out: [pid_t: Double] = [:]
        for pid in Self.allPids() where pid > 0 && pid != me {
            guard let d = procDelta(pid, last: lastProc, into: &next), elapsed > 0, d.cpu > 0, let owner = owner(of: pid, apps: apps) else { continue }
            let pct = Double(d.cpu) * timebase / elapsed * 100
            out[owner, default: 0] += pct * Self.mWPerCorePercent
            use[owner] = ((use[owner]?.cpu ?? 0) + pct, nil)
        }
        lastProc = next
        return out
    }

    /// Pour chaque app hôte (terminal, IDE) : mW par outil lancé dedans, en un seul passage sur les processus.
    private func toolPass(apps: [pid_t: NSRunningApplication], elapsed: Double, me: pid_t) {
        var hostOf: [UInt64: NSRunningApplication] = [:]
        for a in apps.values where a.bundleIdentifier.map(Self.hosts.contains) ?? false {
            if let cid = Self.coalitionID(a.processIdentifier) { hostOf[cid] = a }
        }
        var next: [pid_t: Proc] = [:], perTool: [pid_t: [String: Double]] = [:]
        if !hostOf.isEmpty {
            for pid in Self.allPids() where pid > 0 && pid != me {
                guard let cid = Self.coalitionID(pid), let host = hostOf[cid], let d = procDelta(pid, last: lastToolProc, into: &next), elapsed > 0 else { continue }
                let t = tool(of: pid, host: host, start: next[pid]!.start) ?? ""
                perTool[host.processIdentifier, default: [:]][t, default: 0] += Double(d.nJ) / elapsed * 1000
            }
        }
        lastToolProc = next
        toolCache = toolCache.filter { next[$0.key] != nil }
        guard elapsed > 0 else { return }
        toolEMA = toolEMA.filter { perTool[$0.key] != nil }
        for (host, tools) in perTool {
            var e = toolEMA[host] ?? [:]
            for k in e.keys where tools[k] == nil { e[k]! *= 1 - Self.alpha }
            for (t, mW) in tools { e[t] = e[t].map { $0 + Self.alpha * (mW - $0) } ?? mW }
            toolEMA[host] = e
        }
    }

    /// Outil qui pèse plus de la moitié de l'app hôte (un tiers suffit pour garder celui déjà affiché).
    private func mainTool(of host: pid_t, keep: String?) -> String? {
        guard let e = toolEMA[host] else { return nil }
        let total = e.values.reduce(0, +)
        if let k = keep, let v = e[k], v > total / 3 { return k }
        guard let best = e.max(by: { $0.value < $1.value }), !best.key.isEmpty, best.value > total / 2 else { return nil }
        return best.key
    }

    /// Ancêtre le plus haut qui n'est ni un shell ni dans le bundle de l'app hôte (mis en cache par processus).
    private func tool(of pid: pid_t, host: NSRunningApplication, start: UInt64) -> String? {
        if let c = toolCache[pid], c.start == start { return c.tool }
        let bundle = (host.bundleURL?.path ?? "/nonexistent") + "/"
        var best: String?, p = pid, followed = false
        for _ in 0..<12 {
            guard p > 1, p != host.processIdentifier else { break }
            let path = Self.path(p), name = (path as NSString).lastPathComponent
            if !path.isEmpty, !path.hasPrefix(bundle), !Self.shells.contains(name) { best = Self.displayName(p, path: path) }
            var next = Self.ppid(p)
            // Orphelin (rattaché à launchd) : on suit le processus que macOS désigne comme responsable.
            if next <= 1, !followed, let r = responsible?(p), r > 1, r != p { next = r; followed = true }
            p = next
        }
        toolCache[pid] = (start, best)
        return best
    }

    private static func displayName(_ pid: pid_t, path: String) -> String {
        let name = (path as NSString).lastPathComponent
        if name == "claude" || path.contains("claude-code") { return "Claude Code" }
        if name == "node", args(pid).contains("claude-code") { return "Claude Code" }
        if let r = path.range(of: ".app/Contents/") { return (String(path[..<r.lowerBound]) as NSString).lastPathComponent }
        return name
    }

    /// App « responsable » du processus (secours) : elle-même, celle désignée par macOS, ou un ancêtre.
    private func owner(of pid: pid_t, apps: [pid_t: NSRunningApplication]) -> pid_t? {
        if apps[pid] != nil { return pid }
        var p = pid
        if let r = responsible?(pid), r > 0, r != pid {
            if apps[r] != nil { return r }
            p = r // responsable hors app (outil en ligne de commande) : on remonte à partir de lui
        }
        for _ in 0..<8 {
            p = Self.ppid(p)
            if p <= 1 { return nil }
            if apps[p] != nil { return p }
        }
        return nil
    }

    // MARK: Top 5

    enum Resource { case cpu, ram }
    var ready: Bool { lastTime > 0 && !useEMA.isEmpty }
    struct Top: Identifiable, Equatable { let pid: pid_t; let name: String; let value: Double; var id: pid_t { pid } }

    /// Les apps qui consomment le plus une ressource. CPU : % de tout le processeur, moyenne lissée des dernières mesures
    /// (vide pendant les 2 premières secondes). RAM : lue à la demande, en Go.
    func top(_ r: Resource, count: Int = 5) -> [Top] {
        let me = getpid()
        var apps: [pid_t: NSRunningApplication] = [:]
        for a in NSWorkspace.shared.runningApplications where a.activationPolicy != .prohibited && a.processIdentifier > 0 && a.processIdentifier != me {
            apps[a.processIdentifier] = a
        }
        let values: [pid_t: Double]
        switch r {
        case .cpu: values = useEMA.mapValues { $0.cpu }
        case .ram: values = ramByApp(apps: apps)
        }
        let minimum = r == .ram ? 0.01 : 0.5 // on écarte ce qui ne consomme rien
        let scale = r == .cpu ? Self.cores : 1
        return values.filter { $0.value >= minimum && apps[$0.key] != nil }
            .sorted { $0.value > $1.value }.prefix(count)
            .map { Top(pid: $0.key, name: apps[$0.key]?.localizedName ?? "?", value: $0.value / scale) }
    }

    /// Mémoire par app en Go : chaque processus compte pour l'app de sa coalition (ou son app responsable en secours).
    private func ramByApp(apps: [pid_t: NSRunningApplication]) -> [pid_t: Double] {
        var appOf: [UInt64: pid_t] = [:]
        if cru != nil, layoutOK {
            // Même règle que la mesure d'énergie : apps « regular » d'abord, puis par pid.
            let sorted = apps.values.sorted {
                let r0 = $0.activationPolicy == .regular ? 0 : 1, r1 = $1.activationPolicy == .regular ? 0 : 1
                return r0 != r1 ? r0 < r1 : $0.processIdentifier < $1.processIdentifier
            }
            for a in sorted { if let cid = Self.coalitionID(a.processIdentifier), appOf[cid] == nil { appOf[cid] = a.processIdentifier } }
        }
        var out: [pid_t: Double] = [:]
        for pid in Self.allPids() where pid > 0 {
            let owner: pid_t?
            if apps[pid] != nil { owner = pid }
            else if !appOf.isEmpty { owner = Self.coalitionID(pid).flatMap { appOf[$0] } }
            else { owner = self.owner(of: pid, apps: apps) }
            guard let owner else { continue }
            var info = rusage_info_v6()
            let r = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V6, $0) }
            }
            if r == 0 { out[owner, default: 0] += Double(info.ri_phys_footprint) / 1_073_741_824 }
        }
        return out
    }

    /// Mémoire (empreinte physique, comme le Moniteur d'activité) de l'app et des processus de sa coalition, en Go.
    private func ram(of app: pid_t) -> Double? {
        var bytes: UInt64 = 0
        let cid = Self.coalitionID(app)
        for pid in Self.allPids() where pid > 0 {
            guard pid == app || (cid != nil && Self.coalitionID(pid) == cid) else { continue }
            var info = rusage_info_v6()
            let r = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V6, $0) }
            }
            if r == 0 { bytes &+= info.ri_phys_footprint }
        }
        return bytes > 0 ? Double(bytes) / 1_073_741_824 : nil
    }

    // MARK: Utilitaires

    private static func ppid(_ pid: pid_t) -> pid_t {
        var bsd = proc_bsdinfo()
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 ? pid_t(bsd.pbi_ppid) : 0
    }

    private static func path(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 4096)
        return proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 ? String(cString: buf) : ""
    }

    /// Ligne de commande (pour reconnaître un script node).
    private static func args(_ pid: pid_t) -> String {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid], size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buf = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buf, &size, nil, 0) == 0 else { return "" }
        return String(decoding: buf.prefix(min(size, 8192)).map { $0 == 0 ? 32 : $0 }, as: UTF8.self)
    }

    private static func allPids() -> [pid_t] {
        let n = proc_listallpids(nil, 0)
        guard n > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(n) + 64)
        let got = pids.withUnsafeMutableBufferPointer { proc_listallpids($0.baseAddress, Int32($0.count * MemoryLayout<pid_t>.size)) }
        return Array(pids.prefix(Int(max(0, got))))
    }
}

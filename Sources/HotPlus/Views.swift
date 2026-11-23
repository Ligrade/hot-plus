import SwiftUI

extension Level {
    var color: Color { [Color.green, .yellow, .orange, .red][rawValue] }
}

extension Pressure {
    var color: Color {
        switch self { case .nominal: return .green; case .fair: return .yellow; default: return .red }
    }
}

struct FlameLogo: View {
    var body: some View {
        if let img = NSApp.applicationIconImage { Image(nsImage: img).resizable().interpolation(.high) }
    }
}

/// Barre de température : dégradé vert → rouge, curseur à la position courante (20–110 °C).
struct TempGauge: View {
    let celsius: Double?
    var body: some View {
        GeometryReader { geo in
            let f = celsius.map { min(max(($0 - 20) / 90, 0), 1) }
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [.green, .yellow, .orange, .red], startPoint: .leading, endPoint: .trailing))
                    .opacity(f == nil ? 0.25 : 1)
                    .frame(height: 8)
                if let f {
                    Circle().fill(.white).frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: f * (geo.size.width - 16))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.4), value: celsius)
    }
}

struct UsageRow: View {
    let label: String
    let percent: Int?
    var detail: String? = nil
    var onTap: (() -> Void)? = nil
    @State private var hover = false

    private var row: some View {
        HStack(spacing: 10) {
            Text(label).font(.caption.weight(.semibold)).frame(width: 34, alignment: .leading)
            ProgressView(value: Double(percent ?? 0), total: 100).tint(percent.map { $0 >= 90 ? .red : $0 >= 70 ? .orange : .accentColor } ?? .gray)
            Text(percent.map { "\($0)%" } ?? "—").font(.caption).monospacedDigit().frame(width: 36, alignment: .trailing)
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                .opacity(onTap == nil ? 0 : hover ? 1 : 0.5)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    row
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(hover ? 0.07 : 0)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hover = $0 }
            } else {
                row
            }
        }
        .padding(.horizontal, -6)
        .help(detail ?? "")
    }
}

/// Page « Top 5 » qui glisse à la place de la page principale : les apps qui utilisent le plus le CPU ou la RAM, en direct.
struct TopPage: View {
    @ObservedObject var monitor: Monitor
    let resource: AppEnergy.Resource
    let back: () -> Void
    @ObservedObject var s = Settings.shared
    @State private var pulse = false

    private var free: String? {
        switch resource {
        case .cpu: return monitor.cpu.map { "\(max(0, 100 - $0)) %" }
        case .ram: return monitor.ram.map { "\(max(0, $0.totalGB - $0.usedGB).formatted(.number.precision(.fractionLength(1)))) \(s.t(.gigabytes))" }
        }
    }

    private func value(_ t: AppEnergy.Top) -> String {
        switch resource {
        case .cpu: return t.value < 0.5 ? "<1 %" : "\(Int(t.value.rounded())) %"
        case .ram: return "\(t.value.formatted(.number.precision(.fractionLength(1)))) \(s.t(.gigabytes))"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: back) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    Text(s.t(.usage))
                }
                .font(.callout).foregroundStyle(Color.accentColor).contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.t(resource == .cpu ? .cpu : .ram)).font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text(s.t(.topSubtitle)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 6, height: 6).opacity(pulse ? 1 : 0.35)
                        Text(s.t(.live)).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    // Capacité qui reste : CPU libre en %, RAM disponible en Go.
                    if let free {
                        Text(free).font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text(s.t(.remaining)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            if monitor.tops.isEmpty {
                HStack(spacing: 8) {
                    if !monitor.topReady { ProgressView().controlSize(.small) }
                    Text(s.t(monitor.topReady ? .nothingToShow : .measuring)).font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            } else {
                let lead = max(monitor.tops.first?.value ?? 1, 0.001)
                VStack(spacing: 4) {
                    ForEach(monitor.tops) { t in
                        TopRow(top: t, value: value(t), fraction: t.value / lead)
                    }
                }
            }

            Spacer(minLength: 0)
            Text(s.t(resource == .cpu ? .cpuCaption : .ramCaption)).font(.caption2).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeOut(duration: 0.35), value: monitor.tops)
        .onAppear { withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

/// Une app du Top 5 : icône, nom, barre relative au premier, valeur (pas d'action au clic pour l'instant).
struct TopRow: View {
    let top: AppEnergy.Top
    let value: String
    let fraction: Double

    var body: some View {
            HStack(spacing: 10) {
                if let icon = NSRunningApplication(processIdentifier: top.pid)?.icon {
                    Image(nsImage: icon).resizable().frame(width: 24, height: 24)
                } else {
                    RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.2)).frame(width: 24, height: 24)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(top.name).font(.callout).lineLimit(1)
                        Spacer(minLength: 6)
                        Text(value).font(.callout.weight(.medium)).monospacedDigit()
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule().fill(Color.accentColor).frame(width: max(3, g.size.width * min(1, fraction)))
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(.vertical, 5)
    }
}

/// Petit signalement discret : l'app la plus gourmande du moment.
struct HogNote: View {
    let hog: AppEnergy.Hog
    let text: String
    let lang: String
    @State private var pulse = false

    /// Une mesure ; en orange quand c'est elle qui pèse.
    private func metric(_ label: String, _ value: String, hot: Bool) -> some View {
        HStack(spacing: 3) {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit().fontWeight(hot ? .semibold : .regular).foregroundStyle(hot ? Color.orange : .primary)
        }
        .font(.caption2)
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon = NSRunningApplication(processIdentifier: hog.pid)?.icon {
                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
            } else {
                Image(systemName: "bolt.fill").foregroundStyle(.orange).frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(text).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Circle().fill(Color.green).frame(width: 5, height: 5).opacity(pulse ? 1 : 0.3)
                        .help(L.live.text(lang))
                    metric("CPU", hog.cpu < 1 ? "<1 %" : "\(hog.cpu) %", hot: Double(hog.cpu) * AppEnergy.cores >= 50) // ≥ la moitié d'un cœur
                    if let g = hog.gpu { metric("GPU", "\(g) %", hot: g >= 30) }
                    if let r = hog.ramGB {
                        metric(L.ram.text(lang), "\(r.formatted(.number.precision(.fractionLength(1)))) \(L.gigabytes.text(lang))", hot: r >= 4)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.orange.opacity(0.12)))
        .help("≈ \(hog.watts.formatted(.number.precision(.fractionLength(1)))) W")
        .onAppear { withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

struct PopoverView: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject var s = Settings.shared

    private func open(_ r: AppEnergy.Resource?) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) { monitor.topPage = r }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            main
                .offset(x: monitor.topPage == nil ? 0 : -300)
                .opacity(monitor.topPage == nil ? 1 : 0)
            if let r = monitor.topPage {
                TopPage(monitor: monitor, resource: r) { open(nil) }
                    .padding(20)
                    .frame(width: 300).frame(maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .trailing))
            }
        }
        .frame(width: 300)
        .clipped()
    }

    private var main: some View {
        let level = monitor.level
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: level?.icon(size: 56) ?? monitor.pressure.icon(size: 56)).resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(monitor.reading.map { s.format($0.max) } ?? "—")
                        .font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text(level.map { s.t($0.label) } ?? s.t(.noSensor))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(level?.color ?? .secondary)
                }
                Spacer(minLength: 0)
            }

            if monitor.reading != nil {
                VStack(alignment: .leading, spacing: 8) {
                    TempGauge(celsius: monitor.reading?.max)
                    if let level { Text(s.t(level.tip)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
            } else {
                Text(s.t(.noSensorHint)).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(s.t(.usage)).font(.caption).foregroundStyle(.secondary)
                UsageRow(label: s.t(.cpu), percent: monitor.cpu) { open(.cpu) }
                UsageRow(label: s.t(.ram), percent: monitor.ram?.percent,
                         detail: monitor.ram.map { String(format: "%.1f / %.0f GB", $0.usedGB, $0.totalGB) }) { open(.ram) }
                UsageRow(label: s.t(.gpu), percent: monitor.gpu)
            }

            Divider()

            HStack(alignment: .top, spacing: 10) {
                Image(nsImage: monitor.pressure.icon(size: 40)).resizable().frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.t(.pressure)).font(.caption).foregroundStyle(.secondary)
                    Text(s.t(monitor.pressure.label)).font(.headline)
                    Text(s.t(monitor.pressure.tip)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if let hog = monitor.hog {
                HogNote(hog: hog, text: s.t(hog.tool.map { .appHogTool($0, hog.name) } ?? .appHog(hog.name)), lang: s.lang)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: monitor.hog?.id)
        .padding(20).frame(width: 300)
    }
}

struct SettingsView: View {
    @ObservedObject var s = Settings.shared

    var body: some View {
        Form {
            Section(s.t(.sectionDisplay)) {
                Picker(s.t(.unit), selection: $s.unit) {
                    Text("°C").tag(TempUnit.celsius)
                    Text("°F").tag(TempUnit.fahrenheit)
                }.pickerStyle(.segmented)
                Picker(s.t(.barStyle), selection: $s.barStyle) {
                    Text(s.t(.barIconTemp)).tag(BarStyle.iconAndTemp)
                    Text(s.t(.barTempOnly)).tag(BarStyle.tempOnly)
                    Text(s.t(.barIconOnly)).tag(BarStyle.iconOnly)
                }
                Picker(s.t(.interval), selection: $s.interval) {
                    ForEach([1, 3, 5, 10], id: \.self) { Text(L.seconds($0).text(s.lang)).tag($0) }
                }.pickerStyle(.segmented)
            }
            Section(s.t(.sectionGeneral)) {
                Picker(s.t(.language), selection: $s.language) {
                    Text(s.t(.langSystem)).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.en)
                    Text("Français").tag(AppLanguage.fr)
                }
                Toggle(s.t(.launchAtLogin), isOn: Binding(get: { s.launchAtLogin }, set: { s.setLaunchAtLogin($0) }))
                if let m = s.loginMessage { Text(s.t(m)).font(.caption).foregroundStyle(.orange) }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .safeAreaInset(edge: .bottom) {
            Text(s.t(.sourceHint)).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.bottom, 12).padding(.horizontal, 20)
        }
    }
}

struct AboutView: View {
    @ObservedObject var s = Settings.shared

    var body: some View {
        VStack(spacing: 6) {
            FlameLogo().frame(width: 112, height: 112)
            Text("Hot +").font(.system(size: 28, weight: .bold, design: .rounded)).padding(.top, 4)
            Text(s.t(.byline)).font(.callout).foregroundStyle(.secondary)
            Text(s.t(.aboutText)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            Text(s.t(.openSource)).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Link(s.t(.github), destination: repoURL).padding(.top, 10)
        }
        .padding(.horizontal, 32).padding(.vertical, 28).frame(width: 360)
    }
}

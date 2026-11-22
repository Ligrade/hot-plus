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
    var body: some View {
        HStack(spacing: 10) {
            Text(label).font(.caption.weight(.semibold)).frame(width: 34, alignment: .leading)
            ProgressView(value: Double(percent ?? 0), total: 100).tint(percent.map { $0 >= 90 ? .red : $0 >= 70 ? .orange : .accentColor } ?? .gray)
            Text(percent.map { "\($0)%" } ?? "—").font(.caption).monospacedDigit().frame(width: 36, alignment: .trailing)
        }
        .help(detail ?? "")
    }
}

struct PopoverView: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject var s = Settings.shared

    var body: some View {
        let level = monitor.level
        VStack(alignment: .leading, spacing: 16) {
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
                UsageRow(label: s.t(.cpu), percent: monitor.cpu)
                UsageRow(label: s.t(.gpu), percent: monitor.gpu)
                UsageRow(label: s.t(.ram), percent: monitor.ram?.percent,
                         detail: monitor.ram.map { String(format: "%.1f / %.0f GB", $0.usedGB, $0.totalGB) })
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
        }
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

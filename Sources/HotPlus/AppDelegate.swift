import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = Monitor()
    private let settings = Settings.shared
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = item.button {
            b.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            b.target = self
            b.action = #selector(clicked)
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor))

        monitor.objectWillChange.merge(with: settings.objectWillChange)
            .receive(on: DispatchQueue.main) // après la mise à jour des valeurs
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &bag)
        updateTitle()

        if ProcessInfo.processInfo.environment["HOTPLUS_APPEARANCE"] == "light" { NSApp.appearance = NSAppearance(named: .aqua) }
        // Aide aux captures : HOTPLUS_OPEN=popover|about|settings ouvre directement la fenêtre.
        if let o = ProcessInfo.processInfo.environment["HOTPLUS_OPEN"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                switch o {
                case "about": self?.showAbout()
                case "settings": self?.showSettings()
                default: if let b = self?.item.button { self?.clicked(b) }
                }
            }
        }

        settings.$language.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.settingsWindow?.title = self?.settings.t(.settingsTitle) ?? ""
            self?.aboutWindow?.title = self?.settings.t(.aboutTitle) ?? ""
        }.store(in: &bag)
    }

    private func updateTitle() {
        guard let b = item.button else { return }
        let value: String, icon: NSImage
        if let r = monitor.reading, let l = monitor.level {
            value = settings.format(r.max)
            icon = l.icon(size: 18)
        } else {
            value = "—"
            icon = monitor.pressure.icon(size: 18)
        }
        let text: String
        switch settings.barStyle {
        case .iconAndTemp: text = " " + value; b.image = icon; b.imagePosition = .imageLeft
        case .tempOnly: text = value; b.image = nil; b.imagePosition = .noImage
        case .iconOnly: text = ""; b.image = icon; b.imagePosition = .imageOnly
        }
        if b.title != text { b.title = text }
        if ProcessInfo.processInfo.environment["HOTPLUS_LOG"] != nil { print("mode: \(settings.barStyle.rawValue) title: '\(text)' image: \(b.image != nil)"); fflush(stdout) }
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(nil)
            let menu = NSMenu()
            menu.addItem(withTitle: settings.t(.about), action: #selector(showAbout), keyEquivalent: "").target = self
            menu.addItem(withTitle: settings.t(.settings), action: #selector(showSettings), keyEquivalent: ",").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: settings.t(.quit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            item.menu = menu
            sender.performClick(nil)
            item.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func showSettings() {
        settingsWindow = show(settingsWindow, title: settings.t(.settingsTitle), view: SettingsView())
    }

    @objc private func showAbout() {
        aboutWindow = show(aboutWindow, title: settings.t(.aboutTitle), view: AboutView())
    }

    private func show<V: View>(_ existing: NSWindow?, title: String, view: V) -> NSWindow {
        let w = existing ?? {
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            return w
        }()
        w.title = title
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        return w
    }
}

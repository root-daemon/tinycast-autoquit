import SwiftUI

struct AutoQuitScreen: PaletteScreen {
    let coordinator: AutoQuitCoordinator
    let vm: PaletteState

    var rows: [AutoQuitPaletteItem] {
        var rows: [AutoQuitPaletteItem] = []
        if vm.query.isEmpty {
            rows.append(
                .init(
                    id: "toggle", title: "Auto Quit", subtitle: "Returning to an app resets its countdown",
                    trailing: coordinator.store.enabled ? "On" : "Paused", symbol: "timer", action: .toggle))
        }
        var previousConfigured: Bool?
        for app in coordinator.applications(for: vm.query) {
            let configured = app.minutes != nil
            let section =
                configured != previousConfigured
                ? (configured ? "Configured Applications" : "Add Applications") : nil
            rows.append(
                .init(
                    id: app.id, title: app.name,
                    subtitle: configured
                        ? "Quit after time in the background" : "Choose a delay to add this app",
                    trailing: app.minutes.map { "\($0) min" } ?? "Not configured", symbol: "app",
                    appURL: app.url, section: section, action: .edit(app.bundleID)))
            previousConfigured = configured
        }
        return rows
    }

    var primaryActionTitle: String {
        guard let row = row(at: vm.selection) else { return "Choose Delay" }
        if case .toggle = row.action {
            return coordinator.store.enabled ? "Pause Auto Quit" : "Enable Auto Quit"
        }
        return "Choose Delay"
    }

    private func row(at selection: Int) -> AutoQuitPaletteItem? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    func activate(at selection: Int) {
        guard let row = row(at: selection) else { return }
        activate(row)
    }

    private func activate(_ row: AutoQuitPaletteItem) {
        switch row.action {
        case .toggle: coordinator.setEnabled(!coordinator.store.enabled)
        case .edit(let bundleID): coordinator.edit(bundleID: bundleID)
        default: break
        }
    }

    func secondary(at selection: Int) -> Bool { false }
    func tab(at selection: Int, backwards: Bool) -> Bool { true }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let row = row(at: selection) else { return nil }
        var items: [PopoverMenuItem] = []
        if case .edit(let bundleID) = row.action {
            items.append(
                .init(title: "Choose Delay…", systemImage: "timer", shortcut: "↵") {
                    coordinator.edit(bundleID: bundleID)
                })
            items += AutoQuitDelay.presets.map { minutes in
                PopoverMenuItem(title: "\(minutes) minutes", systemImage: "clock") {
                    configure(minutes: minutes, bundleID: bundleID)
                }
            }
            items.append(
                .init(title: "Custom Delay…", systemImage: "slider.horizontal.3") {
                    coordinator.edit(bundleID: bundleID, custom: true)
                })
            if coordinator.store.rules.contains(where: { $0.bundleID == bundleID }) {
                items.append(
                    .init(
                        title: "Remove Application", systemImage: "minus.circle", startsSection: true,
                        shortcut: "⌘⌫", isDestructive: true
                    ) {
                        coordinator.remove(bundleID: bundleID)
                        follow(bundleID: bundleID)
                    })
            }
        }
        items.append(
            .init(
                title: coordinator.store.enabled ? "Pause Auto Quit" : "Enable Auto Quit",
                systemImage: coordinator.store.enabled ? "pause.circle" : "play.circle",
                startsSection: !items.isEmpty
            ) {
                coordinator.setEnabled(!coordinator.store.enabled)
            })
        return PopoverMenuContent(header: row.title, items: items)
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard shortcut == .commandDelete, let row = row(at: selection),
            case .edit(let bundleID) = row.action,
            coordinator.store.rules.contains(where: { $0.bundleID == bundleID })
        else { return false }
        coordinator.remove(bundleID: bundleID)
        follow(bundleID: bundleID)
        return true
    }

    private func configure(minutes: Int, bundleID: String) {
        coordinator.configure(minutes: minutes, bundleID: bundleID)
        follow(bundleID: bundleID)
    }

    private func follow(bundleID: String) {
        vm.selection = rows.firstIndex { $0.id == bundleID } ?? 0
        vm.followToken = UUID()
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let rows = rows
        return AnyView(
            Group {
                if rows.isEmpty {
                    EmptyResults(text: "No matching applications")
                } else {
                    AutoQuitPaletteList(
                        rows: rows, selectedID: row(at: selection)?.id, scroll: scroll,
                        onActivate: { row in
                            vm.selection = rows.firstIndex { $0.id == row.id } ?? 0
                            activate(row)
                        })
                }
            })
    }
}

import SwiftUI

struct AutoQuitDelayScreen: PaletteScreen {
    let coordinator: AutoQuitCoordinator
    let vm: PaletteState
    let metrics: InterfaceMetrics

    var rows: [AutoQuitPaletteItem] {
        guard let app = coordinator.editingApplication else { return [] }
        let presets = AutoQuitDelay.presets.map { minutes in
            AutoQuitPaletteItem(
                id: "delay:\(minutes)", title: "\(minutes) minutes",
                subtitle: "Quit \(app.name) after time in the background", trailing: "",
                symbol: "clock", isCurrent: app.minutes == minutes, action: .delay(minutes))
        }
        let choices =
            presets + [
                AutoQuitPaletteItem(
                    id: "custom", title: "Custom delay…", subtitle: "Enter 1–1440 minutes in the field above",
                    trailing: app.minutes.map { AutoQuitDelay.presets.contains($0) ? "" : "\($0) min" } ?? "",
                    symbol: "slider.horizontal.3",
                    isCurrent: app.minutes.map { !AutoQuitDelay.presets.contains($0) } ?? false,
                    action: .custom),
                AutoQuitPaletteItem(
                    id: "off", title: "Don't auto quit this app",
                    subtitle: "Remove \(app.name) from Auto Quit",
                    trailing: "", symbol: "minus.circle", isCurrent: app.minutes == nil, action: .remove)
            ]
        return choices.filter {
            vm.query.isEmpty || FuzzyMatch.match(query: vm.query, candidate: $0.title) != nil
        }
    }

    var primaryActionTitle: String { "Save Delay" }
    var landingSelection: Int {
        if coordinator.prefersCustom { return AutoQuitDelay.presets.count }
        guard let minutes = coordinator.editingApplication?.minutes else { return 2 }
        return AutoQuitDelay.presets.firstIndex(of: minutes) ?? AutoQuitDelay.presets.count
    }

    private func row(at selection: Int) -> AutoQuitPaletteItem? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    private var customMinutes: Int? {
        AutoQuitDelay.minutes(from: vm.commandArguments[coordinator.customArgumentKey] ?? "")
    }

    func activate(at selection: Int) {
        guard let row = row(at: selection) else { return }
        activate(row)
    }

    private func activate(_ row: AutoQuitPaletteItem) {
        switch row.action {
        case .delay(let minutes): coordinator.saveEditing(minutes: minutes)
        case .custom:
            if let customMinutes { coordinator.saveEditing(minutes: customMinutes) }
        case .remove: coordinator.saveEditing(minutes: nil)
        default: break
        }
    }

    func secondary(at selection: Int) -> Bool { false }
    func hasActions(at selection: Int) -> Bool { false }

    func headerAccessory(at selection: Int, focus: FocusState<String?>.Binding) -> PaletteHeaderAccessory? {
        guard let row = row(at: selection), case .custom = row.action else { return nil }
        let key = coordinator.customArgumentKey
        let arguments = [InlineArgument(id: key, title: "Minutes")]
        return PaletteHeaderAccessory(
            width: InlineArgumentFields.totalWidth(for: arguments, hasIcon: false, metrics: metrics),
            fieldNames: [key], firstIncompleteField: customMinutes == nil ? key : nil,
            placement: .besideSearchField,
            view: AnyView(
                InlineArgumentFields(
                    arguments: arguments, symbol: nil,
                    value: { _ in
                        Binding(
                            get: { vm.commandArguments[key] ?? "" }, set: { vm.commandArguments[key] = $0 })
                    },
                    focused: focus, openOptions: { _ in },
                    onSubmit: { if let customMinutes { coordinator.saveEditing(minutes: customMinutes) } })))
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let rows = rows
        return AnyView(
            Group {
                if rows.isEmpty {
                    EmptyResults(text: "No matching delays")
                } else {
                    AutoQuitPaletteList(
                        rows: rows, selectedID: row(at: selection)?.id, scroll: scroll,
                        onActivate: { row in
                            if case .custom = row.action {
                                vm.selection = rows.firstIndex { $0.id == row.id } ?? 0
                            } else {
                                activate(row)
                            }
                        })
                }
            })
    }
}

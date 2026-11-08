import SwiftUI

/// Start or edit a session. The search field holds the goal, so these rows never filter.
struct FocusScreen: PaletteScreen {
    static let minutesKey = "focus:minutes"
    let coordinator: FocusCoordinator
    let vm: PaletteState
    let metrics: InterfaceMetrics

    var rows: [FocusPaletteItem] {
        let draft = coordinator.draft
        let durationSection = String(localized: "Duration")
        var rows: [FocusPaletteItem] = [
            .init(
                id: "submit",
                title: coordinator.isEditingSession
                    ? String(localized: "Update Focus Session") : String(localized: "Start Focus Session"),
                subtitle: vm.query.isEmpty
                    ? String(localized: "Type a goal above, or start without one") : vm.query,
                trailing: FocusSummary.text(for: draft), symbol: "target", action: .submit)
        ]
        for (index, minutes) in FocusTimings.durationPresets.enumerated() {
            rows.append(
                .init(
                    id: "minutes:\(minutes)", title: FocusSummary.duration(minutes), symbol: "clock",
                    section: index == 0 ? durationSection : nil, isCurrent: draft.minutes == minutes,
                    action: .minutes(minutes)))
        }
        let isCustom = draft.minutes.map { !FocusTimings.durationPresets.contains($0) } ?? false
        rows += [
            .init(
                id: "minutes:none", title: String(localized: "No Limit"),
                subtitle: String(localized: "Run until you complete the session"), symbol: "infinity",
                isCurrent: draft.minutes == nil, action: .minutes(nil)),
            .init(
                id: "minutes:custom", title: String(localized: "Custom Duration…"),
                subtitle: String(localized: "Type minutes, or a length like 1h 30m, in the field above"),
                trailing: isCustom ? draft.minutes.map(FocusSummary.duration) ?? "" : "",
                symbol: "slider.horizontal.3", isCurrent: isCustom, action: .customMinutes),
            .init(
                id: "mode:block", title: String(localized: "Block Listed Apps"),
                subtitle: String(localized: "Quit the apps and categories you choose"),
                symbol: "hand.raised", section: String(localized: "Mode"),
                isCurrent: draft.mode == .block, action: .mode(.block)),
            .init(
                id: "mode:allow", title: String(localized: "Allow Only Listed Apps"),
                subtitle: String(localized: "Quit every app except the ones you choose"),
                symbol: "checkmark.shield", isCurrent: draft.mode == .allow, action: .mode(.allow)),
            .init(
                id: "apps", title: String(localized: "Choose Apps & Categories…"),
                subtitle: FocusSummary.list(for: draft), symbol: "square.grid.2x2",
                section: String(localized: "Apps"), action: .apps)
        ]
        return rows
    }

    var primaryActionTitle: String {
        switch row(at: vm.selection)?.action {
        case .submit?:
            return coordinator.isEditingSession
                ? String(localized: "Update Session") : String(localized: "Start Focus")
        case .apps?: return String(localized: "Choose Apps")
        case .customMinutes?: return String(localized: "Set Duration")
        default: return String(localized: "Select")
        }
    }

    private func row(at selection: Int) -> FocusPaletteItem? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    private var customMinutes: Int? {
        FocusConfiguration.minutes(from: vm.commandArguments[Self.minutesKey] ?? "")
    }

    func activate(at selection: Int) {
        guard let row = row(at: selection) else { return }
        activate(row)
    }

    private func activate(_ row: FocusPaletteItem) {
        switch row.action {
        case .submit: coordinator.submit(goal: vm.query)
        case .minutes(let minutes): coordinator.setDraftMinutes(minutes)
        case .customMinutes:
            if let customMinutes { coordinator.setDraftMinutes(customMinutes) }
        case .mode(let mode): coordinator.setDraftMode(mode)
        case .apps: coordinator.showApps()
        default: break
        }
    }

    /// ⌘↵ starts from any row, so choosing a duration never costs a trip back to the top.
    func secondary(at selection: Int) -> Bool {
        coordinator.submit(goal: vm.query)
        return true
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        var items: [PopoverMenuItem] = [
            .init(
                title: coordinator.isEditingSession
                    ? String(localized: "Update Focus Session") : String(localized: "Start Focus Session"),
                systemImage: "target", shortcut: "⌘↵"
            ) { coordinator.submit(goal: vm.query) },
            .init(title: String(localized: "Choose Apps & Categories…"), systemImage: "square.grid.2x2") {
                coordinator.showApps()
            }
        ]
        if coordinator.isEditingSession {
            items.append(
                .init(
                    title: String(localized: "Cancel Focus Session"), systemImage: "xmark.circle",
                    startsSection: true, isDestructive: true
                ) { coordinator.cancelFromCommand() })
        }
        return PopoverMenuContent(header: String(localized: "Focus"), items: items)
    }

    func headerAccessory(at selection: Int, focus: FocusState<String?>.Binding) -> PaletteHeaderAccessory? {
        guard let row = row(at: selection), case .customMinutes = row.action else { return nil }
        let key = Self.minutesKey
        let arguments = [InlineArgument(id: key, title: String(localized: "Minutes"))]
        return PaletteHeaderAccessory(
            width: InlineArgumentFields.totalWidth(for: arguments, hasIcon: false, metrics: metrics),
            fieldNames: [key], firstIncompleteField: customMinutes == nil ? key : nil,
            placement: .besideSearchField,
            view: AnyView(
                InlineArgumentFields(
                    arguments: arguments, symbol: nil,
                    value: { _ in
                        Binding(get: { vm.commandArguments[key] ?? "" }, set: { vm.commandArguments[key] = $0 })
                    },
                    focused: focus, openOptions: { _ in },
                    onSubmit: { if let customMinutes { coordinator.setDraftMinutes(customMinutes) } })))
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let rows = rows
        return AnyView(
            FocusPaletteList(
                rows: rows, selectedID: row(at: selection)?.id, scroll: scroll,
                onActivate: { row in
                    vm.selection = rows.firstIndex { $0.id == row.id } ?? 0
                    if case .customMinutes = row.action { return }
                    activate(row)
                }))
    }
}

/// Picks the apps and categories a session lists; the search field filters here.
struct FocusAppsScreen: PaletteScreen {
    let coordinator: FocusCoordinator
    let vm: PaletteState

    var rows: [FocusPaletteItem] {
        let draft = coordinator.draft
        let query = vm.query
        var rows: [FocusPaletteItem] = []
        let categories = FocusCategory.builtIn.filter {
            query.isEmpty || FuzzyMatch.match(query: query, candidate: $0.name) != nil
        }
        for (index, category) in categories.enumerated() {
            rows.append(
                .init(
                    id: "category:\(category.id)", title: category.name,
                    subtitle: String(localized: "\(category.bundleIDs.count) common apps"),
                    symbol: category.symbol, section: index == 0 ? String(localized: "Categories") : nil,
                    isCurrent: draft.categoryIDs.contains(category.id), action: .category(category.id)))
        }
        let selected = draft.categoryIDs.compactMap(FocusCategory.category(id:))
        var previousListed: Bool?
        for app in coordinator.applications(for: query) {
            let listedSection =
                draft.mode == .block ? String(localized: "Blocked Apps") : String(localized: "Allowed Apps")
            let section =
                app.isListed != previousListed
                ? (app.isListed ? listedSection : String(localized: "Applications")) : nil
            previousListed = app.isListed
            rows.append(
                .init(
                    id: app.id, title: app.name,
                    trailing: selected.first { $0.bundleIDs.contains(app.bundleID) }?.name ?? "",
                    symbol: "app", appURL: app.url, section: section, isCurrent: app.isListed,
                    action: .app(app.bundleID)))
        }
        return rows
    }

    var primaryActionTitle: String {
        guard let row = row(at: vm.selection) else { return String(localized: "Select") }
        return row.isCurrent ? String(localized: "Remove") : String(localized: "Add")
    }

    private func row(at selection: Int) -> FocusPaletteItem? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    func activate(at selection: Int) {
        guard let row = row(at: selection) else { return }
        activate(row)
    }

    private func activate(_ row: FocusPaletteItem) {
        switch row.action {
        case .category(let id): coordinator.toggleDraftCategory(id)
        case .app(let bundleID): coordinator.toggleDraftApp(bundleID)
        default: return
        }
        vm.selection = rows.firstIndex { $0.id == row.id } ?? 0
        vm.followToken = UUID()
    }

    func secondary(at selection: Int) -> Bool { false }
    func hasActions(at selection: Int) -> Bool { false }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let rows = rows
        return AnyView(
            Group {
                if rows.isEmpty {
                    EmptyResults(text: String(localized: "No matching apps or categories"))
                } else {
                    FocusPaletteList(
                        rows: rows, selectedID: row(at: selection)?.id, scroll: scroll,
                        onActivate: activate)
                }
            })
    }
}

/// The break lengths Pause offers; a break ends on its own and resumes the session.
struct FocusBreakScreen: PaletteScreen {
    let coordinator: FocusCoordinator
    let vm: PaletteState

    var rows: [FocusPaletteItem] {
        let rows =
            FocusTimings.breakPresets.map { minutes in
                FocusPaletteItem(
                    id: "break:\(minutes)", title: String(localized: "Take a \(minutes)-Minute Break"),
                    subtitle: String(localized: "Focus resumes on its own afterwards"), symbol: "cup.and.saucer",
                    action: .takeBreak(minutes))
            } + [
                FocusPaletteItem(
                    id: "break:open", title: String(localized: "Pause Until I Resume"),
                    subtitle: String(localized: "Blocking stays off until you resume"), symbol: "pause.circle",
                    action: .takeBreak(nil))
            ]
        return rows.filter { vm.query.isEmpty || FuzzyMatch.match(query: vm.query, candidate: $0.title) != nil }
    }

    var primaryActionTitle: String { String(localized: "Pause Focus") }

    func activate(at selection: Int) {
        let rows = rows
        guard rows.indices.contains(selection), case .takeBreak(let minutes) = rows[selection].action else {
            return
        }
        coordinator.takeBreak(minutes: minutes)
    }

    func secondary(at selection: Int) -> Bool { false }
    func hasActions(at selection: Int) -> Bool { false }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let rows = rows
        return AnyView(
            Group {
                if rows.isEmpty {
                    EmptyResults(text: String(localized: "No matching break lengths"))
                } else {
                    FocusPaletteList(
                        rows: rows, selectedID: rows.indices.contains(selection) ? rows[selection].id : nil,
                        scroll: scroll,
                        onActivate: { row in
                            if case .takeBreak(let minutes) = row.action { coordinator.takeBreak(minutes: minutes) }
                        })
                }
            })
    }
}

enum FocusSummary {
    static func duration(_ minutes: Int) -> String {
        minutes < 60 || minutes % 60 != 0
            ? String(localized: "\(minutes) min") : String(localized: "\(minutes / 60) hr")
    }

    /// `25 min · Block · 3 categories, 2 apps`
    static func text(for configuration: FocusConfiguration) -> String {
        let length = configuration.minutes.map(duration) ?? String(localized: "No limit")
        let mode = configuration.mode == .block ? String(localized: "Block") : String(localized: "Allow")
        return "\(length) · \(mode) · \(list(for: configuration))"
    }

    static func list(for configuration: FocusConfiguration) -> String {
        String(
            localized: "\(configuration.categoryIDs.count) categories, \(configuration.bundleIDs.count) apps")
    }
}

import AppKit
import Observation

@MainActor
@Observable
final class AutoQuitCoordinator {
    let store: AutoQuitStore
    private(set) var editingBundleID: String?
    private(set) var prefersCustom = false
    @ObservationIgnored private let monitor: AutoQuitMonitor
    @ObservationIgnored private let appIndex: AppIndex
    @ObservationIgnored private let palette: PaletteState
    @ObservationIgnored private let paletteCoordinator: PaletteCoordinator

    init(
        store: AutoQuitStore, monitor: AutoQuitMonitor, appIndex: AppIndex,
        palette: PaletteState, paletteCoordinator: PaletteCoordinator
    ) {
        self.store = store
        self.monitor = monitor
        self.appIndex = appIndex
        self.palette = palette
        self.paletteCoordinator = paletteCoordinator
    }

    private var protectedBundleIDs: Set<String> {
        ["com.apple.finder", Bundle.main.bundleIdentifier ?? "com.tinycast.app"]
    }

    var excludedBundleIDs: Set<String> {
        Set(store.rules.map(\.bundleID)).union(protectedBundleIDs)
    }

    var editingApplication: AutoQuitApplication? {
        guard let editingBundleID else { return nil }
        return applications(for: "").first { $0.bundleID == editingBundleID }
    }

    var customArgumentKey: String { "auto-quit:\(editingBundleID ?? ""):minutes" }

    func applications(for query: String) -> [AutoQuitApplication] {
        let entries = appIndex.apps.filter { $0.kind == .application }
        let indexed = entries.reduce(into: [String: AppEntry]()) { result, entry in
            if let bundleID = entry.bundleID, result[bundleID] == nil { result[bundleID] = entry }
        }
        let matches = query.isEmpty ? entries : appIndex.matches(query).filter { $0.kind == .application }
        let matchedIDs = Set(matches.compactMap(\.bundleID))
        var seen = protectedBundleIDs
        var applications: [AutoQuitApplication] = []
        for rule in store.rules {
            guard seen.insert(rule.bundleID).inserted else { continue }
            let entry = indexed[rule.bundleID]
            let url = entry?.url ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleID)
            let name = entry?.name ?? url?.deletingPathExtension().lastPathComponent ?? rule.bundleID
            guard
                query.isEmpty || matchedIDs.contains(rule.bundleID)
                    || FuzzyMatch.match(query: query, candidate: name) != nil
            else { continue }
            applications.append(.init(bundleID: rule.bundleID, name: name, url: url, minutes: rule.minutes))
        }
        for entry in matches {
            guard let bundleID = entry.bundleID, seen.insert(bundleID).inserted else { continue }
            applications.append(.init(bundleID: bundleID, name: entry.name, url: entry.url, minutes: nil))
        }
        return applications
    }

    func show() {
        editingBundleID = nil
        paletteCoordinator.showPalette(mode: .autoQuit)
    }

    func edit(bundleID: String, custom: Bool = false) {
        guard !protectedBundleIDs.contains(bundleID) else { return }
        editingBundleID = bundleID
        prefersCustom = custom
        let minutes = store.rules.first { $0.bundleID == bundleID }?.minutes ?? AutoQuitRule.defaultMinutes
        paletteCoordinator.showPalette(mode: .autoQuitDelay)
        palette.commandArguments[customArgumentKey] = String(minutes)
    }

    func saveEditing(minutes: Int?) {
        guard let editingBundleID else { return }
        if let minutes {
            configure(minutes: minutes, bundleID: editingBundleID)
        } else {
            remove(bundleID: editingBundleID)
        }
        _ = palette.pop()
        if palette.mode == .autoQuit,
            let index = applications(for: palette.query).firstIndex(where: { $0.bundleID == editingBundleID })
        {
            palette.selection = index + (palette.query.isEmpty ? 1 : 0)
            palette.followToken = UUID()
        }
    }

    func applySettings() {
        if store.enabled && !store.rules.isEmpty {
            monitor.start(rules: store.rules)
        } else {
            monitor.stop()
        }
    }

    func setEnabled(_ enabled: Bool) {
        store.enabled = enabled
    }

    func add(bundleID: String) {
        guard !excludedBundleIDs.contains(bundleID) else { return }
        configure(minutes: AutoQuitRule.defaultMinutes, bundleID: bundleID)
    }

    func configure(minutes: Int, bundleID: String) {
        guard AutoQuitRule(bundleID: bundleID, minutes: minutes).isValid,
            !protectedBundleIDs.contains(bundleID)
        else { return }
        if let index = store.rules.firstIndex(where: { $0.bundleID == bundleID }) {
            if store.rules[index].minutes != minutes { store.rules[index].minutes = minutes }
        } else {
            store.rules.append(AutoQuitRule(bundleID: bundleID, minutes: minutes))
        }
    }

    func remove(bundleID: String) {
        guard store.rules.contains(where: { $0.bundleID == bundleID }) else { return }
        store.rules.removeAll { $0.bundleID == bundleID }
    }

    func setMinutes(_ minutes: Int, bundleID: String) {
        guard store.rules.contains(where: { $0.bundleID == bundleID }) else { return }
        configure(minutes: minutes, bundleID: bundleID)
    }
}

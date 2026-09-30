import Foundation
import Observation

@MainActor
@Observable
final class AutoQuitCoordinator {
    let store: AutoQuitStore
    @ObservationIgnored private let monitor: AutoQuitMonitor

    init(store: AutoQuitStore, monitor: AutoQuitMonitor) {
        self.store = store
        self.monitor = monitor
    }

    var excludedBundleIDs: Set<String> {
        Set(store.rules.map(\.bundleID)).union([
            "com.apple.finder", Bundle.main.bundleIdentifier ?? "com.tinycast.app"
        ])
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
        store.rules.append(AutoQuitRule(bundleID: bundleID, minutes: AutoQuitRule.defaultMinutes))
    }

    func remove(bundleID: String) {
        store.rules.removeAll { $0.bundleID == bundleID }
    }

    func setMinutes(_ minutes: Int, bundleID: String) {
        guard AutoQuitRule.minuteRange.contains(minutes),
            let index = store.rules.firstIndex(where: { $0.bundleID == bundleID })
        else { return }
        store.rules[index].minutes = minutes
    }
}

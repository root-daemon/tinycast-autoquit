import Foundation
import Observation

@MainActor
@Observable
final class AutoQuitStore {
    var enabled: Bool {
        didSet { defaults.set(enabled, forKey: AppSettingsKey.autoQuitEnabled.rawValue) }
    }
    var rules: [AutoQuitRule] {
        didSet {
            defaults.set(
                rules.map { ["bundleID": $0.bundleID, "minutes": $0.minutes] },
                forKey: AppSettingsKey.autoQuitRules.rawValue)
        }
    }
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: AppSettingsKey.autoQuitEnabled.rawValue)
        let records = defaults.array(forKey: AppSettingsKey.autoQuitRules.rawValue) as? [[String: Any]] ?? []
        rules = AutoQuitRule.normalized(
            records.compactMap { record in
                guard let bundleID = record["bundleID"] as? String, let minutes = record["minutes"] as? Int
                else { return nil }
                return AutoQuitRule(bundleID: bundleID, minutes: minutes)
            })
    }
}

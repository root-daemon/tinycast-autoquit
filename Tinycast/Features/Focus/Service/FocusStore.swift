import Foundation
import Observation

@MainActor
@Observable
final class FocusStore {
    /// The setup the next session starts from; every start remembers its own.
    var configuration: FocusConfiguration {
        didSet { save(configuration, for: .focusConfiguration) }
    }
    var session: FocusSession? {
        didSet { save(session, for: .focusSession) }
    }
    var snoozeMinutes: Int {
        didSet { defaults.set(snoozeMinutes, forKey: AppSettingsKey.focusSnoozeMinutes.rawValue) }
    }
    var playsSound: Bool {
        didSet { defaults.set(playsSound, forKey: AppSettingsKey.focusPlaysSound.rawValue) }
    }
    var reopensQuitApps: Bool {
        didSet { defaults.set(reopensQuitApps, forKey: AppSettingsKey.focusReopensQuitApps.rawValue) }
    }
    var barPlacement: FocusBarPlacement {
        didSet { defaults.set(barPlacement.rawValue, forKey: AppSettingsKey.focusBarPlacement.rawValue) }
    }
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        configuration =
            Self.load(FocusConfiguration.self, from: defaults, key: .focusConfiguration)?.normalized
            ?? .initial
        session = Self.load(FocusSession.self, from: defaults, key: .focusSession)
        let snooze = defaults.object(forKey: AppSettingsKey.focusSnoozeMinutes.rawValue) as? Int
        snoozeMinutes = Self.validSnooze(snooze) ?? FocusTimings.defaultSnoozeMinutes
        playsSound = defaults.object(forKey: AppSettingsKey.focusPlaysSound.rawValue) as? Bool ?? true
        reopensQuitApps = defaults.bool(forKey: AppSettingsKey.focusReopensQuitApps.rawValue)
        barPlacement =
            defaults.string(forKey: AppSettingsKey.focusBarPlacement.rawValue)
            .flatMap(FocusBarPlacement.init(rawValue:)) ?? .floating
    }

    static func validSnooze(_ minutes: Int?) -> Int? {
        minutes.flatMap { FocusTimings.snoozeOptions.contains($0) ? $0 : nil }
    }

    private func save<Value: Encodable>(_ value: Value?, for key: AppSettingsKey) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key.rawValue)
            return
        }
        defaults.set(data, forKey: key.rawValue)
    }

    private static func load<Value: Decodable>(
        _ type: Value.Type, from defaults: UserDefaults, key: AppSettingsKey
    ) -> Value? {
        defaults.data(forKey: key.rawValue).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

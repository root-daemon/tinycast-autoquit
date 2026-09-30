import Foundation

extension AutoQuitRule: SettingsFileValue {
    init?(settingsJSON: SettingsFileJSON) {
        guard let bundleID = settingsJSON["bundleID"]?.string,
            let minutes = settingsJSON["minutes"]?.int
        else { return nil }
        self.init(bundleID: bundleID, minutes: minutes)
        guard isValid else { return nil }
    }

    var settingsJSON: SettingsFileJSON {
        .object(["bundleID": .string(bundleID), "minutes": .number(Double(minutes))])
    }
}

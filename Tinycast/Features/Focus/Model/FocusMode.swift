import Foundation

enum FocusMode: String, CaseIterable, Codable, Sendable {
    /// Quit the listed apps; everything else stays usable.
    case block
    /// Quit every app except the listed ones and the always-allowed system apps.
    case allow
}

enum FocusBarPlacement: String, CaseIterable, Codable, Sendable {
    case floating
    case menuBar
}

enum FocusTimings {
    static let durationPresets = [15, 25, 30, 45, 60, 90, 120]
    static let breakPresets = [5, 10, 15, 30]
    /// Zero offers no snooze at all, so pausing is the only way past a block.
    static let snoozeOptions = [0, 1, 3, 5, 10]
    static let defaultSnoozeMinutes = 3
    static let extensionPresets = [5, 15]
}

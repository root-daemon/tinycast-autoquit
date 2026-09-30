import Foundation

enum AutoQuitDelay {
    static let presets = [5, 10, 15, 30, 45, 60]

    static func minutes(from text: String) -> Int? {
        guard let minutes = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
            AutoQuitRule.minuteRange.contains(minutes)
        else { return nil }
        return minutes
    }
}

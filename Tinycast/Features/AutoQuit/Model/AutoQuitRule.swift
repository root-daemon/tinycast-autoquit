import Foundation

struct AutoQuitRule: Codable, Equatable, Identifiable, Sendable {
    static let minuteRange = 1...1440
    static let defaultMinutes = 15

    let bundleID: String
    var minutes: Int

    var id: String { bundleID }
    var isValid: Bool {
        !bundleID.isEmpty && bundleID == bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            && Self.minuteRange.contains(minutes)
    }

    static func validated(_ rules: [Self]) -> [Self]? {
        normalized(rules).count == rules.count ? rules : nil
    }

    static func normalized(_ rules: [Self]) -> [Self] {
        var seen: Set<String> = []
        return rules.filter { $0.isValid && seen.insert($0.bundleID).inserted }
    }
}

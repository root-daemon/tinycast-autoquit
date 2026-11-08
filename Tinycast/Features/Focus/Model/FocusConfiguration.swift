import Foundation

/// What a session blocks and for how long; also the remembered setup a new session starts from.
struct FocusConfiguration: Codable, Equatable, Sendable {
    static let minuteRange = 1...1440
    static let goalLimit = 200
    static let initial = FocusConfiguration(
        goal: "", minutes: 25, mode: .block, bundleIDs: [],
        categoryIDs: ["social", "entertainment", "gaming"])

    var goal: String
    /// Nil runs until the user completes it.
    var minutes: Int?
    var mode: FocusMode
    var bundleIDs: [String]
    var categoryIDs: [String]

    var normalized: FocusConfiguration {
        var copy = self
        copy.goal = String(goal.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.goalLimit))
        copy.minutes = minutes.map { min(max($0, Self.minuteRange.lowerBound), Self.minuteRange.upperBound) }
        var seenApps: Set<String> = []
        copy.bundleIDs = bundleIDs.filter {
            !$0.isEmpty && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines)
                && seenApps.insert($0).inserted
        }
        var seenCategories: Set<String> = []
        copy.categoryIDs = categoryIDs.filter {
            FocusCategory.category(id: $0) != nil && seenCategories.insert($0).inserted
        }
        return copy
    }

    var listedBundleIDs: Set<String> {
        categoryIDs.compactMap(FocusCategory.category(id:)).reduce(into: Set(bundleIDs)) {
            $0.formUnion($1.bundleIDs)
        }
    }

    /// A link's `arguments` over this setup; one unreadable or unknown field rejects the link.
    func applying(linkFields fields: [String: String]) -> FocusConfiguration? {
        var copy = self
        for (key, value) in fields {
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            switch key.lowercased() {
            case "goal":
                copy.goal = text
            case "duration":
                if ["0", "none", "unlimited"].contains(text.lowercased()) {
                    copy.minutes = nil
                } else {
                    guard let minutes = Self.minutes(from: text) else { return nil }
                    copy.minutes = minutes
                }
            case "mode":
                guard let mode = FocusMode(rawValue: text.lowercased()) else { return nil }
                copy.mode = mode
            case "categories":
                let ids = Self.list(text)
                guard ids.allSatisfy({ FocusCategory.category(id: $0) != nil }) else { return nil }
                copy.categoryIDs = ids
            case "apps":
                copy.bundleIDs = Self.list(text)
            default:
                return nil
            }
        }
        return copy.normalized
    }

    private static func list(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Accepts `25`, `25m`, `90 min`, `1h`, `1h30` and `1h 30m`; nil for anything else.
    static func minutes(from text: String) -> Int? {
        let compact = text.lowercased().filter { !$0.isWhitespace }
        guard !compact.isEmpty else { return nil }
        var total = 0
        var digits = ""
        var sawHours = false
        var index = compact.startIndex
        while index < compact.endIndex {
            let character = compact[index]
            if character.isASCII, character.isNumber {
                digits.append(character)
                index = compact.index(after: index)
                continue
            }
            let rest = compact[index...]
            guard let value = Int(digits) else { return nil }
            if let unit = ["hours", "hour", "hrs", "hr", "h"].first(where: rest.hasPrefix), !sawHours {
                total += value * 60
                sawHours = true
                index = compact.index(index, offsetBy: unit.count)
            } else if let unit = ["minutes", "minute", "mins", "min", "m"].first(where: rest.hasPrefix) {
                total += value
                index = compact.index(index, offsetBy: unit.count)
                guard index == compact.endIndex else { return nil }
            } else {
                return nil
            }
            digits = ""
        }
        if !digits.isEmpty {
            guard let value = Int(digits) else { return nil }
            total += value
        }
        return minuteRange.contains(total) ? total : nil
    }
}

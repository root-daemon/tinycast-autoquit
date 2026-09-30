import Foundation

struct AutoQuitEngine: Sendable {
    struct Application: Sendable {
        let processID: Int32
        let bundleID: String
        let isActive: Bool
        let isEligible: Bool
    }

    private struct Countdown: Sendable {
        let bundleID: String
        let minutes: Int
        let started: Duration
        var requested = false
    }

    private var countdowns: [Int32: Countdown] = [:]

    mutating func reset() {
        countdowns.removeAll()
    }

    mutating func activated(processID: Int32) {
        countdowns.removeValue(forKey: processID)
    }

    mutating func evaluate(
        applications: [Application], rules: [AutoQuitRule], now: Duration
    ) -> [Int32] {
        let delays = Dictionary(
            uniqueKeysWithValues: AutoQuitRule.normalized(rules).map { ($0.bundleID, $0.minutes) })
        let running = Set(applications.map(\.processID))
        countdowns = countdowns.filter { running.contains($0.key) }
        var due: [Int32] = []
        for application in applications {
            let processID = application.processID
            guard application.isEligible, !application.isActive,
                let minutes = delays[application.bundleID]
            else {
                countdowns.removeValue(forKey: processID)
                continue
            }
            if countdowns[processID]?.bundleID != application.bundleID
                || countdowns[processID]?.minutes != minutes
            {
                countdowns[processID] = Countdown(
                    bundleID: application.bundleID, minutes: minutes, started: now)
            }
            guard var countdown = countdowns[processID], !countdown.requested,
                now - countdown.started >= .seconds(minutes * 60)
            else { continue }
            countdown.requested = true
            countdowns[processID] = countdown
            due.append(processID)
        }
        return due
    }
}

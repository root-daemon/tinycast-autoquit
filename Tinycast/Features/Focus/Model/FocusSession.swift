import Foundation

/// One running session. Time counts only while it runs, so breaks and sleep never use it up.
struct FocusSession: Codable, Equatable, Sendable {
    var configuration: FocusConfiguration
    let startedAt: Date
    private(set) var activeBefore: TimeInterval = 0
    /// Nil while paused or while the Mac sleeps.
    private(set) var runningSince: Date?
    private(set) var isPaused = false
    private(set) var breakEndsAt: Date?
    private(set) var snoozes: [String: Date] = [:]
    /// Apps this session quit, in order, so they can be reopened when it ends.
    var quitBundleIDs: [String] = []

    init(configuration: FocusConfiguration, at now: Date) {
        self.configuration = configuration.normalized
        startedAt = now
        runningSince = now
    }

    var isSuspended: Bool { !isPaused && runningSince == nil }

    func elapsed(at now: Date) -> TimeInterval {
        activeBefore + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    func remaining(at now: Date) -> TimeInterval? {
        configuration.minutes.map { max(0, TimeInterval($0 * 60) - elapsed(at: now)) }
    }

    func progress(at now: Date) -> Double? {
        configuration.minutes.map { min(1, elapsed(at: now) / TimeInterval($0 * 60)) }
    }

    func isFinished(at now: Date) -> Bool {
        remaining(at: now) == 0
    }

    func isBreakOver(at now: Date) -> Bool {
        isPaused && breakEndsAt.map { now >= $0 } == true
    }

    func isSnoozed(_ bundleID: String, at now: Date) -> Bool {
        snoozes[bundleID].map { now < $0 } == true
    }

    /// `ownBundleID` is Tinycast's, injected so a test or a debug build names its own.
    func blocks(_ bundleID: String, at now: Date, ownBundleID: String) -> Bool {
        guard !isPaused, runningSince != nil, bundleID != ownBundleID,
            !FocusCategory.alwaysAllowed.contains(bundleID), !isSnoozed(bundleID, at: now)
        else { return false }
        let listed = configuration.listedBundleIDs.contains(bundleID)
        return configuration.mode == .block ? listed : !listed
    }

    mutating func pause(at now: Date, minutes: Int?) {
        fold(at: now)
        isPaused = true
        breakEndsAt = minutes.map { now.addingTimeInterval(TimeInterval($0 * 60)) }
    }

    mutating func resume(at now: Date) {
        guard isPaused else { return }
        isPaused = false
        breakEndsAt = nil
        runningSince = now
    }

    /// Sleep stops the clock without counting as a break.
    mutating func suspend(at now: Date) {
        guard !isPaused else { return }
        fold(at: now)
    }

    mutating func wake(at now: Date) {
        guard isSuspended else { return }
        runningSince = now
    }

    /// Leaves `minutes` still to run, measured from now.
    mutating func extend(minutes: Int, at now: Date) {
        guard configuration.minutes != nil else { return }
        let used = Int((elapsed(at: now) / 60).rounded(.up))
        configuration.minutes = min(FocusConfiguration.minuteRange.upperBound, used + minutes)
    }

    mutating func update(_ configuration: FocusConfiguration) {
        self.configuration = configuration.normalized
    }

    mutating func snooze(_ bundleID: String, minutes: Int, at now: Date) {
        guard minutes > 0 else { return }
        snoozes[bundleID] = now.addingTimeInterval(TimeInterval(minutes * 60))
    }

    /// Drops ended snoozes and returns their bundle IDs.
    mutating func expireSnoozes(at now: Date) -> [String] {
        let ended = snoozes.filter { now >= $0.value }.map(\.key).sorted()
        for bundleID in ended { snoozes.removeValue(forKey: bundleID) }
        return ended
    }

    mutating func recordQuit(_ bundleID: String) {
        if !quitBundleIDs.contains(bundleID) { quitBundleIDs.append(bundleID) }
    }

    private mutating func fold(at now: Date) {
        activeBefore = elapsed(at: now)
        runningSince = nil
    }
}

enum FocusClock {
    /// `24:59`, or `1:02:03` past an hour; rounded up so a fresh 25-minute session reads 25:00.
    static func text(_ seconds: TimeInterval, roundingUp: Bool = true) -> String {
        let total = max(0, Int(roundingUp ? seconds.rounded(.up) : seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

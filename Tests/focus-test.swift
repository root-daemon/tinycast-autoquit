import Foundation

@main
@MainActor
struct FocusTest {
    static var failures = 0
    static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let own = "test.tinycast"

    static func main() {
        testMinutesParsing()
        testNormalization()
        testBlocking()
        testClock()
        testPauseAndSleep()
        testSnooze()
        testExtendAndEdit()
        testLinkFields()
        testPersistence()
        testFormatting()
        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }

    static func check(_ description: String, _ condition: @autoclosure () -> Bool) {
        if !condition() {
            print("FAIL: \(description)")
            failures += 1
        }
    }

    static func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    static func session(
        mode: FocusMode = .block, minutes: Int? = 25, apps: [String] = ["test.chat"],
        categories: [String] = []
    ) -> FocusSession {
        FocusSession(
            configuration: FocusConfiguration(
                goal: "Write", minutes: minutes, mode: mode, bundleIDs: apps, categoryIDs: categories),
            at: start)
    }

    static func testMinutesParsing() {
        let cases: [(String, Int?)] = [
            ("25", 25), ("25m", 25), ("25 min", 25), ("90 minutes", 90), ("1h", 60), ("1h30", 90),
            ("1h 30m", 90), ("2 hours", 120), ("24h", 1440), ("0", nil), ("1441", nil), ("", nil),
            ("abc", nil), ("1h2h", nil), ("30m1h", nil), ("-5", nil), ("h", nil)
        ]
        for (text, expected) in cases {
            check("minutes(from: \(text)) == \(String(describing: expected))",
                FocusConfiguration.minutes(from: text) == expected)
        }
    }

    static func testNormalization() {
        let raw = FocusConfiguration(
            goal: "  Ship it \n", minutes: 5000, mode: .block,
            bundleIDs: ["a", "a", "", " b"], categoryIDs: ["social", "nope", "social"])
        let normalized = raw.normalized
        check("goal trimmed", normalized.goal == "Ship it")
        check("minutes clamped", normalized.minutes == 1440)
        check("apps deduplicated and cleaned", normalized.bundleIDs == ["a"])
        check("unknown categories dropped", normalized.categoryIDs == ["social"])
        let long = FocusConfiguration(
            goal: String(repeating: "x", count: 500), minutes: nil, mode: .allow, bundleIDs: [],
            categoryIDs: [])
        check("goal capped", long.normalized.goal.count == FocusConfiguration.goalLimit)
        check("no limit kept", long.normalized.minutes == nil)
        check(
            "category apps are listed",
            FocusConfiguration(goal: "", minutes: 1, mode: .block, bundleIDs: [], categoryIDs: ["gaming"])
                .listedBundleIDs.contains("com.valvesoftware.steam"))
        check("built-in IDs are unique", Set(FocusCategory.builtIn.map(\.id)).count == FocusCategory.builtIn.count)
        check(
            "no category lists an always-allowed app",
            FocusCategory.builtIn.allSatisfy { $0.bundleIDs.isDisjoint(with: FocusCategory.alwaysAllowed) })
    }

    static func testBlocking() {
        let block = session(categories: ["gaming"])
        check("listed app blocked", block.blocks("test.chat", at: at(1), ownBundleID: own))
        check("category app blocked", block.blocks("com.valvesoftware.steam", at: at(1), ownBundleID: own))
        check("unlisted app allowed", !block.blocks("test.editor", at: at(1), ownBundleID: own))
        let allow = session(mode: .allow, apps: ["test.editor"])
        check("allow mode keeps listed app", !allow.blocks("test.editor", at: at(1), ownBundleID: own))
        check("allow mode blocks the rest", allow.blocks("test.chat", at: at(1), ownBundleID: own))
        check("Finder never blocked", !allow.blocks("com.apple.finder", at: at(1), ownBundleID: own))
        check("Tinycast never blocked", !allow.blocks(own, at: at(1), ownBundleID: own))
        let listedFinder = session(apps: ["com.apple.finder", own])
        check("listing Finder does not block it", !listedFinder.blocks("com.apple.finder", at: at(1), ownBundleID: own))
        check("listing Tinycast does not block it", !listedFinder.blocks(own, at: at(1), ownBundleID: own))
    }

    static func testClock() {
        let running = session(minutes: 25)
        check("fresh session has full time", running.remaining(at: start) == 1500)
        check("counts down", running.remaining(at: at(60)) == 1440)
        check("progress halfway", running.progress(at: at(750)) == 0.5)
        check("not finished early", !running.isFinished(at: at(1499)))
        check("finished at zero", running.isFinished(at: at(1500)))
        check("remaining never negative", running.remaining(at: at(9999)) == 0)
        let open = session(minutes: nil)
        check("no limit has no remaining", open.remaining(at: at(60)) == nil)
        check("no limit never finishes", !open.isFinished(at: at(999_999)))
        check("no limit tracks elapsed", open.elapsed(at: at(90)) == 90)
    }

    static func testPauseAndSleep() {
        var value = session(minutes: 25)
        value.pause(at: at(600), minutes: 5)
        check("paused stops blocking", !value.blocks("test.chat", at: at(601), ownBundleID: own))
        check("pause freezes the clock", value.remaining(at: at(900)) == 900)
        check("break not over early", !value.isBreakOver(at: at(899)))
        check("break over on time", value.isBreakOver(at: at(900)))
        value.suspend(at: at(700))
        check("sleep while paused stays paused", value.isPaused && !value.isSuspended)
        value.wake(at: at(800))
        check("wake does not resume a pause", value.isPaused)
        value.resume(at: at(1000))
        check("resume blocks again", value.blocks("test.chat", at: at(1001), ownBundleID: own))
        check("resume continues the clock", value.remaining(at: at(1100)) == 800)
        value.suspend(at: at(1100))
        check("sleep suspends", value.isSuspended)
        check("sleep stops blocking", !value.blocks("test.chat", at: at(1200), ownBundleID: own))
        check("sleep freezes the clock", value.remaining(at: at(5000)) == 800)
        value.wake(at: at(5000))
        check("wake restarts the clock", value.remaining(at: at(5100)) == 700)
        value.resume(at: at(5200))
        check("resume without pause is a no-op", value.remaining(at: at(5200)) == 600)
    }

    static func testSnooze() {
        var value = session()
        value.snooze("test.chat", minutes: 3, at: at(10))
        check("snoozed app allowed", !value.blocks("test.chat", at: at(100), ownBundleID: own))
        check("snooze ends", value.blocks("test.chat", at: at(190), ownBundleID: own))
        check("nothing expired early", value.expireSnoozes(at: at(189)).isEmpty)
        check("expired snooze reported", value.expireSnoozes(at: at(190)) == ["test.chat"])
        check("expired snooze removed", value.expireSnoozes(at: at(191)).isEmpty)
        value.snooze("test.chat", minutes: 0, at: at(200))
        check("zero snooze does nothing", value.blocks("test.chat", at: at(201), ownBundleID: own))
        value.recordQuit("a")
        value.recordQuit("b")
        value.recordQuit("a")
        check("quit apps recorded once, in order", value.quitBundleIDs == ["a", "b"])
    }

    static func testExtendAndEdit() {
        var value = session(minutes: 25)
        value.extend(minutes: 5, at: at(1500))
        check("extend leaves five minutes", value.remaining(at: at(1500)) == 300)
        var open = session(minutes: nil)
        open.extend(minutes: 5, at: at(60))
        check("extend ignores no limit", open.configuration.minutes == nil)
        value.update(
            FocusConfiguration(goal: " New ", minutes: 10, mode: .allow, bundleIDs: [], categoryIDs: []))
        check("edit normalizes", value.configuration.goal == "New")
        check("edit to a shorter length finishes", value.isFinished(at: at(1500)))
        check("edit keeps the start", value.startedAt == start)
    }

    static func testLinkFields() {
        let base = FocusConfiguration.initial
        let link = base.applying(linkFields: [
            "goal": "Deep Focus", "duration": "45", "mode": "Allow", "categories": "social, gaming",
            "apps": "com.a,com.b"
        ])
        check("link goal", link?.goal == "Deep Focus")
        check("link duration", link?.minutes == 45)
        check("link mode", link?.mode == .allow)
        check("link categories", link?.categoryIDs == ["social", "gaming"])
        check("link apps", link?.bundleIDs == ["com.a", "com.b"])
        check("link no limit", base.applying(linkFields: ["duration": "none"])?.minutes == nil)
        check("link keeps unset fields", base.applying(linkFields: [:]) == base.normalized)
        check("bad duration rejects", base.applying(linkFields: ["duration": "soon"]) == nil)
        check("bad mode rejects", base.applying(linkFields: ["mode": "maybe"]) == nil)
        check("unknown category rejects", base.applying(linkFields: ["categories": "social,nope"]) == nil)
        check("unknown field rejects", base.applying(linkFields: ["colour": "red"]) == nil)
    }

    static func testPersistence() {
        let suite = "focus-test-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return check("suite", false) }
        defer { defaults.removePersistentDomain(forName: suite) }
        let fresh = FocusStore(defaults: defaults)
        check("initial configuration", fresh.configuration == .initial)
        check("no session", fresh.session == nil)
        check("default snooze", fresh.snoozeMinutes == FocusTimings.defaultSnoozeMinutes)
        check("sound on by default", fresh.playsSound)
        check("reopen off by default", !fresh.reopensQuitApps)
        check("floating by default", fresh.barPlacement == .floating)
        var value = session(categories: ["news"])
        value.pause(at: at(30), minutes: 5)
        value.snooze("test.chat", minutes: 3, at: at(10))
        value.recordQuit("test.chat")
        fresh.session = value
        fresh.configuration = value.configuration
        fresh.snoozeMinutes = 10
        fresh.playsSound = false
        fresh.reopensQuitApps = true
        fresh.barPlacement = .menuBar
        let reloaded = FocusStore(defaults: defaults)
        check("session round trip", reloaded.session == value)
        check("configuration round trip", reloaded.configuration == value.configuration)
        check("snooze round trip", reloaded.snoozeMinutes == 10)
        check("sound round trip", !reloaded.playsSound)
        check("reopen round trip", reloaded.reopensQuitApps)
        check("placement round trip", reloaded.barPlacement == .menuBar)
        reloaded.session = nil
        check("ended session cleared", FocusStore(defaults: defaults).session == nil)
        defaults.set(Data("junk".utf8), forKey: AppSettingsKey.focusConfiguration.rawValue)
        defaults.set(7, forKey: AppSettingsKey.focusSnoozeMinutes.rawValue)
        defaults.set("sideways", forKey: AppSettingsKey.focusBarPlacement.rawValue)
        let repaired = FocusStore(defaults: defaults)
        check("corrupt configuration falls back", repaired.configuration == .initial)
        check("invalid snooze falls back", repaired.snoozeMinutes == FocusTimings.defaultSnoozeMinutes)
        check("invalid placement falls back", repaired.barPlacement == .floating)
        check("snooze validation", FocusStore.validSnooze(5) == 5 && FocusStore.validSnooze(4) == nil)
    }

    static func testFormatting() {
        check("full minutes", FocusClock.text(1500) == "25:00")
        check("rounds up a partial second", FocusClock.text(1499.2) == "25:00")
        check("seconds pad", FocusClock.text(65) == "1:05")
        check("hours", FocusClock.text(3723) == "1:02:03")
        check("zero", FocusClock.text(0) == "0:00")
        check("never negative", FocusClock.text(-4) == "0:00")
        check("elapsed rounds down", FocusClock.text(59.9, roundingUp: false) == "0:59")
        check(
            "placement round-trips settings.json",
            FocusBarPlacement(settingsJSON: FocusBarPlacement.menuBar.settingsJSON) == .menuBar)
        check("unknown placement rejected", FocusBarPlacement(settingsJSON: .string("sideways")) == nil)
    }
}

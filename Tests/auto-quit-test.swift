import Foundation

@main
@MainActor
struct AutoQuitTest {
    static var failures = 0
    static let rule = AutoQuitRule(bundleID: "test.editor", minutes: 1)

    static func main() {
        testCountdowns()
        testConfiguration()
        testPersistence()
        testFormat()
        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }

    static func check(_ description: String, _ condition: @autoclosure () -> Bool) {
        if !condition() {
            print("FAIL: \(description)")
            failures += 1
        }
    }

    static func app(
        _ processID: Int32 = 1, bundleID: String = "test.editor", active: Bool = false,
        eligible: Bool = true
    ) -> AutoQuitEngine.Application {
        .init(processID: processID, bundleID: bundleID, isActive: active, isEligible: eligible)
    }

    static func testCountdowns() {
        var engine = AutoQuitEngine()
        check(
            "startup begins a full delay",
            engine.evaluate(applications: [app()], rules: [rule], now: .zero).isEmpty)
        check(
            "before threshold",
            engine.evaluate(applications: [app()], rules: [rule], now: .seconds(59)).isEmpty)
        check("at threshold", engine.evaluate(applications: [app()], rules: [rule], now: .seconds(60)) == [1])
        check(
            "cancelled quit isn't repeatedly requested",
            engine.evaluate(applications: [app()], rules: [rule], now: .seconds(120)).isEmpty)
        check(
            "foreground app is never due",
            engine.evaluate(applications: [app(active: true)], rules: [rule], now: .seconds(180)).isEmpty)
        check(
            "background starts again",
            engine.evaluate(applications: [app()], rules: [rule], now: .seconds(200)).isEmpty)
        check(
            "returning resets the countdown",
            engine.evaluate(applications: [app()], rules: [rule], now: .seconds(259)).isEmpty)
        check(
            "new background spell can quit again",
            engine.evaluate(applications: [app()], rules: [rule], now: .seconds(260)) == [1])
        engine.activated(processID: 1)
        check(
            "brief activation resets even between polls",
            engine.evaluate(applications: [app()], rules: [rule], now: .seconds(400)).isEmpty)
        engine.reset()
        check(
            "wake or re-enable begins a full delay",
            engine.evaluate(applications: [app()], rules: [rule], now: .seconds(500)).isEmpty)
        check(
            "terminated process is removed",
            engine.evaluate(applications: [], rules: [rule], now: .seconds(600)).isEmpty)
        check(
            "reused process ID starts fresh",
            engine.evaluate(applications: [app()], rules: [rule], now: .seconds(700)).isEmpty)
    }

    static func testConfiguration() {
        var engine = AutoQuitEngine()
        let applications = [
            app(), app(2), app(3, bundleID: "test.other"), app(4, eligible: false), app(5, active: true)
        ]
        _ = engine.evaluate(applications: applications, rules: [rule], now: .zero)
        check(
            "only selected eligible background processes quit",
            engine.evaluate(applications: applications, rules: [rule], now: .seconds(60)) == [1, 2])
        engine.reset()
        _ = engine.evaluate(applications: [app()], rules: [rule], now: .zero)
        let longer = AutoQuitRule(bundleID: rule.bundleID, minutes: 2)
        check(
            "changing delay starts a full countdown",
            engine.evaluate(applications: [app()], rules: [longer], now: .seconds(60)).isEmpty)
        check(
            "changed delay uses new duration",
            engine.evaluate(applications: [app()], rules: [longer], now: .seconds(180)) == [1])
        engine.reset()
        _ = engine.evaluate(applications: [app()], rules: [rule], now: .zero)
        _ = engine.evaluate(applications: [app()], rules: [], now: .seconds(30))
        check(
            "removing and restoring a rule clears elapsed time",
            engine.evaluate(applications: [app()], rules: [rule], now: .seconds(90)).isEmpty)
        let replacement = AutoQuitRule(bundleID: "test.other", minutes: 1)
        check(
            "PID reuse by another bundle clears elapsed time",
            engine.evaluate(
                applications: [app(bundleID: "test.other")], rules: [replacement], now: .seconds(150)
            ).isEmpty)
        let invalid = [
            AutoQuitRule(bundleID: "", minutes: 1), AutoQuitRule(bundleID: "x", minutes: 0),
            AutoQuitRule(bundleID: "x", minutes: 1441)
        ]
        check(
            "invalid rules and duplicates are rejected",
            AutoQuitRule.normalized(invalid + [rule, rule]) == [rule])
    }

    static func testPersistence() {
        let suite = "auto-quit-test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("No test defaults") }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AutoQuitStore(defaults: defaults)
        check("disabled with no selected apps by default", !store.enabled && store.rules.isEmpty)
        store.enabled = true
        store.rules = [rule]
        let restored = AutoQuitStore(defaults: defaults)
        check("rules and enablement survive restart", restored.enabled && restored.rules == [rule])
        defaults.set(
            [
                ["bundleID": rule.bundleID, "minutes": 1],
                ["bundleID": rule.bundleID, "minutes": 2],
                ["bundleID": "invalid", "minutes": 0],
                ["minutes": 10]
            ], forKey: AppSettingsKey.autoQuitRules.rawValue)
        check("bad persisted records don't arm extra apps", AutoQuitStore(defaults: defaults).rules == [rule])
    }

    static func testFormat() {
        check("valid list is accepted", AutoQuitRule.validated([rule]) == [rule])
        check("duplicate edit is rejected", AutoQuitRule.validated([rule, rule]) == nil)
        check("empty list clears rules", AutoQuitRule.validated([]) == [])
        check("settings file round trip", AutoQuitRule(settingsJSON: rule.settingsJSON) == rule)
        check("rule list round trip", [AutoQuitRule](settingsJSON: [rule].settingsJSON) == [rule])
        check(
            "invalid minutes are rejected",
            AutoQuitRule(settingsJSON: .object(["bundleID": "x", "minutes": 0])) == nil)
        check(
            "fractional minutes are rejected",
            AutoQuitRule(settingsJSON: .object(["bundleID": "x", "minutes": .number(1.5)])) == nil)
        check("missing delay is rejected", AutoQuitRule(settingsJSON: .object(["bundleID": "x"])) == nil)
        check(
            "malformed rule list is rejected",
            [AutoQuitRule](settingsJSON: .array([rule.settingsJSON, .null])) == nil)
    }
}

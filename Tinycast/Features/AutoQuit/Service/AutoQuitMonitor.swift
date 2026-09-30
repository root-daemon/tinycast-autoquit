import AppKit

@MainActor
final class AutoQuitMonitor {
    var onFailure: ((String) -> Void)?
    private var engine = AutoQuitEngine()
    private var rules: [AutoQuitRule] = []
    private var task: Task<Void, Never>?
    private var observations: [NotificationCenter.ObservationToken] = []
    private let clock = SuspendingClock()
    private let origin = SuspendingClock().now
    private var sleeping = false
    private var sessionInactive = false

    func start(rules: [AutoQuitRule]) {
        if self.rules != rules { engine.reset() }
        self.rules = rules
        guard task == nil else { return }
        observeWorkspace()
        refresh()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5), clock: .suspending)
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        let center = NSWorkspace.shared.notificationCenter
        for token in observations { center.removeObserver(token) }
        observations.removeAll()
        engine.reset()
        sleeping = false
        sessionInactive = false
    }

    isolated deinit {
        task?.cancel()
        let center = NSWorkspace.shared.notificationCenter
        for token in observations { center.removeObserver(token) }
    }

    private func observeWorkspace() {
        let workspace = NSWorkspace.shared
        let center = workspace.notificationCenter
        observations = [
            center.addObserver(of: workspace, for: .didActivateApplication) { [weak self] message in
                self?.engine.activated(processID: message.application.processIdentifier)
                self?.refresh()
            },
            center.addObserver(of: workspace, for: .didLaunchApplication) { [weak self] message in
                self?.engine.activated(processID: message.application.processIdentifier)
                self?.refresh()
            },
            center.addObserver(of: workspace, for: .didTerminateApplication) { [weak self] message in
                self?.engine.activated(processID: message.application.processIdentifier)
                self?.refresh()
            },
            center.addObserver(of: workspace, for: .willSleep) { [weak self] _ in
                self?.setSleeping(true)
            },
            center.addObserver(of: workspace, for: .didWake) { [weak self] _ in
                self?.setSleeping(false)
            },
            center.addObserver(of: workspace, for: .sessionDidResignActive) { [weak self] _ in
                self?.setSessionInactive(true)
            },
            center.addObserver(of: workspace, for: .sessionDidBecomeActive) { [weak self] _ in
                self?.setSessionInactive(false)
            }
        ]
    }

    private func setSleeping(_ sleeping: Bool) {
        self.sleeping = sleeping
        engine.reset()
        refresh()
    }

    private func setSessionInactive(_ inactive: Bool) {
        sessionInactive = inactive
        engine.reset()
        refresh()
    }

    private func refresh() {
        guard !sleeping, !sessionInactive else { return }
        let applications = NSWorkspace.shared.runningApplications
        let snapshots = applications.compactMap { application -> AutoQuitEngine.Application? in
            guard let bundleID = application.bundleIdentifier else { return nil }
            return AutoQuitEngine.Application(
                processID: application.processIdentifier, bundleID: bundleID,
                isActive: application.isActive,
                isEligible: application.activationPolicy == .regular
                    && application.isFinishedLaunching && !application.isTerminated
                    && application.processIdentifier != ProcessInfo.processInfo.processIdentifier
                    && bundleID != "com.apple.finder")
        }
        let due = engine.evaluate(
            applications: snapshots, rules: rules, now: origin.duration(to: clock.now))
        for processID in due {
            guard let application = applications.first(where: { $0.processIdentifier == processID }),
                !application.isActive, !application.isTerminated
            else { continue }
            if !application.terminate() {
                onFailure?(application.localizedName ?? application.bundleIdentifier ?? "Application")
            }
        }
    }
}

import AppKit

/// Quits blocked apps as they launch or come forward, and ticks once a second while armed.
@MainActor
final class FocusMonitor {
    /// The coordinator's verdict for a bundle ID; the monitor only acts on it.
    var blocks: (String) -> Bool = { _ in false }
    /// `announced` is false for a sweep, true when the user just tried to open the app.
    var onQuit: ((NSRunningApplication, Bool) -> Void)?
    var onFailure: ((String) -> Void)?
    var onTick: (() -> Void)?
    var onSuspend: ((Bool) -> Void)?
    private var task: Task<Void, Never>?
    private var observations: [NotificationCenter.ObservationToken] = []
    /// A refused quit is asked again only after the user leaves that app and comes back.
    private var requested: Set<pid_t> = []

    var isRunning: Bool { task != nil }

    func start() {
        guard task == nil else { return }
        observeWorkspace()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.onTick?()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        let center = NSWorkspace.shared.notificationCenter
        for token in observations { center.removeObserver(token) }
        observations.removeAll()
        requested.removeAll()
    }

    isolated deinit {
        task?.cancel()
        let center = NSWorkspace.shared.notificationCenter
        for token in observations { center.removeObserver(token) }
    }

    /// Quits every running app the verdict blocks, the frontmost one included.
    func sweep() {
        for application in NSWorkspace.shared.runningApplications {
            quitIfBlocked(application, announced: false)
        }
    }

    private func observeWorkspace() {
        let workspace = NSWorkspace.shared
        let center = workspace.notificationCenter
        observations = [
            center.addObserver(of: workspace, for: .didActivateApplication) { [weak self] message in
                self?.quitIfBlocked(message.application, announced: true)
            },
            center.addObserver(of: workspace, for: .didLaunchApplication) { [weak self] message in
                self?.quitIfBlocked(message.application, announced: true)
            },
            center.addObserver(of: workspace, for: .didDeactivateApplication) { [weak self] message in
                self?.requested.remove(message.application.processIdentifier)
            },
            center.addObserver(of: workspace, for: .didTerminateApplication) { [weak self] message in
                self?.requested.remove(message.application.processIdentifier)
            },
            center.addObserver(of: workspace, for: .willSleep) { [weak self] _ in
                self?.onSuspend?(true)
            },
            center.addObserver(of: workspace, for: .didWake) { [weak self] _ in
                self?.onSuspend?(false)
            },
            center.addObserver(of: workspace, for: .sessionDidResignActive) { [weak self] _ in
                self?.onSuspend?(true)
            },
            center.addObserver(of: workspace, for: .sessionDidBecomeActive) { [weak self] _ in
                self?.onSuspend?(false)
            }
        ]
    }

    private func quitIfBlocked(_ application: NSRunningApplication, announced: Bool) {
        guard application.activationPolicy == .regular, !application.isTerminated,
            application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
            let bundleID = application.bundleIdentifier, blocks(bundleID),
            requested.insert(application.processIdentifier).inserted
        else { return }
        if application.terminate() {
            onQuit?(application, announced)
        } else {
            onFailure?(application.localizedName ?? bundleID)
        }
    }
}

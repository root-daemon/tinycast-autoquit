import AppKit
import Observation

@MainActor
@Observable
final class FocusCoordinator {
    struct BlockedApp: Equatable {
        let bundleID: String
        let name: String
    }

    let store: FocusStore
    /// Advanced once a second while a session exists, so the bar and menu redraw their countdown.
    private(set) var now = Date()
    /// What the Start and Edit screens change; committed only by `submit(goal:)`.
    var draft = FocusConfiguration.initial
    private(set) var isEditingSession = false
    private(set) var lastBlocked: BlockedApp?
    @ObservationIgnored private let monitor: FocusMonitor
    @ObservationIgnored private let appIndex: AppIndex
    @ObservationIgnored private let palette: PaletteState
    @ObservationIgnored private let paletteCoordinator: PaletteCoordinator
    @ObservationIgnored private let showMessage: (String, DialogTone) -> Void
    @ObservationIgnored private let choose: (String, String?, [DialogAction]) async -> Int
    @ObservationIgnored private lazy var bar = FocusBarController(coordinator: self)
    @ObservationIgnored private var menuBar: FocusMenuBarController?
    @ObservationIgnored private let glow = FocusGlowController()
    @ObservationIgnored private var isAskingToExtend = false
    @ObservationIgnored private let ownBundleID = Bundle.main.bundleIdentifier ?? "com.tinycast.app"

    init(
        store: FocusStore, monitor: FocusMonitor, appIndex: AppIndex, palette: PaletteState,
        paletteCoordinator: PaletteCoordinator,
        showMessage: @escaping (String, DialogTone) -> Void,
        choose: @escaping (String, String?, [DialogAction]) async -> Int
    ) {
        self.store = store
        self.monitor = monitor
        self.appIndex = appIndex
        self.palette = palette
        self.paletteCoordinator = paletteCoordinator
        self.showMessage = showMessage
        self.choose = choose
    }

    var session: FocusSession? { store.session }

    var canSnooze: Bool {
        lastBlocked != nil && store.snoozeMinutes > 0 && session.map { !$0.isPaused } == true
    }

    // MARK: - Lifecycle

    /// Picks up a session that outlived the last run; the clock restarts from now.
    func restore() {
        monitor.blocks = { [unowned self] bundleID in
            self.store.session?.blocks(bundleID, at: Date(), ownBundleID: self.ownBundleID) ?? false
        }
        monitor.onQuit = { [unowned self] application, announced in
            self.quitApplication(application, announced: announced)
        }
        monitor.onFailure = { [unowned self] name in
            self.showMessage(String(localized: "Focus couldn't quit \(name)"), .danger)
        }
        monitor.onTick = { [unowned self] in self.tick() }
        monitor.onSuspend = { [unowned self] in self.setSuspended($0) }
        if var session = store.session {
            session.wake(at: Date())
            store.session = session
        }
        applyPresentation()
        if session.map({ !$0.isPaused }) == true { monitor.sweep() }
    }

    /// Stops the clock so the time Tinycast is not running never counts as focus.
    func prepareForTermination() {
        monitor.stop()
        guard var session = store.session else { return }
        session.suspend(at: Date())
        store.session = session
    }

    func applyPresentation() {
        guard store.session != nil else {
            monitor.stop()
            bar.close()
            menuBar?.remove()
            menuBar = nil
            return
        }
        now = Date()
        monitor.start()
        switch store.barPlacement {
        case .floating:
            menuBar?.remove()
            menuBar = nil
            bar.show()
        case .menuBar:
            bar.close()
            if menuBar == nil { menuBar = FocusMenuBarController(coordinator: self) }
            menuBar?.update()
        }
    }

    func setBarPlacement(_ placement: FocusBarPlacement) {
        store.barPlacement = placement
    }

    // MARK: - Session

    func begin(_ configuration: FocusConfiguration) {
        let configuration = configuration.normalized
        store.configuration = configuration
        store.session = FocusSession(configuration: configuration, at: Date())
        lastBlocked = nil
        play("Submarine")
        applyPresentation()
        monitor.sweep()
        showMessage(String(localized: "Focus session started"), .success)
    }

    func toggle() {
        if store.session == nil { begin(store.configuration) } else { complete() }
    }

    func complete() {
        end(message: String(localized: "Focus session complete"), celebrates: true)
    }

    func cancel() {
        end(message: String(localized: "Focus session cancelled"), celebrates: false)
    }

    func pause(minutes: Int?) {
        guard var session = store.session else { return reportNoSession() }
        guard !session.isPaused else { return }
        session.pause(at: Date(), minutes: minutes)
        store.session = session
        refresh()
        showMessage(
            minutes.map { String(localized: "Focus paused for \($0) min") }
                ?? String(localized: "Focus paused"), .success)
    }

    func resume() {
        resume(announcing: String(localized: "Focus resumed"))
    }

    func togglePause() {
        if store.session?.isPaused == true { resume() } else { pause(minutes: nil) }
    }

    func extend(minutes: Int) {
        guard var session = store.session else { return }
        session.extend(minutes: minutes, at: Date())
        store.session = session
        refresh()
    }

    /// Lets the last blocked app back in for the snooze length, and reopens it.
    func snoozeLastBlocked() {
        guard let blocked = lastBlocked, store.snoozeMinutes > 0, var session = store.session else { return }
        session.snooze(blocked.bundleID, minutes: store.snoozeMinutes, at: Date())
        store.session = session
        lastBlocked = nil
        reopen([blocked.bundleID], activates: true)
        showMessage(String(localized: "\(blocked.name) snoozed for \(store.snoozeMinutes) min"), .success)
    }

    // MARK: - Commands that open a screen

    func showStart() {
        guard store.session == nil else { return showEdit() }
        draft = store.configuration
        isEditingSession = false
        paletteCoordinator.showPalette(mode: .focus, seeding: draft.goal)
    }

    func showEdit() {
        guard let session = store.session else { return reportNoSession() }
        draft = session.configuration
        isEditingSession = true
        paletteCoordinator.showPalette(mode: .focus, seeding: draft.goal)
    }

    func showPause() {
        guard let session = store.session else { return reportNoSession() }
        guard !session.isPaused else {
            return showMessage(String(localized: "Focus is already paused"), .neutral)
        }
        paletteCoordinator.showPalette(mode: .focusBreak)
    }

    func resumeFromCommand() {
        guard let session = store.session else { return reportNoSession() }
        guard session.isPaused else { return showMessage(String(localized: "Focus is already running"), .neutral) }
        paletteCoordinator.hidePalette()
        resume()
    }

    func completeFromCommand() {
        guard store.session != nil else { return reportNoSession() }
        paletteCoordinator.hidePalette()
        complete()
    }

    func cancelFromCommand() {
        guard store.session != nil else { return reportNoSession() }
        paletteCoordinator.hidePalette()
        cancel()
    }

    func toggleFromCommand() {
        paletteCoordinator.hidePalette()
        toggle()
    }

    func showApps() {
        palette.push(mode: .focusApps)
    }

    func submit(goal: String) {
        draft.goal = goal
        paletteCoordinator.hidePalette()
        guard isEditingSession, var session = store.session else { return begin(draft) }
        session.update(draft)
        store.session = session
        store.configuration = session.configuration
        refresh()
        if !session.isPaused { monitor.sweep() }
        showMessage(String(localized: "Focus session updated"), .success)
    }

    func takeBreak(minutes: Int?) {
        paletteCoordinator.hidePalette()
        pause(minutes: minutes)
    }

    /// `tinycast://command/start-focus-session?arguments=…`; false when a field is unreadable.
    func begin(linkFields fields: [String: String]) -> Bool {
        guard let configuration = store.configuration.applying(linkFields: fields) else { return false }
        paletteCoordinator.hidePalette()
        begin(configuration)
        return true
    }

    // MARK: - Draft

    func setDraftMinutes(_ minutes: Int?) {
        draft.minutes = minutes
    }

    func setDraftMode(_ mode: FocusMode) {
        draft.mode = mode
    }

    func toggleDraftCategory(_ id: String) {
        if let index = draft.categoryIDs.firstIndex(of: id) {
            draft.categoryIDs.remove(at: index)
        } else {
            draft.categoryIDs.append(id)
        }
    }

    func toggleDraftApp(_ bundleID: String) {
        if let index = draft.bundleIDs.firstIndex(of: bundleID) {
            draft.bundleIDs.remove(at: index)
        } else {
            draft.bundleIDs.append(bundleID)
        }
    }

    /// Listed apps first, then the rest of the index; system apps that are never quit stay out.
    func applications(for query: String) -> [FocusApplication] {
        let entries = appIndex.apps.filter { $0.kind == .application }
        let indexed = entries.reduce(into: [String: AppEntry]()) { result, entry in
            if let bundleID = entry.bundleID, result[bundleID] == nil { result[bundleID] = entry }
        }
        let matches = query.isEmpty ? entries : appIndex.matches(query).filter { $0.kind == .application }
        let matchedIDs = Set(matches.compactMap(\.bundleID))
        var seen = FocusCategory.alwaysAllowed.union([ownBundleID])
        var applications: [FocusApplication] = []
        for bundleID in draft.bundleIDs {
            guard seen.insert(bundleID).inserted else { continue }
            let entry = indexed[bundleID]
            let url = entry?.url ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            let name = entry?.name ?? url?.deletingPathExtension().lastPathComponent ?? bundleID
            guard
                query.isEmpty || matchedIDs.contains(bundleID)
                    || FuzzyMatch.match(query: query, candidate: name) != nil
            else { continue }
            applications.append(.init(bundleID: bundleID, name: name, url: url, isListed: true))
        }
        for entry in matches {
            guard let bundleID = entry.bundleID, seen.insert(bundleID).inserted else { continue }
            applications.append(.init(bundleID: bundleID, name: entry.name, url: entry.url, isListed: false))
        }
        return applications
    }

    // MARK: - Private

    private func end(message: String, celebrates: Bool) {
        guard let session = store.session else { return reportNoSession() }
        store.session = nil
        lastBlocked = nil
        applyPresentation()
        if celebrates {
            glow.flash(Theme.Colors.success)
            play("Glass")
        }
        showMessage(message, .success)
        if store.reopensQuitApps { reopen(session.quitBundleIDs, activates: false) }
    }

    private func resume(announcing message: String) {
        guard var session = store.session else { return reportNoSession() }
        guard session.isPaused else { return }
        session.resume(at: Date())
        store.session = session
        refresh()
        monitor.sweep()
        showMessage(message, .success)
    }

    private func tick() {
        now = Date()
        guard var session = store.session else { return }
        if session.isBreakOver(at: now) {
            play("Submarine")
            return resume(announcing: String(localized: "Break's over — back to focus"))
        }
        if !session.expireSnoozes(at: now).isEmpty { store.session = session }
        if session.isFinished(at: now) { askToExtend() }
        menuBar?.update()
    }

    private func refresh() {
        now = Date()
        menuBar?.update()
    }

    private func askToExtend() {
        guard !isAskingToExtend, let goal = store.session?.configuration.goal else { return }
        isAskingToExtend = true
        play("Glass")
        Task {
            let options =
                FocusTimings.extensionPresets.map {
                    DialogAction(title: String(localized: "Extend \($0) min"))
                } + [DialogAction(title: String(localized: "Wrap Up"), role: .cancel)]
            let index = await choose(
                String(localized: "Focus time's up"), goal.isEmpty ? nil : goal, options)
            isAskingToExtend = false
            // The session may have been completed, cancelled or extended while the dialog was up.
            guard store.session?.isFinished(at: Date()) == true else { return }
            if FocusTimings.extensionPresets.indices.contains(index) {
                extend(minutes: FocusTimings.extensionPresets[index])
            } else {
                complete()
            }
        }
    }

    private func quitApplication(_ application: NSRunningApplication, announced: Bool) {
        guard var session = store.session, let bundleID = application.bundleIdentifier else { return }
        session.recordQuit(bundleID)
        store.session = session
        guard announced else { return }
        let name = application.localizedName ?? bundleID
        lastBlocked = BlockedApp(bundleID: bundleID, name: name)
        glow.flash(Theme.Colors.warning)
        showMessage(String(localized: "\(name) is blocked while you focus"), .danger)
        menuBar?.update()
    }

    private func setSuspended(_ suspended: Bool) {
        guard var session = store.session else { return }
        if suspended { session.suspend(at: Date()) } else { session.wake(at: Date()) }
        store.session = session
        refresh()
    }

    private func reopen(_ bundleIDs: [String], activates: Bool) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        for bundleID in bundleIDs {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                continue
            }
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }
        }
    }

    private func reportNoSession() {
        showMessage(String(localized: "No focus session is running"), .neutral)
    }

    private func play(_ name: String) {
        guard store.playsSound else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}

struct FocusApplication: Identifiable {
    let bundleID: String
    let name: String
    let url: URL?
    let isListed: Bool

    var id: String { bundleID }
}

import AppKit
import SwiftUI

/// The floating bar: goal, countdown and controls, above other apps on every Space.
@MainActor
final class FocusBarController {
    private unowned let coordinator: FocusCoordinator
    private var panel: FocusBarPanel?

    init(coordinator: FocusCoordinator) {
        self.coordinator = coordinator
    }

    func show() {
        if let panel {
            panel.orderFrontRegardless()
            return
        }
        let host = NSHostingView(rootView: FocusBarView(coordinator: coordinator))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: Theme.Size.focusBar)
        let panel = FocusBarPanel(content: host)
        if !panel.setFrameUsingName(FocusBarPanel.autosaveName) { position(panel) }
        panel.setFrameAutosaveName(FocusBarPanel.autosaveName)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// Top centre, just under the menu bar, where Raycast's bar sits too.
    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = Theme.Size.focusBar
        panel.setFrameOrigin(
            NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - Theme.Spacing.xl))
    }
}

private final class FocusBarPanel: NSPanel, AnimatedPanel {
    static let autosaveName = "FocusBar"

    init(content: NSView) {
        super.init(
            contentRect: NSRect(origin: .zero, size: content.frame.size),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        followMotion()
        isReleasedWhenClosed = false
        isRestorable = false
        contentView = content
    }

    override var canBecomeKey: Bool { false }
}

private struct FocusBarView: View {
    let coordinator: FocusCoordinator

    var body: some View {
        let session = coordinator.session
        let now = coordinator.now
        let isPaused = session?.isPaused == true
        HStack(spacing: Theme.Spacing.lg) {
            FocusRing(progress: session?.progress(at: now) ?? 0, isPaused: isPaused)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title(session))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(FocusStatus.line(session, at: now))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.xs)
            if coordinator.canSnooze, let blocked = coordinator.lastBlocked {
                FocusBarButton(
                    title: String(localized: "Snooze \(blocked.name)"), symbol: "clock.arrow.circlepath"
                ) { coordinator.snoozeLastBlocked() }
            }
            FocusBarButton(
                title: isPaused ? String(localized: "Resume") : String(localized: "Pause"),
                symbol: isPaused ? "play.fill" : "pause.fill"
            ) { coordinator.togglePause() }
            FocusBarButton(title: String(localized: "Complete"), symbol: "checkmark") {
                coordinator.complete()
            }
            FocusBarButton(title: String(localized: "Edit Focus Session"), symbol: "slider.horizontal.3") {
                coordinator.showEdit()
            }
            FocusBarButton(title: String(localized: "Move to Menu Bar"), symbol: "menubar.arrow.up.rectangle") {
                coordinator.setBarPlacement(.menuBar)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(width: Theme.Size.focusBar.width, height: Theme.Size.focusBar.height)
        .background(GlassEffectView())
        .clipShape(Capsule(style: .continuous))
        .contextMenu {
            Button(String(localized: "Cancel Focus Session"), role: .destructive) { coordinator.cancel() }
        }
        .motionScope()
    }

    private func title(_ session: FocusSession?) -> String {
        let goal = session?.configuration.goal ?? ""
        return goal.isEmpty ? String(localized: "Focus") : goal
    }
}

private struct FocusBarButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            SymbolImage(name: symbol, size: Theme.Size.focusRing / 2)
                .foregroundStyle(hovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .frame(width: Theme.Size.focusRing, height: Theme.Size.focusRing)
                .background(Circle().fill(hovered ? Theme.Colors.rowHover : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(title)
    }
}

private struct FocusRing: View {
    let progress: Double
    let isPaused: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Theme.Colors.separator, lineWidth: Theme.Size.focusRingStroke)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isPaused ? Theme.Colors.warning : Color.accentColor,
                    style: StrokeStyle(lineWidth: Theme.Size.focusRingStroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            SymbolImage(name: isPaused ? "pause.fill" : "target", size: Theme.Size.focusRing / 2.5)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(width: Theme.Size.focusRing, height: Theme.Size.focusRing)
        .accessibilityHidden(true)
    }
}

enum FocusStatus {
    /// `18:42 left`, `Paused · 4:59 break`, or `12:30 elapsed` for a session with no limit.
    static func line(_ session: FocusSession?, at now: Date) -> String {
        guard let session else { return "" }
        if session.isPaused {
            guard let ends = session.breakEndsAt else { return String(localized: "Paused") }
            let left = FocusClock.text(ends.timeIntervalSince(now))
            return String(localized: "On a break · \(left) left")
        }
        if let remaining = session.remaining(at: now) {
            return String(localized: "\(FocusClock.text(remaining)) left")
        }
        return String(localized: "\(FocusClock.text(session.elapsed(at: now), roundingUp: false)) elapsed")
    }

    /// The menu bar's short form: the countdown alone, or the elapsed time.
    static func compact(_ session: FocusSession, at now: Date) -> String {
        if session.isPaused { return String(localized: "Paused") }
        if let remaining = session.remaining(at: now) { return FocusClock.text(remaining) }
        return FocusClock.text(session.elapsed(at: now), roundingUp: false)
    }
}

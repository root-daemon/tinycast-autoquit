import AppKit
import SwiftUI

/// A brief coloured glow around the active screen's edge: orange for a block, green for done.
@MainActor
final class FocusGlowController {
    private var panel: NSPanel?
    private var fade: Task<Void, Never>?

    func flash(_ color: Color) {
        guard let screen = NSScreen.main else { return }
        fade?.cancel()
        panel?.orderOut(nil)
        let panel = NSPanel(
            contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: FocusGlowView(color: color).motionScope())
        host.sizingOptions = []
        panel.contentView = host
        panel.setFrame(screen.frame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.duration(Theme.Duration.focusGlowIn)
            panel.animator().alphaValue = 1
        }
        fade = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Theme.Duration.focusGlowHold))
            guard !Task.isCancelled else { return }
            self?.dismiss(panel)
        }
    }

    private func dismiss(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.duration(Theme.Duration.focusGlowOut)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                if self?.panel === panel { self?.panel = nil }
            }
        }
    }
}

private struct FocusGlowView: View {
    let color: Color

    var body: some View {
        Rectangle()
            .strokeBorder(color, lineWidth: Theme.Size.focusGlowWidth)
            .blur(radius: Theme.Size.focusGlowWidth / 2)
            .ignoresSafeArea()
    }
}

import AppKit

/// The session in the menu bar: a countdown title, and its controls in the item's menu.
@MainActor
final class FocusMenuBarController: NSObject, NSMenuDelegate {
    private unowned let coordinator: FocusCoordinator
    private let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    init(coordinator: FocusCoordinator) {
        self.coordinator = coordinator
        super.init()
        status.autosaveName = "Focus"
        menu.delegate = self
        status.menu = menu
        status.button?.image = NSImage(
            systemSymbolName: CommandID.startFocus.sfSymbol,
            accessibilityDescription: String(localized: "Focus"))
        status.button?.imagePosition = .imageLeading
        update()
    }

    func remove() {
        menu.cancelTracking()
        NSStatusBar.system.removeStatusItem(status)
    }

    func update() {
        guard let session = coordinator.session else { return }
        let title = " " + FocusStatus.compact(session, at: coordinator.now)
        if status.button?.title != title {
            status.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            status.button?.title = title
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let session = coordinator.session else { return }
        let goal = session.configuration.goal
        menu.addItem(label(goal.isEmpty ? String(localized: "Focus") : goal))
        menu.addItem(label(FocusStatus.line(session, at: Date())))
        menu.addItem(.separator())
        if let blocked = coordinator.lastBlocked, coordinator.canSnooze {
            menu.addItem(
                item(String(localized: "Snooze \(blocked.name)"), action: #selector(snooze)))
        }
        if session.isPaused {
            menu.addItem(item(String(localized: "Resume"), action: #selector(resume)))
        } else {
            let pause = NSMenuItem(title: String(localized: "Pause"), action: nil, keyEquivalent: "")
            let breaks = NSMenu()
            for minutes in FocusTimings.breakPresets {
                let entry = item(String(localized: "\(minutes) min break"), action: #selector(takeBreak))
                entry.tag = minutes
                breaks.addItem(entry)
            }
            breaks.addItem(.separator())
            breaks.addItem(item(String(localized: "Until I Resume"), action: #selector(takeBreak)))
            pause.submenu = breaks
            menu.addItem(pause)
        }
        menu.addItem(item(String(localized: "Complete"), action: #selector(complete)))
        menu.addItem(item(String(localized: "Edit Focus Session…"), action: #selector(edit)))
        menu.addItem(item(String(localized: "Show Floating Bar"), action: #selector(detach)))
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Cancel Focus Session"), action: #selector(cancel)))
    }

    private func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func item(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func snooze() { coordinator.snoozeLastBlocked() }
    @objc private func resume() { coordinator.resume() }
    @objc private func takeBreak(_ sender: NSMenuItem) {
        coordinator.pause(minutes: sender.tag > 0 ? sender.tag : nil)
    }
    @objc private func complete() { coordinator.complete() }
    @objc private func edit() { coordinator.showEdit() }
    @objc private func detach() { coordinator.setBarPlacement(.floating) }
    @objc private func cancel() { coordinator.cancel() }
}

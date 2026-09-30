import SwiftUI

struct AutoQuitSettingsView: View {
    @Environment(AutoQuitCoordinator.self) private var coordinator
    @State private var showsAppPicker = false

    var body: some View {
        Form {
            Section {
                Toggle(
                    isOn: Binding(
                        get: { coordinator.store.enabled },
                        set: { coordinator.setEnabled($0) })
                ) {
                    SettingsFeatureToggleLabel(
                        anchor: .autoQuitAutoQuit, title: "Enable Auto Quit",
                        subtitle: "Quit selected apps after time in the background.")
                }
            } footer: {
                Text(
                    "Returning to an app resets its countdown. Sleep and switching users reset all countdowns."
                )
            }
            .settingsAnchor(.autoQuitAutoQuit)

            Section {
                ForEach(coordinator.store.rules) { rule in
                    AutoQuitApplicationRow(rule: rule)
                }
                Button("Add Application…", systemImage: "plus") { showsAppPicker = true }
                    .popover(isPresented: $showsAppPicker) {
                        AppPickerPopover(excluded: coordinator.excludedBundleIDs) { bundleID in
                            if let bundleID { coordinator.add(bundleID: bundleID) }
                            showsAppPicker = false
                        }
                    }
            } header: {
                SettingsSectionHeader(.autoQuitApplications)
            } footer: {
                Text(
                    "Each delay is in minutes (1–1440). Apps receive a normal quit request "
                        + "and may ask to save changes. A cancelled quit is retried only after "
                        + "you use the app again. Finder and Tinycast are never quit."
                )
            }
            .settingsEnabled(coordinator.store.enabled)
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.autoQuit)
    }
}

private struct AutoQuitApplicationRow: View {
    let rule: AutoQuitRule
    @Environment(AutoQuitCoordinator.self) private var coordinator
    @Environment(AppIndex.self) private var appIndex

    private var minutes: Binding<Int> {
        Binding(
            get: { rule.minutes },
            set: { coordinator.setMinutes($0, bundleID: rule.bundleID) })
    }

    var body: some View {
        let presentation = AppPresentation.resolve(bundleID: rule.bundleID, in: appIndex)
        LabeledContent {
            HStack(spacing: Theme.Spacing.md) {
                Stepper(value: minutes, in: AutoQuitRule.minuteRange) {
                    HStack(spacing: Theme.Spacing.xs) {
                        TextField("Minutes", value: minutes, format: .number.grouping(.never))
                            .multilineTextAlignment(.trailing)
                            .fixedSize()
                            .accessibilityLabel("Background minutes for \(presentation.name)")
                        Text("min").foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("Background minutes for \(presentation.name)")
                Button("Remove \(presentation.name)", systemImage: "minus.circle", role: .destructive) {
                    coordinator.remove(bundleID: rule.bundleID)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Remove \(presentation.name)")
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(nsImage: presentation.icon)
                    .resizable()
                    .frame(width: SettingsListMetrics.iconSize, height: SettingsListMetrics.iconSize)
                Text(presentation.name)
            }
        }
    }
}

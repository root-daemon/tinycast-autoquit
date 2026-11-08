import SwiftUI

struct FocusSettingsView: View {
    @Environment(FocusCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var store = coordinator.store
        return Form {
            FeatureCommandsSection(owner: .focus, anchor: .focusCommands)

            Section {
                Picker(selection: $store.barPlacement) {
                    Text("Floating Bar").tag(FocusBarPlacement.floating)
                    Text("Menu Bar").tag(FocusBarPlacement.menuBar)
                } label: {
                    SettingsRowTitle(.focusSession, "Show Session In")
                }
                Picker(selection: $store.snoozeMinutes) {
                    ForEach(FocusTimings.snoozeOptions, id: \.self) { minutes in
                        if minutes == 0 {
                            Text("No Snooze").tag(minutes)
                        } else {
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                } label: {
                    SettingsRowTitle(.focusSession, "Snooze Length")
                }
                Toggle(isOn: $store.playsSound) {
                    SettingsRowTitle(.focusSession, "Play sounds")
                }
                Toggle(isOn: $store.reopensQuitApps) {
                    SettingsRowTitle(.focusSession, "Reopen quit apps when a session ends")
                }
            } header: {
                SettingsSectionHeader(.focusSession)
            } footer: {
                Text(
                    "Snooze lets the last blocked app back in for a few minutes. Breaks and sleep "
                        + "stop the clock. Apps receive a normal quit request and may ask to save changes."
                )
            }

            Section {
                Button("Choose Apps in Launcher", systemImage: "magnifyingglass") {
                    coordinator.showStart()
                }
            } header: {
                SettingsSectionHeader(.focusApps)
            } footer: {
                Text(
                    "Each session remembers its duration, mode and list for the next one. "
                        + "Finder, System Settings and Activity Monitor are never quit."
                )
            }
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.focus)
    }
}

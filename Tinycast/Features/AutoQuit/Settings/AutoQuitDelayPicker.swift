import SwiftUI

struct AutoQuitDelayPicker: View {
    @Binding var minutes: Int
    let applicationName: String
    @State private var usesCustom = false

    private var selection: Binding<Int?> {
        Binding(
            get: { !usesCustom && AutoQuitDelay.presets.contains(minutes) ? minutes : nil },
            set: { value in
                usesCustom = value == nil
                if let value { minutes = value }
            })
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Picker("Quit after", selection: selection) {
                ForEach(AutoQuitDelay.presets, id: \.self) { preset in
                    Text("\(preset) minutes").tag(Optional(preset))
                }
                Text("Custom…").tag(Int?.none)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .accessibilityLabel("Quit \(applicationName) after")
            if selection.wrappedValue == nil {
                TextField("Minutes", value: $minutes, format: .number.grouping(.never))
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .accessibilityLabel("Custom minutes for \(applicationName)")
                Text("min").foregroundStyle(.secondary)
            }
        }
    }
}

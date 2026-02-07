import SwiftUI

/// A settings row with a label and content aligned to the right
struct SettingsRow<Content: View>: View {
    let label: String
    let tooltip: String?
    let content: () -> Content

    init(
        label: String,
        tooltip: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.tooltip = tooltip
        self.content = content
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .help(tooltip ?? "")

            Spacer()

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// A simple settings row with just text value
struct SettingsTextRow: View {
    let label: String
    let value: String
    let tooltip: String?

    init(label: String, value: String, tooltip: String? = nil) {
        self.label = label
        self.value = value
        self.tooltip = tooltip
    }

    var body: some View {
        SettingsRow(label: label, tooltip: tooltip) {
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

/// A settings row with a toggle
struct SettingsToggleRow: View {
    let label: String
    let tooltip: String?
    @Binding var isOn: Bool

    init(label: String, isOn: Binding<Bool>, tooltip: String? = nil) {
        self.label = label
        self._isOn = isOn
        self.tooltip = tooltip
    }

    var body: some View {
        SettingsRow(label: label, tooltip: tooltip) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
        }
    }
}

/// A settings row with a picker/dropdown
struct SettingsPickerRow<SelectionValue: Hashable>: View {
    let label: String
    let tooltip: String?
    @Binding var selection: SelectionValue
    let options: [(label: String, value: SelectionValue)]

    init(
        label: String,
        selection: Binding<SelectionValue>,
        options: [(String, SelectionValue)],
        tooltip: String? = nil
    ) {
        self.label = label
        self._selection = selection
        self.options = options
        self.tooltip = tooltip
    }

    var body: some View {
        SettingsRow(label: label, tooltip: tooltip) {
            Picker("", selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 125)
        }
    }
}

/// A settings row with a stepper
struct SettingsStepperRow: View {
    let label: String
    let tooltip: String?
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String

    init(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        suffix: String = "",
        tooltip: String? = nil
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.suffix = suffix
        self.tooltip = tooltip
    }

    var body: some View {
        SettingsRow(label: label, tooltip: tooltip) {
            HStack(spacing: 8) {
                Text("\(value)\(suffix)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 40, alignment: .trailing)

                Stepper("", value: $value, in: range)
                    .labelsHidden()
            }
        }
    }
}

/// A settings row with a horizontal slider
struct SettingsSliderRow: View {
    let label: String
    let tooltip: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let suffix: String

    init(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1.0,
        suffix: String = "",
        tooltip: String? = nil
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.suffix = suffix
        self.tooltip = tooltip
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .help(tooltip ?? "")

                Spacer()

                Text("\(Int(value))\(suffix)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 40, alignment: .trailing)
            }

            Slider(value: $value, in: range, step: step)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack(spacing: 0) {
        SettingsTextRow(
            label: "Battery Health",
            value: "Normal",
            tooltip: "Your battery is functioning normally"
        )
        Divider()
        SettingsToggleRow(
            label: "Show in Menu Bar",
            isOn: .constant(true),
            tooltip: "Display battery information in the menu bar"
        )
        Divider()
        SettingsPickerRow(
            label: "Update Interval",
            selection: .constant(1),
            options: [
                ("1 second", 1),
                ("5 seconds", 5),
                ("10 seconds", 10),
            ],
            tooltip: "How often to refresh battery data"
        )
        Divider()
        SettingsStepperRow(
            label: "Low Battery Warning",
            value: .constant(20),
            range: 5...50,
            suffix: "%",
            tooltip: "Get notified when battery falls below this level"
        )
    }
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(8)
    .padding()
    .frame(width: 500)
}

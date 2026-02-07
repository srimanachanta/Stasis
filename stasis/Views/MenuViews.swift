import SwiftUI

struct BatteryMainInfo: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer(minLength: 20)
            Text(value)
                .foregroundStyle(.primary)
                .font(.body)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

struct BatteryAdditionalInfo<Label: View>: View {
    let label: () -> Label
    let value: String

    init(label: @escaping () -> Label, value: String) {
        self.label = label
        self.value = value
    }

    init(label: String, value: String) where Label == Text {
        self.label = { Text(label) }
        self.value = value
    }

    var body: some View {
        HStack(alignment: .top) {
            label()
            Spacer(minLength: 20)
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .foregroundColor(.secondary)
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}

#Preview("Menu Items") {
    VStack(spacing: 0) {
        BatteryMainInfo(label: "Battery", value: "85%")
        Divider()
        BatteryAdditionalInfo(label: "Battery Percentage", value: "85%")
        BatteryAdditionalInfo(label: "Time Remaining", value: "02:45")
        BatteryAdditionalInfo(label: "Battery Mode", value: "Discharging")
    }
    .frame(width: 300)
    .background(Color(NSColor.controlBackgroundColor))
}

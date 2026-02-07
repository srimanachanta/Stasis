import SwiftUI

/// A grouped settings section with a rounded, elevated background
struct SettingsSection<Content: View>: View {
    let title: String?
    let description: String?
    let content: () -> Content

    init(
        title: String? = nil,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.description = description
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 4)
            }

            if let description = description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

/// Divider for use within settings sections
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

#Preview {
    VStack(spacing: 20) {
        SettingsSection(
            title: "Battery Health",
            description: nil
        ) {
            SettingsTextRow(
                label: "Battery Health",
                value: "Normal",
                tooltip: "Your battery is functioning normally"
            )
        }

        SettingsSection(
            title: "Energy Mode",
            description:
                "Your Mac can optimize either its battery usage with Low Power Mode, or its performance in resource-intensive tasks with High Power Mode."
        ) {
            SettingsPickerRow(
                label: "On battery",
                selection: .constant("Automatic"),
                options: [
                    ("Automatic", "Automatic"),
                    ("Low Power", "Low Power"),
                    ("High Power", "High Power"),
                ]
            )

            SettingsDivider()

            SettingsPickerRow(
                label: "On power adapter",
                selection: .constant("Automatic"),
                options: [
                    ("Automatic", "Automatic"),
                    ("Low Power", "Low Power"),
                    ("High Power", "High Power"),
                ]
            )
        }

        SettingsSection(title: "Preferences") {
            SettingsToggleRow(label: "Show in Menu Bar", isOn: .constant(true))
            SettingsDivider()
            SettingsToggleRow(label: "Launch at Login", isOn: .constant(false))
            SettingsDivider()
            SettingsStepperRow(
                label: "Update Interval",
                value: .constant(1),
                range: 1...60,
                suffix: "s"
            )
        }
    }
    .padding()
    .frame(width: 600)
}

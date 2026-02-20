import Defaults
import SwiftUI

struct GeneralSettingsView: View {
    @Default(.launchAtLogin) var launchAtLogin
    @Default(.showBatteryPercentageInStatusIcon) var showBatteryPercentageInStatusIcon
    @Default(.disableNotifications) var disableNotifications
    @Default(.showChargingStatusChangedNotification) var showChargingStatusChangedNotification

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
            }

            Section {
                Toggle("Show battery percentage", isOn: $showBatteryPercentageInStatusIcon)
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu Bar Icon")
                    Text(
                        "Display the current battery percentage next to the status icon in the menu bar."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Disable all notifications", isOn: $disableNotifications)
                Toggle("Charging status changed", isOn: $showChargingStatusChangedNotification)
                    .disabled(disableNotifications)
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")
                    Text("Control when Stasis sends you notifications.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0)
        .onChange(of: launchAtLogin) { _, newValue in
            LaunchAtLoginService.shared.setLaunchAtLogin(newValue)
        }
    }
}

#Preview {
    GeneralSettingsView()
}

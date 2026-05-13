import Defaults
import SwiftUI

struct GeneralSettingsView: View {
    @Default(.launchAtLogin) var launchAtLogin
    @Default(.showBatteryPercentageInStatusIcon) var showBatteryPercentageInStatusIcon
    @Default(.showBatteryPercentageInsideIconOnBattery) var showBatteryPercentageInsideIconOnBattery
    @Default(.showBatteryPercentageOutsideIconWhenPowered) var showBatteryPercentageOutsideIconWhenPowered
    @Default(.showBatteryStateInStatusIcon) var showBatteryStateInStatusIcon
    @Default(.disableNotifications) var disableNotifications
    @Default(.showChargingStatusChangedNotification) var showChargingStatusChangedNotification

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
            }

            Section {
                Toggle("Show battery percentage", isOn: $showBatteryPercentageInStatusIcon)
                Toggle(
                    "Show percentage inside icon on battery",
                    isOn: $showBatteryPercentageInsideIconOnBattery
                )
                .disabled(!showBatteryPercentageInStatusIcon)
                Toggle(
                    "Show outside percentage when on power",
                    isOn: $showBatteryPercentageOutsideIconWhenPowered
                )
                .disabled(
                    !showBatteryPercentageInStatusIcon
                        || !showBatteryPercentageInsideIconOnBattery
                )
                Toggle("Show battery state", isOn: $showBatteryStateInStatusIcon)
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu Bar Icon")
                    Text(
                        "Display battery percentage next to or inside the menu bar icon."
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

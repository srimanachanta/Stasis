import Defaults
import SwiftUI

struct GeneralSettingsView: View {
    @Default(.launchAtLogin) var launchAtLogin
    @Default(.batteryPercentageDisplayLocation) var batteryPercentageDisplayLocation
    @Default(.showBatteryStateInStatusIcon) var showBatteryStateInStatusIcon
    @Default(.showWattageInStatusIcon) var showWattageInStatusIcon
    @Default(.disableNotifications) var disableNotifications
    @Default(.showChargingStatusChangedNotification) var showChargingStatusChangedNotification

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
            }

            Section {
                Picker("Show percentage", selection: $batteryPercentageDisplayLocation) {
                    Text("Hidden").tag(PercentageDisplayLocation.hidden)
                    Text("Next to icon").tag(PercentageDisplayLocation.nextToIcon)
                    Text("Inside icon").tag(PercentageDisplayLocation.insideIcon)
                }
                Toggle("Show battery state", isOn: $showBatteryStateInStatusIcon)
                Toggle("Show wattage", isOn: $showWattageInStatusIcon)
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu Bar Icon")
                    Text(
                        "Customize battery percentage, state, and wattage in the menu bar icon."
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

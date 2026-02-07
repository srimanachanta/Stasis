import Defaults
import SwiftUI

struct DashboardSettingsView: View {
    @Default(.showTimeTillDischarge) var showTimeTillDischarge
    @Default(.showBatteryCycleCount) var showBatteryCycleCount
    @Default(.showBatteryHealth) var showBatteryHealth
    @Default(.showBatteryTemperature) var showBatteryTemperature
    @Default(.showPowerSource) var showPowerSource
    @Default(.showUptime) var showUptime
    @Default(.showLastDischarge) var showLastDischarge
    @Default(.showLastFullCharge) var showLastFullCharge
    @Default(.showBatteryMode) var showBatteryMode
    @Default(.showInternalPower) var showInternalPower
    @Default(.showExternalPower) var showExternalPower
    @Default(.showPowerDistribution) var showPowerDistribution

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Menu Dashboard")
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SettingsSection(
                        title: "Battery Information",
                        description:
                            "Choose which battery metrics to display in the menu dropdown."
                    ) {
                        SettingsToggleRow(
                            label: "Power source",
                            isOn: $showPowerSource,
                            tooltip: "Show whether on battery or AC power"
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            label: "Time until discharge",
                            isOn: $showTimeTillDischarge,
                            tooltip:
                                "Show estimated time until battery is empty"
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            label: "Uptime",
                            isOn: $showUptime,
                            tooltip:
                                "Show time since the system was last rebooted"
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            label: "Battery mode",
                            isOn: $showBatteryMode,
                            tooltip: "Show current battery charging mode"
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            label: "Battery temperature",
                            isOn: $showBatteryTemperature,
                            tooltip: "Show current battery temperature"
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            label: "Battery cycle count",
                            isOn: $showBatteryCycleCount,
                            tooltip: "Show total number of charge cycles"
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            label: "Battery health",
                            isOn: $showBatteryHealth,
                            tooltip: "Show battery health percentage"
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            label: "Internal power",
                            isOn: $showInternalPower,
                            tooltip: "Show internal battery voltage and current"
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            label: "External power",
                            isOn: $showExternalPower,
                            tooltip: "Show external adapter voltage and current"
                        )
                    }

                    SettingsSection(
                        title: "Visualizations",
                        description:
                            "Display charts and graphs of battery data."
                    ) {
                        SettingsToggleRow(
                            label: "Power distribution diagram",
                            isOn: $showPowerDistribution,
                            tooltip: "Show visual power flow diagram"
                        )
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 400)
    }
}

#Preview {
    DashboardSettingsView()
}

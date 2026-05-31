import Defaults
import SwiftUI

struct DashboardSettingsView: View {
    @Default(.showPowerSource) var showPowerSource
    @Default(.showTimeTillDischarge) var showTimeTillDischarge
    @Default(.showUptime) var showUptime
    @Default(.showBatteryMode) var showBatteryMode
    @Default(.showBatteryTemperature) var showBatteryTemperature
    @Default(.showBatteryCycleCount) var showBatteryCycleCount
    @Default(.showBatteryHealth) var showBatteryHealth
    @Default(.showInternalPower) var showInternalPower
    @Default(.showExternalPower) var showExternalPower
    @Default(.showPowerDistribution) var showPowerDistribution
    @Default(.showOutputPortsText) var showOutputPortsText
    @Default(.outputVisualizationMode) var outputVisualizationMode

    var body: some View {
        Form {
            Section {
                Toggle("Power source", isOn: $showPowerSource)
                Toggle("Time until discharge", isOn: $showTimeTillDischarge)
                Toggle("Uptime", isOn: $showUptime)
                Toggle("Battery mode", isOn: $showBatteryMode)
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                    Text(
                        "General system and battery status information shown in the menu dropdown."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Section("Battery Health") {
                Toggle("Cycle count", isOn: $showBatteryCycleCount)
                Toggle("Health", isOn: $showBatteryHealth)
                Toggle("Temperature", isOn: $showBatteryTemperature)
            }

            Section("Power") {
                Toggle("Battery Power Metrics", isOn: $showInternalPower)
                Toggle("Adapter Power Metrics", isOn: $showExternalPower)
            }

            Section("Visuals") {
                Toggle("Power distribution diagram", isOn: $showPowerDistribution)
                Picker("Show outgoing output", selection: $outputVisualizationMode) {
                    Text("Off").tag(OutputVisualizationMode.off)
                    Text("Power Only").tag(OutputVisualizationMode.powerOnly)
                    Text("Battery Only").tag(OutputVisualizationMode.batteryOnly)
                    Text("Always").tag(OutputVisualizationMode.always)
                }
                .disabled(!showPowerDistribution)
                Toggle("Output ports text row", isOn: $showOutputPortsText)
                    .disabled(!showPowerDistribution)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0)
    }
}

#Preview {
    DashboardSettingsView()
}

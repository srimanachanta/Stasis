import Defaults
import SwiftUI
import os.log

struct ChargingSettingsView: View {
    @Default(.manageCharging) var manageCharging
    @Default(.chargeLimit) var chargeLimit
    @Default(.sailingMode) var sailingMode
    @Default(.sailingModeLimit) var sailingModeLimit
    @Default(.automaticDischarge) var automaticDischarge
    @Default(.enableHeatProtectionMode) var enableHeatProtectionMode
    @Default(.heatProtectionLimit) var heatProtectionLimit
    @Default(.manageMagSafeLED) var manageMagSafeLED
    @Default(.heatProtectionMagSafeLEDState) var heatProtectionMagSafeLEDState
    @State private var installError: String?

    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "ChargingSettingsView"
    )

    private var sailingResumePercentage: Int {
        chargeLimit - sailingModeLimit
    }

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Manage charging",
                    isOn: Binding(
                        get: { manageCharging },
                        set: { newValue in
                            toggleManageCharging(newValue)
                        }
                    ))

                if manageCharging {
                    LabeledContent {
                        HStack(spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: { Double(chargeLimit) },
                                    set: { chargeLimit = Int($0) }
                                ), in: 50...100, step: 5
                            )
                            Text("\(chargeLimit)%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    } label: {
                        Text("Charge limit")
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Charge Management")
                    Text("Limit the maximum charge level to extend battery lifespan.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if manageCharging {
                Section {
                    Toggle("Enable sailing mode", isOn: $sailingMode)

                    if sailingMode {
                        LabeledContent {
                            HStack(spacing: 8) {
                                Slider(
                                    value: Binding(
                                        get: { Double(sailingModeLimit) },
                                        set: { sailingModeLimit = Int($0) }
                                    ), in: 1...20, step: 1
                                )
                                Text("\(sailingModeLimit)%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        } label: {
                            Text("Threshold below limit")
                        }

                        LabeledContent("Charging resumes at") {
                            Text("\(sailingResumePercentage)%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sailing Mode")
                        Text(
                            "Automatically resume charging when the battery drops below the threshold relative to your charge limit."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Automatic discharge", isOn: $automaticDischarge)
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Discharge")
                        Text(
                            "Discharge the battery to your charge limit when plugged in above the target level."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Enable heat protection", isOn: $enableHeatProtectionMode)

                    if enableHeatProtectionMode {
                        LabeledContent {
                            HStack(spacing: 8) {
                                Slider(
                                    value: Binding(
                                        get: { Double(heatProtectionLimit) },
                                        set: { heatProtectionLimit = Int($0) }
                                    ), in: 30...50, step: 1
                                )
                                Text("\(heatProtectionLimit)°C")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        } label: {
                            Text("Temperature limit")
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Heat Protection")
                        Text("Pause charging when the battery temperature exceeds the threshold.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Manage MagSafe LED", isOn: $manageMagSafeLED)

                    if manageMagSafeLED {
                        if enableHeatProtectionMode {
                            Picker(
                                "LED during heat protection",
                                selection: $heatProtectionMagSafeLEDState
                            ) {
                                Text("Off").tag(MagSafeLEDState.off)
                                Text("Green").tag(MagSafeLEDState.green)
                                Text("Orange").tag(MagSafeLEDState.orange)
                                Text("Blinking Orange").tag(MagSafeLEDState.blinkOrange)
                            }
                        }

                    }
                } header: {
                    Text("MagSafe LED Control")
                }
            }
        }
        .formStyle(.grouped)
        .animation(.default, value: manageCharging)
        .animation(.default, value: sailingMode)
        .animation(.default, value: enableHeatProtectionMode)
        .animation(.default, value: manageMagSafeLED)
        .alert(
            "Failed to install charging helper",
            isPresented: Binding(
                get: { installError != nil },
                set: { if !$0 { installError = nil } }
            )
        ) {
            Button("OK") { installError = nil }
        } message: {
            if let installError {
                Text(installError)
            }
        }
    }

    private func toggleManageCharging(_ enabled: Bool) {
        do {
            if enabled {
                try ChargingHelperManager.shared.install()
            } else {
                try ChargingHelperManager.shared.uninstall()
            }
            manageCharging = enabled
        } catch {
            logger.error("Failed to \(enabled ? "install" : "uninstall") charging helper: \(error)")
            installError = error.localizedDescription
        }
    }
}

#Preview {
    ChargingSettingsView()
}

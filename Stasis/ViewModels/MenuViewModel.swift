import AppKit
import Defaults
import Foundation
import Observation

@MainActor
@Observable
class MenuViewModel {
    private let batteryService: BatteryService
    private let chargeManager: ChargeManager
    private let bootTimestamp: Date?

    var batteryPercentageText: String = "0%"
    var powerSourceText: String = "Battery"
    var timeRemainingText: String = "Calculating..."
    var uptimeText: String = "0m"
    var batteryModeText: String = "Unknown"
    var batteryTemperatureText: String = "0°C"
    var externalInputText: String = "0V @ 0A"
    var internalInputText: String = "0V @ 0A"
    var cycleCountText: String = "0"
    var batteryHealthText: String = "100%"

    var displayPercentage: Int = 0
    var chargingMode: ChargingMode = .discharging
    var batteryPower: Double = 0
    var adapterPower: Double = 0
    var systemPower: Double = 0
    var outputPower: Double = 0
    var outputPortPowers: [OutputPortPower] = []
    var outputPortDetailsText: String = "None"
    var powerSource: PowerSource = .battery
    var isCharging: Bool = false
    var isLowPowerModeEnabled: Bool = false

    var chargeLimitOverrideActive: Bool { chargeManager.chargeLimitOverrideActive }
    var forceDischargeActive: Bool { chargeManager.forceDischargeActive }
    var manageChargingEnabled: Bool { Defaults[.manageCharging] }
    var adapterConnected: Bool = false

    private var metricsObservation: Task<Void, Never>?
    private var settingsObservation: Task<Void, Never>?
    private var uptimeTask: Task<Void, Never>?
    private var stableOutputPorts: [OutputPortPower] = []
    private var outputPortsHoldUntil: Date = .distantPast
    private var powerModeObservation: Task<Void, Never>?

    init(batteryService: BatteryService, chargeManager: ChargeManager) {
        self.batteryService = batteryService
        self.chargeManager = chargeManager
        self.bootTimestamp = SystemService.bootTimestamp()
        startObservingMetrics()
        startObservingSettings()
        startObservingPowerMode()
    }

    private func startObservingMetrics() {
        metricsObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.updateFormattedValues(
                    from: self.batteryService.metrics,
                    adapter: self.batteryService.adapterMetrics
                )
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.batteryService.metrics
                        _ = self.batteryService.adapterMetrics
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }

    private func startObservingSettings() {
        settingsObservation = Task { [weak self] in
            for await _ in Defaults.updates([.useHardwarePercentage], initial: false) {
                guard let self else { return }
                self.updateFormattedValues(
                    from: self.batteryService.metrics,
                    adapter: self.batteryService.adapterMetrics
                )
            }
        }
    }

    private func startObservingPowerMode() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        powerModeObservation = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .NSProcessInfoPowerStateDidChange,
                object: ProcessInfo.processInfo
            )
            for await _ in notifications {
                self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    func toggleChargeLimitOverride() {
        chargeManager.toggleChargeLimitOverride()
    }

    func toggleForceDischarge() {
        chargeManager.toggleForceDischarge()
    }

    private func updateFormattedValues(from metrics: BatteryMetrics, adapter: AdapterMetrics) {
        let useHardware = Defaults[.useHardwarePercentage]
        let percentage =
            useHardware
            ? metrics.hardwareBatteryPercentage : metrics.batteryPercentage
        displayPercentage = percentage
        batteryPercentageText = "\(percentage)%"

        let derivedPowerSource = derivePowerSource(battery: metrics, adapter: adapter)

        switch derivedPowerSource {
        case .battery:
            powerSourceText = "Battery"
        case .acAdapter:
            powerSourceText = "Power Adapter"
        case .both:
            powerSourceText = "Battery & Power Adapter"
        }

        let formatted = formatTimeRemaining(minutes: metrics.timeRemaining)
        if !formatted.isEmpty {
            timeRemainingText = formatted
        } else if derivedPowerSource == .acAdapter && !metrics.isCharging {
            timeRemainingText = "Not Charging"
        } else {
            timeRemainingText = "Calculating..."
        }

        updateUptimeText()

        if derivedPowerSource == .acAdapter {
            if metrics.isCharging {
                chargingMode = .charging
                batteryModeText = "Charging"
            } else {
                chargingMode = .pluggedIn
                batteryModeText = "Plugged In (Not Charging)"
            }
        } else {
            chargingMode = .discharging
            batteryModeText = "Discharging"
        }

        batteryTemperatureText =
            "\(metrics.batteryTemperature.formatted(.number.precision(.fractionLength(1))))°C"

        let voltageFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
        let currentFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))

        externalInputText =
            "\(adapter.adapterVoltage.formatted(voltageFormat))V @ \(adapter.adapterCurrent.formatted(currentFormat))A"

        internalInputText =
            "\(metrics.batteryVoltage.formatted(voltageFormat))V @ \(metrics.batteryCurrent.formatted(currentFormat))A"

        batteryPower = metrics.batteryPower
        adapterPower = adapter.adapterPower
        let totalLoadPower: Double = {
            if adapter.adapterConnected {
                return max(0, adapter.adapterPower - metrics.batteryPower)
            }
            return max(0, -metrics.batteryPower)
        }()
        let preferredOutputPower = max(0, metrics.outputPower)
        let rawOutputPower = preferredOutputPower

        let now = Date()
        if metrics.outputPorts.isEmpty, now < outputPortsHoldUntil, !stableOutputPorts.isEmpty {
            outputPortPowers = stableOutputPorts
        } else {
            outputPortPowers = metrics.outputPorts
            if !outputPortPowers.isEmpty {
                stableOutputPorts = outputPortPowers
                outputPortsHoldUntil = now.addingTimeInterval(2.5)
            }
        }

        let portsOutputPower = outputPortPowers.reduce(0) { $0 + $1.powerWatts }
        outputPower = min(totalLoadPower, max(portsOutputPower, min(totalLoadPower, rawOutputPower)))
        systemPower = max(0, totalLoadPower - outputPower)

        if outputPortPowers.isEmpty {
            outputPortDetailsText = "None"
        } else {
            outputPortDetailsText = outputPortPowers
                .map { "Port \($0.portIndex): \(Int($0.powerWatts.rounded())) W" }
                .joined(separator: " • ")
        }
        powerSource = derivedPowerSource
        isCharging = metrics.isCharging
        adapterConnected = adapter.adapterConnected

        cycleCountText = "\(metrics.cycleCount)"
        batteryHealthText = "\(metrics.batteryHealth)%"
    }

    private func derivePowerSource(battery: BatteryMetrics, adapter: AdapterMetrics) -> PowerSource {
        guard adapter.adapterConnected else { return .battery }

        if adapter.adapterPower == 0 {
            return .battery
        } else if battery.batteryPower >= 0 {
            return .acAdapter
        } else {
            return .both
        }
    }

    private func updateUptimeText() {
        guard let bootTimestamp else {
            uptimeText = "Unknown"
            return
        }

        let elapsed = Duration.seconds(Date().timeIntervalSince(bootTimestamp))
        uptimeText = elapsed.formatted(.units(
            allowed: [.days, .hours, .minutes],
            width: .condensedAbbreviated,
            zeroValueUnits: .hide
        ))
    }

    private func startUptimeTimer() {
        guard uptimeTask == nil else { return }

        uptimeTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                self?.updateUptimeText()
            }
        }
    }

    private func stopUptimeTimer() {
        uptimeTask?.cancel()
        uptimeTask = nil
    }

    func menuWillOpen() {
        updateUptimeText()
        startUptimeTimer()
        batteryService.enableFastPolling()
    }

    func menuDidClose() {
        stopUptimeTimer()
        batteryService.disableFastPolling()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func formatTimeRemaining(minutes: Int) -> String {
        if minutes < 0 {
            return ""
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }

    deinit {
        MainActor.assumeIsolated {
            metricsObservation?.cancel()
            settingsObservation?.cancel()
            uptimeTask?.cancel()
            powerModeObservation?.cancel()
        }
    }
}

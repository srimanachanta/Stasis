import AppKit
import Defaults
import Foundation
import Observation

@MainActor
@Observable
class MenuViewModel {
    private let batteryService: BatteryService
    private let systemService: SystemService

    var batteryPercentageText: String = "0%"
    var powerSourceText: String = "Battery"
    var timeRemainingText: String = "Calculating..."
    var uptimeText: String = "00:00"
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
    var powerSource: PowerSource = .Battery
    var isCharging: Bool = false

    private var metricsObservation: Task<Void, Never>?
    private var uptimeTask: Task<Void, Never>?

    init(batteryService: BatteryService, systemService: SystemService) {
        self.batteryService = batteryService
        self.systemService = systemService
        startObservingMetrics()
    }

    private func startObservingMetrics() {
        metricsObservation = Task { [weak self] in
            guard let self else { return }
            // Process the current value immediately, then re-process on each change
            while !Task.isCancelled {
                self.updateFormattedValues(from: self.batteryService.metrics)
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.batteryService.metrics
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }

    private func updateFormattedValues(from metrics: BatteryMetrics) {
        let useHardware = Defaults[.useHardwarePercentage]
        let percentage =
            useHardware
            ? metrics.hardwareBatteryPercentage : metrics.batteryPercentage
        displayPercentage = percentage
        batteryPercentageText = "\(percentage)%"

        switch metrics.powerSource {
        case .Battery:
            powerSourceText = "Battery"
        case .ACAdapter:
            powerSourceText = "Power Adapter"
        case .Both:
            powerSourceText = "Battery & Power Adapter"
        }

        let formatted = formatTimeRemaining(minutes: metrics.timeRemaining)
        timeRemainingText = formatted.isEmpty ? "Calculating..." : formatted

        updateUptimeText()

        if metrics.isCharging {
            chargingMode = .charging
            batteryModeText = "Charging"
        } else if metrics.adapterConnected {
            chargingMode = .pluggedIn
            batteryModeText = "Plugged In (Not Charging)"
        } else {
            chargingMode = .discharging
            batteryModeText = "Discharging"
        }

        batteryTemperatureText = String(
            format: "%.1f°C",
            metrics.batteryTemperature
        )

        externalInputText = String(
            format: "%.2fV @ %.2fA",
            metrics.adapterVoltage,
            metrics.adapterCurrent
        )

        internalInputText = String(
            format: "%.2fV @ %.2fA",
            metrics.batteryVoltage,
            metrics.batteryCurrent
        )

        batteryPower = metrics.batteryPower
        adapterPower = metrics.adapterPower
        systemPower = metrics.systemPower
        powerSource = metrics.powerSource
        isCharging = metrics.isCharging

        cycleCountText = "\(metrics.cycleCount)"
        batteryHealthText = "\(metrics.batteryHealth)%"
    }

    private func updateUptimeText() {
        guard let bootTimestamp = systemService.bootTimestamp else {
            uptimeText = "Unknown"
            return
        }

        let uptime = Date().timeIntervalSince(bootTimestamp)
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        uptimeText = String(format: "%02d:%02d", hours, minutes)
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

    deinit {
        MainActor.assumeIsolated {
            metricsObservation?.cancel()
            uptimeTask?.cancel()
        }
    }
}

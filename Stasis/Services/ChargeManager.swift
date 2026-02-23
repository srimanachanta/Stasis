import Defaults
import Foundation
import Observation
import UserNotifications
import os.log
import smc_power

@MainActor
@Observable
class ChargeManager {
    private let batteryService: BatteryService

    private var metricsObservation: Task<Void, Never>?
    private var settingsObservation: Task<Void, Never>?

    private var lastAdapterConnected: Bool?
    private var lastManageChargingEnabled: Bool?
    private var hasReachedChargeLimit = false
    private var lastNotifiedChargingState: Bool?

    private(set) var chargeLimitOverrideActive = false

    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "ChargeManager"
    )

    init(batteryService: BatteryService) {
        self.batteryService = batteryService
        startObservingMetrics()
        startObservingSettings()
    }

    private func startObservingMetrics() {
        metricsObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.evaluate(metrics: self.batteryService.metrics)
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

    private func startObservingSettings() {
        settingsObservation = Task { [weak self] in
            for await _ in Defaults.updates(
                [
                    .manageCharging, .sailingMode, .automaticDischarge,
                    .enableHeatProtectionMode, .manageMagSafeLED, .useHardwarePercentage,
                    .chargeLimit, .sailingModeLimit, .heatProtectionLimit,
                    .heatProtectionMagSafeLEDState,
                ],
                initial: false
            ) {
                guard let self else { return }
                self.evaluate(metrics: self.batteryService.metrics)
            }
        }
    }

    private func evaluate(metrics: BatteryMetrics) {
        if metrics.adapterConnected != lastAdapterConnected {
            logger.info("Adapter connection changed: \(metrics.adapterConnected)")
            lastAdapterConnected = metrics.adapterConnected
            clearCachedState()
        }

        guard Defaults[.manageCharging], metrics.adapterConnected else {
            if chargeLimitOverrideActive, !metrics.adapterConnected {
                chargeLimitOverrideActive = false
            }
            resetToDefaults()
            return
        }

        if lastManageChargingEnabled != true {
            lastManageChargingEnabled = true
            clearCachedState()
        }

        let chargeLimit = chargeLimitOverrideActive ? 100 : Defaults[.chargeLimit]
        let batteryPercentage =
            Defaults[.useHardwarePercentage]
            ? metrics.hardwareBatteryPercentage : metrics.batteryPercentage

        var desiredCharging: Bool?
        var desiredAdapter: Bool?
        var desiredLED: MagSafeLEDState?
        var chargingStateReason: String?

        if batteryPercentage > chargeLimit {
            hasReachedChargeLimit = true
            desiredCharging = false
            desiredAdapter = Defaults[.automaticDischarge] ? false : true
            desiredLED = Defaults[.manageMagSafeLED] ? .green : nil
            chargingStateReason = "Battery is above the charge limit of \(chargeLimit)%"
        } else if batteryPercentage == chargeLimit {
            hasReachedChargeLimit = true
            desiredCharging = false
            desiredAdapter = true
            desiredLED = Defaults[.manageMagSafeLED] ? .green : nil
            chargingStateReason = "Battery has reached the charge limit of \(chargeLimit)%"
        } else if Defaults[.sailingMode] {
            let sailingThreshold = chargeLimit - Defaults[.sailingModeLimit]
            let inSailingRange = batteryPercentage >= sailingThreshold

            if inSailingRange && hasReachedChargeLimit {
                desiredCharging = false
                desiredAdapter = true
                desiredLED = Defaults[.manageMagSafeLED] ? .green : nil
                chargingStateReason = "Sailing mode is maintaining charge below \(chargeLimit)%"
            } else {
                hasReachedChargeLimit = false
                desiredCharging = true
                desiredAdapter = true
                desiredLED = Defaults[.manageMagSafeLED] ? .orange : nil
                chargingStateReason =
                    inSailingRange
                    ? "Charging to reach charge limit of \(chargeLimit)%"
                    : "Battery dropped below sailing threshold of \(sailingThreshold)%"
            }
        } else {
            desiredCharging = true
            desiredAdapter = true
            desiredLED = Defaults[.manageMagSafeLED] ? .orange : nil
            chargingStateReason = "Battery is below the charge limit of \(chargeLimit)%"
        }

        if Defaults[.enableHeatProtectionMode]
            && metrics.batteryTemperature > Double(Defaults[.heatProtectionLimit])
        {
            desiredCharging = false
            chargingStateReason =
                "Battery temperature exceeds \(Defaults[.heatProtectionLimit])°C"
            if Defaults[.manageMagSafeLED] {
                desiredLED = Defaults[.heatProtectionMagSafeLEDState]
            }
        }

        let capabilities = batteryService.deviceCapabilities

        if let desiredCharging, capabilities.chargingControl {
            setCharging(enabled: desiredCharging)
            sendChargingStateNotification(
                charging: desiredCharging, reason: chargingStateReason
            )
        }
        if let desiredAdapter, capabilities.adapterControl {
            setAdapter(enabled: desiredAdapter)
        }
        if let desiredLED, capabilities.hasMagSafe, capabilities.magsafeLEDControl {
            setLED(state: desiredLED)
        }
    }

    private func clearCachedState() {
        lastNotifiedChargingState = nil
        hasReachedChargeLimit = false
    }

    private func resetToDefaults() {
        hasReachedChargeLimit = false
        lastManageChargingEnabled = false
        guard ChargingHelperManager.shared.isInstalled else { return }
        let capabilities = batteryService.deviceCapabilities
        if capabilities.chargingControl {
            setCharging(enabled: true)
        }
        if capabilities.adapterControl {
            setAdapter(enabled: true)
        }
        if capabilities.hasMagSafe, capabilities.magsafeLEDControl {
            setLED(state: .reset)
        }
    }

    private func setCharging(enabled: Bool) {
        logger.info("Setting charging: \(enabled)")
        Task {
            do {
                try await batteryService.manageBatteryCharging(enabled: enabled)
            } catch {
                logger.error("Failed to set charging to \(enabled): \(error)")
            }
        }
    }

    private func setAdapter(enabled: Bool) {
        logger.info("Setting adapter: \(enabled)")
        Task {
            do {
                try await batteryService.manageExternalPower(enabled: enabled)
            } catch {
                logger.error("Failed to set adapter to \(enabled): \(error)")
            }
        }
    }

    private func setLED(state: MagSafeLEDState) {
        logger.info("Setting MagSafe LED: \(String(describing: state))")
        Task {
            do {
                try await batteryService.manageMagsafeLED(target: state)
            } catch {
                logger.error("Failed to set LED to \(String(describing: state)): \(error)")
            }
        }
    }

    private func sendChargingStateNotification(charging: Bool, reason: String?) {
        guard charging != lastNotifiedChargingState else { return }
        lastNotifiedChargingState = charging

        guard !Defaults[.disableNotifications],
            Defaults[.showChargingStatusChangedNotification]
        else { return }

        let content = UNMutableNotificationContent()
        content.title = charging ? String(localized: "Charging Resumed") : String(localized: "Charging Paused")
        if let reason {
            content.body = reason
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "chargingStateChanged",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.error("Failed to deliver notification: \(error)")
            }
        }
    }

    func toggleChargeLimitOverride() {
        chargeLimitOverrideActive.toggle()
        evaluate(metrics: batteryService.metrics)
    }

    func stop() {
        metricsObservation?.cancel()
        metricsObservation = nil
        settingsObservation?.cancel()
        settingsObservation = nil
    }
}

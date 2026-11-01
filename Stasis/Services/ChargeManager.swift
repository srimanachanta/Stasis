import Defaults
import Foundation
import IOKit.pwr_mgt
import Observation
import UserNotifications
import os.log
import smc_power

private enum ChargeCommand {
    case charging
    case adapter
    case magSafeLED
    case nativeChargeLimit
}

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
    private(set) var forceDischargeActive = false
    private var commandErrors: [ChargeCommand: String] = [:]
    private var appliedNativeChargeLimit: Int?
    private var nativeChargeLimitDisableError: String?
    private var manageChargingObservation: Task<Void, Never>?
    private var sleepAssertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)

    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "ChargeManager"
    )

    var chargeManagementIssue: String? {
        guard Defaults[.manageCharging] else { return nativeChargeLimitDisableError }
        switch ChargingHelperManager.shared.helperStatus {
        case .notInstalled:
            return String(localized: "Charging helper is not installed. Reinstall it in Settings.")
        case .requiresApproval:
            return String(localized: "Approve Stasis in System Settings \u{2192} Login Items.")
        case .installed:
            return commandErrors.values.sorted().first
        }
    }

    init(batteryService: BatteryService) {
        self.batteryService = batteryService
        clampChargeLimitToNativeRange()
        startObservingMetrics()
        startObservingSettings()
        startObservingManageCharging()
    }

    private func clampChargeLimitToNativeRange() {
        let capabilities = batteryService.deviceCapabilities
        guard capabilities.usesNativeChargeLimit,
            let minimum = capabilities.nativeChargeLimits.first,
            Defaults[.chargeLimit] < minimum
        else { return }
        logger.info("Raising charge limit to the macOS minimum of \(minimum)%")
        Defaults[.chargeLimit] = minimum
    }

    private func startObservingMetrics() {
        metricsObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.evaluate(controlState: self.batteryService.controlState)
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.batteryService.controlState
                        _ = ChargingHelperManager.shared.helperStatus
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
                    .disableSleepUntilChargeLimit,
                    .enableHeatProtectionMode, .manageMagSafeLED, .useHardwarePercentage,
                    .chargeLimit, .sailingModeLimit, .heatProtectionLimit,
                    .heatProtectionMagSafeLEDState,
                ],
                initial: false
            ) {
                guard let self else { return }
                self.evaluate(controlState: self.batteryService.controlState)
            }
        }
    }

    private func startObservingManageCharging() {
        manageChargingObservation = Task { [weak self] in
            for await enabled in Defaults.updates(.manageCharging, initial: false) {
                guard let self else { return }
                self.nativeChargeLimitDisableError = nil
                if !enabled && self.batteryService.deviceCapabilities.usesNativeChargeLimit {
                    self.disableNativeChargeLimit()
                }
            }
        }
    }

    private func evaluate(controlState: BatteryControlState) {
        var stateWasCleared = false

        if controlState.adapterConnected != lastAdapterConnected {
            logger.info("Adapter connection changed: \(controlState.adapterConnected)")
            lastAdapterConnected = controlState.adapterConnected
            clearCachedState()
            stateWasCleared = true
        }

        guard Defaults[.manageCharging], controlState.adapterConnected else {
            if chargeLimitOverrideActive, !controlState.adapterConnected {
                chargeLimitOverrideActive = false
            }
            if forceDischargeActive, !controlState.adapterConnected {
                forceDischargeActive = false
            }
            resetToDefaults()
            return
        }

        guard ChargingHelperManager.shared.helperStatus == .installed else {
            updateSleepAssertion(shouldPreventSleep: false)
            return
        }

        if lastManageChargingEnabled != true {
            lastManageChargingEnabled = true
            clearCachedState()
            stateWasCleared = true
        }

        let chargeLimit = chargeLimitOverrideActive ? 100 : Defaults[.chargeLimit]
        let batteryPercentage =
            Defaults[.useHardwarePercentage]
            ? controlState.hardwareBatteryPercentage : controlState.batteryPercentage
        let capabilities = batteryService.deviceCapabilities

        if capabilities.usesNativeChargeLimit {
            evaluateNativeChargeLimit(
                chargeLimit: chargeLimit,
                batteryPercentage: batteryPercentage,
                capabilities: capabilities
            )
            return
        }

        if stateWasCleared && Defaults[.sailingMode]
            && batteryPercentage >= chargeLimit - Defaults[.sailingModeLimit] {
            hasReachedChargeLimit = true
        }

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
                let droppedOutOfSailingRange = !inSailingRange && hasReachedChargeLimit
                hasReachedChargeLimit = false
                desiredCharging = true
                desiredAdapter = true
                desiredLED = Defaults[.manageMagSafeLED] ? .orange : nil
                if inSailingRange {
                    chargingStateReason = "Charging to reach charge limit of \(chargeLimit)%"
                } else if droppedOutOfSailingRange {
                    chargingStateReason =
                        "Battery dropped below sailing threshold of \(sailingThreshold)%"
                } else {
                    chargingStateReason = "Battery is below the charge limit of \(chargeLimit)%"
                }
            }
        } else {
            desiredCharging = true
            desiredAdapter = true
            desiredLED = Defaults[.manageMagSafeLED] ? .orange : nil
            chargingStateReason = "Battery is below the charge limit of \(chargeLimit)%"
        }

        if Defaults[.enableHeatProtectionMode]
            && controlState.batteryTemperature > Double(Defaults[.heatProtectionLimit])
        {
            desiredCharging = false
            chargingStateReason =
                "Battery temperature exceeds \(Defaults[.heatProtectionLimit])°C"
            if Defaults[.manageMagSafeLED] {
                desiredLED = Defaults[.heatProtectionMagSafeLEDState]
            }
        }

        if forceDischargeActive {
            desiredCharging = false
            desiredAdapter = false
        }

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

        let shouldPreventSleep = Defaults[.disableSleepUntilChargeLimit]
            && desiredCharging == true
        updateSleepAssertion(shouldPreventSleep: shouldPreventSleep)
    }

    private func evaluateNativeChargeLimit(
        chargeLimit: Int,
        batteryPercentage: Int,
        capabilities: DeviceCapabilities
    ) {
        let nativeLimit =
            capabilities.nativeChargeLimits.first { $0 >= chargeLimit }
            ?? capabilities.nativeChargeLimits.last ?? chargeLimit
        if nativeLimit != appliedNativeChargeLimit {
            setNativeChargeLimit(nativeLimit)
        }

        let charging = !forceDischargeActive && batteryPercentage < nativeLimit
        let reason =
            charging
            ? "Battery is below the charge limit of \(nativeLimit)%"
            : "Battery has reached the charge limit of \(nativeLimit)%"
        sendChargingStateNotification(charging: charging, reason: reason)

        if capabilities.adapterControl {
            setAdapter(enabled: !forceDischargeActive)
        }
        if Defaults[.manageMagSafeLED], capabilities.hasMagSafe, capabilities.magsafeLEDControl {
            setLED(state: charging ? .orange : .green)
        }

        updateSleepAssertion(
            shouldPreventSleep: Defaults[.disableSleepUntilChargeLimit] && charging)
    }

    private func clearCachedState() {
        lastNotifiedChargingState = nil
        hasReachedChargeLimit = false
        // Re-sync on adapter changes in case the limit was changed in System Settings.
        appliedNativeChargeLimit = nil
    }

    private func resetToDefaults() {
        commandErrors.removeAll()
        hasReachedChargeLimit = false
        lastManageChargingEnabled = false
        updateSleepAssertion(shouldPreventSleep: false)
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
                commandSucceeded(.charging)
                batteryService.scheduleSinglePoll()
            } catch {
                logger.error("Failed to set charging to \(enabled): \(error)")
                commandFailed(.charging, error: error)
            }
        }
    }

    private func setAdapter(enabled: Bool) {
        logger.info("Setting adapter: \(enabled)")
        Task {
            do {
                try await batteryService.manageExternalPower(enabled: enabled)
                commandSucceeded(.adapter)
                batteryService.scheduleSinglePoll()
            } catch {
                logger.error("Failed to set adapter to \(enabled): \(error)")
                commandFailed(.adapter, error: error)
            }
        }
    }

    private func setLED(state: MagSafeLEDState) {
        logger.info("Setting MagSafe LED: \(String(describing: state))")
        Task {
            do {
                try await batteryService.manageMagsafeLED(target: state)
                commandSucceeded(.magSafeLED)
            } catch {
                logger.error("Failed to set LED to \(String(describing: state)): \(error)")
                commandFailed(.magSafeLED, error: error)
            }
        }
    }

    private func setNativeChargeLimit(_ limit: Int) {
        logger.info("Setting native charge limit: \(limit)%")
        // Set before the call completes so evaluations that run in the meantime don't resend it.
        appliedNativeChargeLimit = limit
        Task {
            do {
                try await batteryService.setNativeChargeLimit(limit)
                commandSucceeded(.nativeChargeLimit)
            } catch {
                logger.error("Failed to set native charge limit to \(limit)%: \(error)")
                if appliedNativeChargeLimit == limit {
                    appliedNativeChargeLimit = nil
                }
                commandFailed(.nativeChargeLimit, error: error)
            }
        }
    }

    private func disableNativeChargeLimit() {
        logger.info("Disabling native charge limit")
        appliedNativeChargeLimit = nil
        Task {
            do {
                try await batteryService.disableNativeChargeLimit()
            } catch {
                logger.error("Failed to disable native charge limit: \(error)")
                nativeChargeLimitDisableError = error.localizedDescription
            }
        }
    }

    private func commandSucceeded(_ command: ChargeCommand) {
        commandErrors[command] = nil
    }

    private func commandFailed(_ command: ChargeCommand, error: Error) {
        commandErrors[command] = error.localizedDescription
        // The daemon may have been removed from Login Items while the app was running.
        ChargingHelperManager.shared.refreshStatus()
    }

    private func updateSleepAssertion(shouldPreventSleep: Bool) {
        let assertionActive = sleepAssertionID != IOPMAssertionID(kIOPMNullAssertionID)

        if shouldPreventSleep && !assertionActive {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Stasis: Charging towards charge limit" as CFString,
                &sleepAssertionID
            )
            if result == kIOReturnSuccess {
                logger.info("Sleep assertion created")
            } else {
                logger.error("Failed to create sleep assertion: \(result)")
            }
        } else if !shouldPreventSleep && assertionActive {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
            logger.info("Sleep assertion released")
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
        evaluate(controlState: batteryService.controlState)
    }

    func toggleForceDischarge() {
        forceDischargeActive.toggle()
        evaluate(controlState: batteryService.controlState)
    }

    func stop() {
        metricsObservation?.cancel()
        metricsObservation = nil
        settingsObservation?.cancel()
        settingsObservation = nil
        manageChargingObservation?.cancel()
        manageChargingObservation = nil
        updateSleepAssertion(shouldPreventSleep: false)
    }
}

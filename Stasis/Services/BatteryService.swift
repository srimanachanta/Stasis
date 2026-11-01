import Foundation
import Observation
import os.log
import smc_types

enum XPCError: LocalizedError {
    case helperUnavailable
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .helperUnavailable:
            "XPC helper is unavailable"
        case .commandFailed(let message):
            "Command failed: \(message)"
        }
    }
}

@MainActor
@Observable
class BatteryService {
    var metrics = BatteryMetrics()
    var adapterMetrics = AdapterMetrics()
    private(set) var controlState = BatteryControlState()
    private(set) var deviceCapabilities = DeviceCapabilities(
        chargingControl: false,
        adapterControl: false,
        hasMagSafe: false,
        magsafeLEDControl: false
    )

    private let xpcManager = SMCReaderConnection(
        serviceName: "com.srimanachanta.stasis.helper"
    )
    private let ioKitService = IOKitService()
    private var nativeChargeLimit: NativeChargeLimit?

    private var ioKitMonitorTask: Task<Void, Never>?
    private var smcPollTask: Task<Void, Never>?
    private var delayedPollTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "BatteryService"
    )

    init() {
        logger.info("BatteryService initialized")
        xpcManager.connect()
        startIOKitMonitoring()
    }

    func loadCapabilities() async {
        guard
            let smcCapabilities: DeviceCapabilities = await callReaderHelper(
                "loading capabilities",
                { helper, reply in
                    helper.getCapabilities {
                        chargingControl, adapterControl, hasMagSafe, magsafeLEDControl in
                        reply(
                            DeviceCapabilities(
                                chargingControl: chargingControl,
                                adapterControl: adapterControl,
                                hasMagSafe: hasMagSafe,
                                magsafeLEDControl: magsafeLEDControl
                            ))
                    }
                })
        else {
            logger.warning("Helper unavailable for capability probe")
            return
        }

        // PowerUI makes synchronous XPC calls during setup, keep them off the main actor.
        let nativeChargeLimit = await Task.detached { NativeChargeLimit() }.value
        self.nativeChargeLimit = nativeChargeLimit

        let capabilities = DeviceCapabilities(
            chargingControl: smcCapabilities.chargingControl,
            adapterControl: smcCapabilities.adapterControl,
            hasMagSafe: smcCapabilities.hasMagSafe,
            magsafeLEDControl: smcCapabilities.magsafeLEDControl,
            nativeChargeLimits: nativeChargeLimit?.availableLimits ?? []
        )
        self.deviceCapabilities = capabilities
        logger.info(
            "Capabilities loaded: charging=\(capabilities.chargingControl), adapter=\(capabilities.adapterControl), magSafe=\(capabilities.hasMagSafe), nativeLimits=\(capabilities.nativeChargeLimits)"
        )
    }

    private func startIOKitMonitoring() {
        logger.info("Starting IOKit monitoring in main app")
        ioKitMonitorTask = Task {
            for await (newBatteryMetrics, newAdapterMetrics) in self.ioKitService.metricsStream() {
                guard !Task.isCancelled else { break }
                self.handleIOKitUpdate(newBatteryMetrics, adapterUpdate: newAdapterMetrics)
            }
        }
    }

    func enableFastPolling() {
        guard smcPollTask == nil else {
            logger.warning("Fast polling already enabled")
            return
        }

        logger.info("Enabling fast SMC polling")

        smcPollTask = Task {
            await self.pollSMCOnce()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await self.pollSMCOnce()
            }
        }
    }

    func scheduleSinglePoll(delay: Duration = .seconds(3)) {
        delayedPollTask?.cancel()
        delayedPollTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self.pollSMCOnce()
        }
    }

    func disableFastPolling() {
        guard smcPollTask != nil else {
            logger.warning("Fast polling not enabled")
            return
        }

        logger.info("Disabling fast SMC polling")
        smcPollTask?.cancel()
        smcPollTask = nil
    }

    private func fetchSMCBatteryData() async -> SMCBatteryReading? {
        await callReaderHelper("during SMC battery poll") { helper, reply in
            helper.readBatteryMetrics {
                batteryVoltage, batteryCurrent, batteryPower, batteryTemperature in
                reply(
                    SMCBatteryReading(
                        batteryVoltage: batteryVoltage,
                        batteryCurrent: batteryCurrent,
                        batteryPower: batteryPower,
                        batteryTemperature: batteryTemperature.isNaN ? nil : batteryTemperature
                    ))
            }
        }
    }

    private func fetchSMCAdapterData() async -> SMCAdapterReading? {
        await callReaderHelper("during SMC adapter poll") { helper, reply in
            helper.readAdapterMetrics { adapterVoltage, adapterCurrent, adapterPower in
                reply(
                    SMCAdapterReading(
                        adapterVoltage: adapterVoltage,
                        adapterCurrent: adapterCurrent,
                        adapterPower: adapterPower
                    ))
            }
        }
    }

    private func callReaderHelper<Reading: Sendable>(
        _ context: String,
        _ request: (HelperProtocol, @escaping @Sendable (Reading) -> Void) -> Void
    ) async -> Reading? {
        let logger = self.logger
        return await withCheckedContinuation { (continuation: CheckedContinuation<Reading?, Never>) in
            // XPC invokes either the reply or the error handler, never both. The error handler must
            // resume the continuation, otherwise a crashed reader service hangs the caller.
            guard
                let helper = xpcManager.getHelper(errorHandler: { error in
                    logger.error("XPC error \(context): \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                })
            else {
                continuation.resume(returning: nil)
                return
            }
            request(helper) { reading in
                continuation.resume(returning: reading)
            }
        }
    }

    private func pollSMCOnce() async {
        async let batteryData = fetchSMCBatteryData()
        async let adapterData = fetchSMCAdapterData()

        guard let batteryReading = await batteryData, let adapterReading = await adapterData else {
            logger.error("No helper available for SMC battery polling")
            return
        }

        var updatedBattery = metrics
        updatedBattery.batteryVoltage = batteryReading.batteryVoltage
        updatedBattery.batteryCurrent = batteryReading.batteryCurrent
        updatedBattery.batteryPower = batteryReading.batteryPower
        if let batteryTemperature = batteryReading.batteryTemperature {
            updatedBattery.batteryTemperature = batteryTemperature
        }

        var updatedAdapter = adapterMetrics
        updatedAdapter.adapterVoltage = adapterReading.adapterVoltage
        updatedAdapter.adapterCurrent = adapterReading.adapterCurrent
        updatedAdapter.adapterPower = adapterReading.adapterPower

        // SMC reports faster than IOKit can update, so refine isCharging
        // using the actual power flow direction.
        if updatedAdapter.adapterConnected {
            updatedBattery.isCharging = batteryReading.batteryPower > 0
        }

        if updatedBattery != metrics {
            metrics = updatedBattery
        }
        if updatedAdapter != adapterMetrics {
            adapterMetrics = updatedAdapter
        }
        updateControlState(from: updatedBattery, adapter: updatedAdapter)
    }

    private func handleIOKitUpdate(_ newBatteryMetrics: BatteryMetrics, adapterUpdate: AdapterMetrics) {
        logger.debug("Received IOKit update")

        var updatedBattery = newBatteryMetrics
        updatedBattery.batteryVoltage = metrics.batteryVoltage
        updatedBattery.batteryCurrent = metrics.batteryCurrent
        updatedBattery.batteryPower = metrics.batteryPower
        // macOS 27 no longer reports temperature through IOKit (0 means missing); keep the SMC reading.
        if updatedBattery.batteryTemperature == 0 {
            updatedBattery.batteryTemperature = metrics.batteryTemperature
        }

        if updatedBattery != metrics {
            metrics = updatedBattery
        }

        var updatedAdapter = adapterUpdate
        updatedAdapter.adapterVoltage = adapterMetrics.adapterVoltage
        updatedAdapter.adapterCurrent = adapterMetrics.adapterCurrent
        updatedAdapter.adapterPower = adapterMetrics.adapterPower

        if updatedAdapter != adapterMetrics {
            adapterMetrics = updatedAdapter
        }

        updateControlState(from: updatedBattery, adapter: updatedAdapter)
    }

    private func updateControlState(from metrics: BatteryMetrics, adapter: AdapterMetrics) {
        let newState = BatteryControlState(
            batteryPercentage: metrics.batteryPercentage,
            hardwareBatteryPercentage: metrics.hardwareBatteryPercentage,
            adapterConnected: adapter.adapterConnected,
            batteryTemperature: metrics.batteryTemperature
        )
        if newState != controlState {
            controlState = newState
        }
    }

    func manageBatteryCharging(enabled: Bool) async throws {
        try await callChargingHelper { helper, reply in
            helper.manageBatteryCharging(enabled: enabled, reply: reply)
        }
    }

    func manageExternalPower(enabled: Bool) async throws {
        try await callChargingHelper { helper, reply in
            helper.manageExternalPower(enabled: enabled, reply: reply)
        }
    }

    func manageMagsafeLED(target: MagSafeLEDState) async throws {
        try await callChargingHelper { helper, reply in
            helper.manageMagsafeLED(target: target.rawValue, reply: reply)
        }
    }

    func setNativeChargeLimit(_ limit: Int) async throws {
        guard let nativeChargeLimit else { throw NativeChargeLimitError.unavailable }
        try await nativeChargeLimit.apply(limit: limit)
    }

    func disableNativeChargeLimit() async throws {
        guard let nativeChargeLimit else { throw NativeChargeLimitError.unavailable }
        try await nativeChargeLimit.disable()
    }

    func currentNativeChargeLimit() async throws -> Int? {
        guard let nativeChargeLimit else { throw NativeChargeLimitError.unavailable }
        return try await nativeChargeLimit.currentLimit()
    }

    func nativeChargeLimitChanges() -> AsyncStream<Void>? {
        nativeChargeLimit?.changes()
    }

    private func callChargingHelper(
        _ command: (ChargingHelperProtocol, @escaping @Sendable (Bool, String?) -> Void) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // XPC invokes either the reply or the error handler, never both. The error
            // handler must resume the continuation, otherwise a missing daemon hangs the caller.
            guard
                let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                    continuation.resume(throwing: error)
                })
            else {
                continuation.resume(throwing: XPCError.helperUnavailable)
                return
            }
            command(helper) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func stop() {
        logger.info("BatteryService stopping")
        ioKitMonitorTask?.cancel()
        ioKitMonitorTask = nil
        smcPollTask?.cancel()
        smcPollTask = nil
        delayedPollTask?.cancel()
        delayedPollTask = nil
        xpcManager.disconnect()
    }
}

import Foundation
import Observation
import os.log

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

    private let xpcManager = SMCReaderConnection(
        serviceName: "com.srimanachanta.stasis.helper"
    )
    private let ioKitService = IOKitService()

    private var ioKitMonitorTask: Task<Void, Never>?
    private var smcPollTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "BatteryService"
    )

    init() {
        logger.info("BatteryService initialized")

        xpcManager.connect()
        startIOKitMonitoring()
    }

    private func startIOKitMonitoring() {
        logger.info("Starting IOKit monitoring in main app")
        ioKitMonitorTask = Task {
            for await newMetrics in self.ioKitService.metricsStream() {
                guard !Task.isCancelled else { break }
                self.handleIOKitUpdate(newMetrics)
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

    func disableFastPolling() {
        guard smcPollTask != nil else {
            logger.warning("Fast polling not enabled")
            return
        }

        logger.info("Disabling fast SMC polling")
        smcPollTask?.cancel()
        smcPollTask = nil
    }

    private func fetchSMCPowerData() async -> SMCPowerReading? {
        let logger = self.logger
        guard
            let helper = xpcManager.getHelper(errorHandler: { error in
                logger.error(
                    "XPC error during SMC poll: \(error.localizedDescription)"
                )
            })
        else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            helper.readBatteryMetrics {
                batteryVoltage, batteryCurrent, batteryPower, externalVoltage, externalCurrent,
                externalPower, systemPower in
                continuation.resume(
                    returning: SMCPowerReading(
                        batteryVoltage: batteryVoltage,
                        batteryCurrent: batteryCurrent,
                        batteryPower: batteryPower,
                        externalVoltage: externalVoltage,
                        externalCurrent: externalCurrent,
                        externalPower: externalPower,
                        systemPower: systemPower,
                    )
                )
            }
        }
    }

    private func pollSMCOnce() async {
        guard let reading = await fetchSMCPowerData() else {
            logger.error("No helper available for SMC polling")
            return
        }

        logger.debug(
            "SMC read: battery=\(reading.batteryPower)W, external=\(reading.externalPower)W, system=\(reading.systemPower)"
        )

        var updated = metrics
        updated.batteryVoltage = reading.batteryVoltage
        updated.batteryCurrent = reading.batteryCurrent
        updated.batteryPower = reading.batteryPower
        updated.adapterVoltage = reading.externalVoltage
        updated.adapterCurrent = reading.externalCurrent
        updated.adapterPower = reading.externalPower
        updated.systemPower = reading.systemPower

        // SMC reports faster than IOKit can update. This fixes the case where the UI falsely shows power flowing from the battery to the system even though 100% of system power is from the AC Adapter
        if updated.adapterConnected {
            if reading.externalPower == 0 {
                updated.powerSource = .battery
            } else if reading.batteryPower >= 0 {
                updated.powerSource = .acAdapter
            } else {
                updated.powerSource = .both
            }

            updated.isCharging = reading.batteryPower > 0
        }

        if updated != metrics {
            metrics = updated
        }
    }

    private func handleIOKitUpdate(_ newMetrics: BatteryMetrics) {
        logger.debug("Received IOKit update")
        var updated = newMetrics
        updated.batteryVoltage = metrics.batteryVoltage
        updated.batteryCurrent = metrics.batteryCurrent
        updated.batteryPower = metrics.batteryPower
        updated.adapterVoltage = metrics.adapterVoltage
        updated.adapterCurrent = metrics.adapterCurrent
        updated.adapterPower = metrics.adapterPower
        updated.systemPower = metrics.systemPower

        if updated != metrics {
            metrics = updated
        }
    }

    func manageBatteryCharging(enabled: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let helper = self.getChargingHelper(continuation: continuation)
            guard let helper else { return }
            helper.manageBatteryCharging(enabled: enabled) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func manageExternalPower(enabled: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let helper = self.getChargingHelper(continuation: continuation)
            guard let helper else { return }
            helper.manageExternalPower(enabled: enabled) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func manageMagsafeLED(target: MagSafeLEDState) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let helper = self.getChargingHelper(continuation: continuation)
            guard let helper else { return }
            helper.manageMagsafeLED(target: target.rawValue) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: XPCError.commandFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    private func getChargingHelper(
        continuation: CheckedContinuation<Void, any Error>
    ) -> ChargingHelperProtocol? {
        guard
            let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                continuation.resume(throwing: error)
            })
        else {
            continuation.resume(throwing: XPCError.helperUnavailable)
            return nil
        }
        return helper
    }

    func stop() {
        logger.info("BatteryService stopping")
        ioKitMonitorTask?.cancel()
        ioKitMonitorTask = nil
        smcPollTask?.cancel()
        smcPollTask = nil
        xpcManager.disconnect()
    }
}

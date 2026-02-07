import Foundation
import Observation
import os.log

struct SMCPowerReading {
    var batteryPower: Double
    var adapterPower: Double
    var systemPower: Double
}

@MainActor
@Observable
class BatteryService {
    var metrics = BatteryMetrics()

    private let xpcManager = XPCConnectionManager(
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
        ioKitMonitorTask = Task { [weak self] in
            guard let self else { return }
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

        smcPollTask = Task { [weak self] in
            guard let self else { return }
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
        guard
            let helper = xpcManager.getHelper(errorHandler: {
                [weak self] error in
                Task { @MainActor in
                    self?.logger.error(
                        "XPC error during SMC poll: \(error.localizedDescription)"
                    )
                }
            })
        else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            helper.readSMCPower { batteryPower, externalPower, systemPower in
                continuation.resume(
                    returning: SMCPowerReading(
                        batteryPower: batteryPower,
                        adapterPower: externalPower,
                        systemPower: systemPower
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
            "SMC read: battery=\(reading.batteryPower)W, external=\(reading.adapterPower)W, system=\(reading.systemPower)"
        )

        var updated = metrics
        updated.batteryPower = reading.batteryPower
        updated.adapterPower = reading.adapterPower
        updated.systemPower = reading.systemPower

        // SMC reports faster than IOKit can update. This fixes the case where the UI falsely shows power flowing from the battery to the system even though 100% of system power is from the AC Adapter
        if updated.adapterConnected && reading.batteryPower > 0 {
            updated.powerSource = .ACAdapter
        }

        if updated != metrics {
            metrics = updated
        }
    }

    private func handleIOKitUpdate(_ newMetrics: BatteryMetrics) {
        logger.debug("Received IOKit update")
        var updated = newMetrics
        updated.batteryPower = metrics.batteryPower
        updated.adapterPower = metrics.adapterPower
        updated.systemPower = metrics.systemPower

        if updated != metrics {
            metrics = updated
        }
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

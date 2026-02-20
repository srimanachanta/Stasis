import Foundation
import os.log
import smc_power

private enum Constants {
    static let helperSubsystem = "com.srimanachanta.stasis.helper"
}

final class Helper: NSObject, HelperProtocol {
    private let logger = Logger(
        subsystem: Constants.helperSubsystem,
        category: "Helper"
    )

    func readBatteryMetrics(
        reply: @escaping @Sendable (Double, Double, Double, Double, Double, Double, Double) -> Void
    ) {
        do {
            let batteryVoltage = try SMCBattery.getVoltage()
            let batteryCurrent = try SMCBattery.getCurrent()
            var externalVoltage = try SMCAdapter.getVoltage()
            var externalCurrent = try SMCAdapter.getCurrent()

            if abs(externalVoltage) < 0.1 { externalVoltage = 0 }
            if abs(externalCurrent) < 0.1 { externalCurrent = 0 }

            let batteryPower = batteryVoltage * batteryCurrent
            let externalPower = externalVoltage * externalCurrent
            let systemPower = externalPower - batteryPower

            reply(
                batteryVoltage, batteryCurrent, batteryPower,
                externalVoltage, externalCurrent, externalPower,
                systemPower
            )
        } catch {
            logger.error("SMC power read failed: \(error.localizedDescription)")
            reply(0, 0, 0, 0, 0, 0, 0)
        }
    }

    func getCapabilities(reply: @escaping @Sendable (Bool, Bool, Bool, Bool) -> Void) {
        do {
            let battery = try SMCBattery.probe()
            let adapter = try SMCAdapter.probe()
            let capabilities = DeviceCapabilities.from(
                battery: battery.capabilities,
                adapter: adapter.capabilities
            )
            logger.info(
                "Probed capabilities (charging=\(capabilities.chargingControl), adapter=\(capabilities.adapterControl), magSafe=\(capabilities.hasMagSafe))"
            )
            reply(
                capabilities.chargingControl,
                capabilities.adapterControl,
                capabilities.hasMagSafe,
                capabilities.magsafeLEDControl
            )
        } catch {
            logger.error("Failed to probe capabilities: \(error.localizedDescription)")
            reply(false, false, false, false)
        }
    }
}

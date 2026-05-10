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
        reply: @escaping @Sendable (Double, Double, Double) -> Void
    ) {
        do {
            let batteryVoltage = try SMCBattery.getVoltage()
            let batteryCurrent = try SMCBattery.getCurrent()
            let batteryPower = batteryVoltage * batteryCurrent

            reply(batteryVoltage, batteryCurrent, batteryPower)
        } catch {
            logger.error("SMC battery read failed: \(error.localizedDescription)")
            reply(0, 0, 0)
        }
    }

    func readAdapterMetrics(
        reply: @escaping @Sendable (Double, Double, Double) -> Void
    ) {
        do {
            var adapterVoltage = try SMCAdapter.getVoltage()
            var adapterCurrent = try SMCAdapter.getCurrent()

            if abs(adapterVoltage) < 0.1 { adapterVoltage = 0 }
            if abs(adapterCurrent) < 0.1 { adapterCurrent = 0 }

            let adapterPower = adapterVoltage * adapterCurrent

            reply(adapterVoltage, adapterCurrent, adapterPower)
        } catch {
            logger.error("SMC adapter read failed: \(error.localizedDescription)")
            reply(0, 0, 0)
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

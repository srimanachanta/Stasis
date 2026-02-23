import Foundation
import os.log
import smc_power

private enum Constants {
    static let subsystem = "com.srimanachanta.stasis.charging-helper"
}

final class ChargingHelper: NSObject, ChargingHelperProtocol {
    private let battery: SMCBattery
    private let adapter: SMCAdapter
    private let logger = Logger(
        subsystem: Constants.subsystem,
        category: "ChargingHelper"
    )

    init(battery: SMCBattery, adapter: SMCAdapter) {
        self.battery = battery
        self.adapter = adapter
        super.init()
        logger.info(
            "Initialized (charging=\(battery.capabilities.inhibitChargeControl), discharge=\(battery.capabilities.forceDischargeControl), magSafe=\(adapter.capabilities.magSafeControl))"
        )
    }

    func manageBatteryCharging(enabled: Bool, reply: @escaping @Sendable (Bool, String?) -> Void) {
        do {
            guard battery.capabilities.inhibitChargeControl else {
                reply(false, "Charging control is not supported on this device")
                return
            }
            let currentlyInhibited = try battery.getChargingInhibited()
            if currentlyInhibited != !enabled {
                try battery.setChargingInhibited(!enabled)
                logger.debug("SMC set charging inhibited to: \(!enabled)")
            }
            reply(true, nil)
        } catch {
            logger.error("manageBatteryCharging failed: \(error.localizedDescription)")
            reply(false, error.localizedDescription)
        }
    }

    func manageExternalPower(enabled: Bool, reply: @escaping @Sendable (Bool, String?) -> Void) {
        do {
            guard battery.capabilities.forceDischargeControl else {
                reply(false, "Adapter control is not supported on this device")
                return
            }
            let currentlyDischarging = try battery.getForceDischarging()
            if currentlyDischarging != !enabled {
                try battery.setForceDischarging(!enabled)
                logger.debug("SMC set force discharging to: \(!enabled)")
            }
            reply(true, nil)
        } catch {
            logger.error("manageExternalPower failed: \(error.localizedDescription)")
            reply(false, error.localizedDescription)
        }
    }

    func manageMagsafeLED(target: UInt8, reply: @escaping @Sendable (Bool, String?) -> Void) {
        do {
            guard adapter.capabilities.magSafeControl else {
                reply(false, "MagSafe LED control is not supported on this device")
                return
            }
            guard let ledState = MagSafeLEDState(rawValue: target) else {
                reply(false, "Invalid MagSafe LED state: \(target)")
                return
            }
            let currentState = try adapter.getMagSafeLEDState()
            if currentState != ledState {
                try adapter.setMagSafeLEDState(ledState)
                logger.debug("SMC MagSafe LED set to: \(ledState.rawValue)")
            }
            reply(true, nil)
        } catch {
            logger.error("manageMagsafeLED failed: \(error.localizedDescription)")
            reply(false, error.localizedDescription)
        }
    }

    func resetToDefaults() {
        do {
            if battery.capabilities.inhibitChargeControl {
                try battery.setChargingInhibited(false)
            }
            if battery.capabilities.forceDischargeControl {
                try battery.setForceDischarging(false)
            }
            if adapter.capabilities.magSafeControl {
                try adapter.setMagSafeLEDState(.reset)
            }
            logger.info("SMC keys reset to defaults")
        } catch {
            logger.error("resetToDefaults failed: \(error.localizedDescription)")
        }
    }
}

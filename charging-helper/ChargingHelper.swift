import Foundation
import SMCKit
import os.log

private enum Constants {
    static let subsystem = "com.srimanachanta.stasis.charging-helper"
}

final class ChargingHelper: NSObject, ChargingHelperProtocol, Sendable {
    private static let chargingKey = FourCharCode(fromStaticString: "CHTE")
    private static let adapterKey = FourCharCode(fromStaticString: "CHIE")
    private static let magsafeLEDKey = FourCharCode(fromStaticString: "ACLC")

    private let logger = Logger(
        subsystem: Constants.subsystem,
        category: "ChargingHelper"
    )

    override init() {
        super.init()
        logger.info("ChargingHelper daemon initialized")
    }

    func manageBatteryCharging(enabled: Bool, reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task {
            do {
                let value: UInt32 = enabled ? 0 : 1
                try await SMCKit.shared.write(Self.chargingKey, value)
                self.logger.debug("SMC set charging state to: \(enabled)")
                reply(true, nil)
            } catch {
                self.logger.error("manageBatteryCharging failed: \(error.localizedDescription)")
                reply(false, error.localizedDescription)
            }
        }
    }

    func manageExternalPower(enabled: Bool, reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task {
            do {
                let value = Data(enabled ? [0x00] : [0x08])
                try await SMCKit.shared.writeData(Self.adapterKey, value)
                self.logger.debug("SMC set adapter state to: \(enabled)")
                reply(true, nil)
            } catch {
                self.logger.error("manageExternalPower failed: \(error.localizedDescription)")
                reply(false, error.localizedDescription)
            }
        }
    }

    func manageMagsafeLED(target: UInt8, reply: @escaping @Sendable (Bool, String?) -> Void) {
        Task {
            do {
                guard let state = MagSafeLEDState(rawValue: target) else {
                    reply(false, "Invalid MagSafe LED state: \(target)")
                    return
                }
                try await SMCKit.shared.write(Self.magsafeLEDKey, state.rawValue)
                self.logger.debug("SMC MagSafeLED write successful to: \(state.rawValue)")
                reply(true, nil)
            } catch {
                self.logger.error("manageMagsafeLED failed: \(error.localizedDescription)")
                reply(false, error.localizedDescription)
            }
        }
    }

    func resetToDefaults() {
        Task {
            do {
                try await SMCKit.shared.write(Self.chargingKey, UInt32(0))
                try await SMCKit.shared.writeData(Self.adapterKey, Data([0x00]))
                try await SMCKit.shared.write(Self.magsafeLEDKey, MagSafeLEDState.reset.rawValue)
                self.logger.info("SMC keys reset to defaults")
            } catch {
                self.logger.error("resetToDefaults failed: \(error.localizedDescription)")
            }
        }
    }
}

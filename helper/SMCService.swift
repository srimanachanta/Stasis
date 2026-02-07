import Foundation
import SMCKit
import os.log

struct PowerReading {
    let batteryPower: Double
    let externalPower: Double
    let systemPower: Double
}

class SMCService {
    // SMC keys for power sensors
    private static let batteryPowerKey = FourCharCode(fromStaticString: "SBAP")  // Battery discharge/charge power
    private static let externalPowerKey = FourCharCode(fromStaticString: "PDTR")  // AC adapter delivery power

    // Values below this threshold (in watts) are treated as zero to filter sensor noise
    private static let noiseFloor: Double = 0.01

    private let logger = Logger(
        subsystem: Constants.helperSubsystem,
        category: "SMCService"
    )

    func readPower() async throws -> PowerReading {
        let batteryPowerRaw: Float = try await SMCKit.shared.read(
            Self.batteryPowerKey
        )
        let externalPowerRaw: Float = try await SMCKit.shared.read(
            Self.externalPowerKey
        )

        // SMC reports these values with inverted sign (negative = delivering power),
        // so we negate to get conventional positive-means-delivering semantics.
        var batteryPower = Double(-batteryPowerRaw)
        var externalPower = Double(-externalPowerRaw)

        if abs(batteryPower) < Self.noiseFloor {
            batteryPower = 0
        }

        if abs(externalPower) < Self.noiseFloor {
            externalPower = 0
        }

        // System power is the total drawn from all sources
        let systemPower = -(externalPower + batteryPower)

        logger.debug(
            "SMC read successful: battery=\(batteryPower)W, external=\(externalPower)W, system=\(systemPower)W"
        )

        return PowerReading(
            batteryPower: batteryPower,
            externalPower: externalPower,
            systemPower: systemPower
        )
    }
}

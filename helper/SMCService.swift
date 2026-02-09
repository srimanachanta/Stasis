import Foundation
import SMCKit
import os.log

final class SMCService: Sendable {
    private static let batteryVoltageKey = FourCharCode(fromStaticString: "B0AV")
    private static let batteryCurrentKey = FourCharCode(fromStaticString: "B0AC")
    private static let externalVoltageKey = FourCharCode(fromStaticString: "VD0R")
    private static let externalCurrentKey = FourCharCode(fromStaticString: "ID0R")

    private let logger = Logger(
        subsystem: Constants.helperSubsystem,
        category: "SMCService"
    )

    func readBatteryMetrics() async throws -> SMCPowerReading {
        let batteryVoltageRaw: UInt16 = try await SMCKit.shared.read(Self.batteryVoltageKey)
        let batteryCurrentRaw: Int16 = try await SMCKit.shared.read(Self.batteryCurrentKey)

        let batteryVoltage = Double(batteryVoltageRaw) / 1000.0
        let batteryCurrent = Double(batteryCurrentRaw) / 1000.0

        let externalVoltageRaw: Float = try await SMCKit.shared.read(Self.externalVoltageKey)
        let externalCurrentRaw: Float = try await SMCKit.shared.read(Self.externalCurrentKey)

        var externalVoltage = Double(externalVoltageRaw)
        var externalCurrent = Double(externalCurrentRaw)

        if abs(externalVoltage) < 0.1 {
            externalVoltage = 0
        }

        if abs(externalCurrent) < 0.1 {
            externalCurrent = 0
        }

        let batteryPower = batteryVoltage * batteryCurrent
        let externalPower = externalVoltage * externalCurrent
        let systemPower = externalPower - batteryPower

        logger.debug(
            "SMC power read successful: battery=\(batteryPower)W, external=\(externalPower)W, system=\(systemPower)W"
        )

        return SMCPowerReading(
            batteryVoltage: batteryVoltage,
            batteryCurrent: batteryCurrent,
            batteryPower: batteryPower,
            externalVoltage: externalVoltage,
            externalCurrent: externalCurrent,
            externalPower: externalPower,
            systemPower: systemPower
        )
    }

}

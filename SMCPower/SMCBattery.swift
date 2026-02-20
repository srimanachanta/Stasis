import Foundation
import SMCKit

public enum SMCBatteryError: Error, Sendable {
    case unsupportedCapability
}

public struct BatteryCapabilities: Codable, Sendable {
    public let inhibitChargeControl: Bool
    public let forceDischargeControl: Bool
}

/*
 * Based on:
 * https://github.com/AsahiLinux/linux/blob/79a307df1e18f144610742ac9ee60080c3983875/drivers/power/supply/macsmc-power.c
 * https://github.com/mhaeuser/Battery-Toolkit/blob/ed3adf103abfdad53223ce6f0a764ae7163c385b/Libraries/SMCComm%2BPower.swift
 * https://github.com/acidanthera/VirtualSMC/blob/55b89a23f51beda82581dbab795615838a3e6e56/Docs/SMCSensorKeys.txt
 */
public struct SMCBattery: Sendable {
    public let capabilities: BatteryCapabilities

    private let hasCH0C: Bool
    private let hasCHTE: Bool
    private let hasCH0I: Bool
    private let hasCHIE: Bool

    public static func probe() throws -> SMCBattery {
        let hasCH0C = try SMCKit.shared.isKeyFound("CH0C")
        let hasCHTE = try SMCKit.shared.isKeyFound("CHTE")
        let hasCH0I = try SMCKit.shared.isKeyFound("CH0I")
        let hasCHIE = try SMCKit.shared.isKeyFound("CHIE")

        let capabilities = BatteryCapabilities(
            inhibitChargeControl: hasCH0C || hasCHTE,
            forceDischargeControl: hasCH0I || hasCHIE
        )

        return SMCBattery(
            capabilities: capabilities,
            hasCH0C: hasCH0C,
            hasCHTE: hasCHTE,
            hasCH0I: hasCH0I,
            hasCHIE: hasCHIE
        )
    }
    
    private init(capabilities: BatteryCapabilities, hasCH0C: Bool, hasCHTE: Bool, hasCH0I: Bool, hasCHIE: Bool) {
        self.capabilities = capabilities
        self.hasCH0C = hasCH0C
        self.hasCHTE = hasCHTE
        self.hasCH0I = hasCH0I
        self.hasCHIE = hasCHIE
    }

    public static func getVoltage() throws -> Double {
        Double(try SMCKit.shared.read("B0AV") as UInt16) / 1000.0
    }

    public static func getCurrent() throws -> Double {
        Double(try SMCKit.shared.read("B0AC") as Int16) / 1000.0
    }

    public func getChargingInhibited() throws -> Bool {
        guard capabilities.inhibitChargeControl else { throw SMCBatteryError.unsupportedCapability }

        if hasCHTE {
            let value: UInt32 = try SMCKit.shared.read("CHTE")
            return value != 0
        } else {
            let value: UInt8 = try SMCKit.shared.read("CH0C")
            return value != 0
        }
    }

    public func setChargingInhibited(_ inhibited: Bool) throws {
        guard capabilities.inhibitChargeControl else { throw SMCBatteryError.unsupportedCapability }

        if hasCHTE {
            if !inhibited && hasCH0I {
                try SMCKit.shared.write("CH0I", UInt8(0))
            }
            let value: UInt32 = inhibited ? 1 : 0
            try SMCKit.shared.write("CHTE", value)
        } else {
            if !inhibited && hasCH0I {
                try SMCKit.shared.write("CH0I", UInt8(0))
            }
            let value: UInt8 = inhibited ? 1 : 0
            try SMCKit.shared.write("CH0C", value)
        }
    }

    public func getForceDischarging() throws -> Bool {
        guard capabilities.forceDischargeControl else {
            throw SMCBatteryError.unsupportedCapability
        }

        if hasCHIE {
            let data = try SMCKit.shared.readData("CHIE")
            return data.first == 0x08
        } else {
            let value: UInt8 = try SMCKit.shared.read("CH0I")
            return value != 0
        }
    }

    public func setForceDischarging(_ enabled: Bool) throws {
        guard capabilities.forceDischargeControl else {
            throw SMCBatteryError.unsupportedCapability
        }

        if enabled {
            // Clear charging inhibit before enabling force discharge
            if hasCHTE {
                try SMCKit.shared.write("CHTE", UInt32(0))
            } else if hasCH0C {
                try SMCKit.shared.write("CH0C", UInt8(0))
            }

            if hasCHIE {
                try SMCKit.shared.writeData("CHIE", Data([0x08]))
            } else {
                try SMCKit.shared.write("CH0I", UInt8(1))
            }
        } else {
            if hasCHIE {
                try SMCKit.shared.writeData("CHIE", Data([0x00]))
            } else {
                try SMCKit.shared.write("CH0I", UInt8(0))
            }
        }
    }
}

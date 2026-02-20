import SMCKit

public enum MagSafeLEDState: UInt8, Codable, Sendable {
    case reset = 0
    case off = 1
    case green = 3
    case orange = 4
    case blinkOrangeSlow = 6
    case blinkOrangeFast = 7
}

public enum SMCAdapterError: Error {
    case magSafeNotSupported
    case unknownLEDState(UInt8)
}

public struct AdapterCapabilities: Codable, Sendable {
    public let magSafeControl: Bool
}

/*
* Based on:
* https://github.com/mhaeuser/Battery-Toolkit/blob/ed3adf103abfdad53223ce6f0a764ae7163c385b/Libraries/SMCComm%2BMagSafe.swift
* https://github.com/acidanthera/VirtualSMC/blob/55b89a23f51beda82581dbab795615838a3e6e56/Docs/SMCSensorKeys.txt
*/
public struct SMCAdapter: Sendable {
    public let capabilities: AdapterCapabilities

    private let hasACLC: Bool

    public static func probe() throws -> SMCAdapter {
        let hasACLC = try SMCKit.shared.isKeyFound("ACLC")

        let capabilities = AdapterCapabilities(
            magSafeControl: hasACLC
        )

        return SMCAdapter(capabilities: capabilities, hasACLC: hasACLC)
    }

    private init(capabilities: AdapterCapabilities, hasACLC: Bool) {
        self.capabilities = capabilities
        self.hasACLC = hasACLC
    }

    public static func getVoltage() throws -> Double {
        Double(try SMCKit.shared.read("VD0R") as Float)
    }

    public static func getCurrent() throws -> Double {
        Double(try SMCKit.shared.read("ID0R") as Float)
    }

    public func getMagSafeLEDState() throws -> MagSafeLEDState {
        guard hasACLC else { throw SMCAdapterError.magSafeNotSupported }

        let raw: UInt8 = try SMCKit.shared.read("ACLC")
        guard let state = MagSafeLEDState(rawValue: raw) else {
            throw SMCAdapterError.unknownLEDState(raw)
        }
        return state
    }

    public func setMagSafeLEDState(_ state: MagSafeLEDState) throws {
        guard hasACLC else { throw SMCAdapterError.magSafeNotSupported }

        try SMCKit.shared.write("ACLC", state.rawValue)
    }
}

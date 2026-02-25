import Foundation

public struct SMCBatteryReading: Sendable {
    public let batteryVoltage: Double
    public let batteryCurrent: Double
    public let batteryPower: Double

    public init(
        batteryVoltage: Double,
        batteryCurrent: Double,
        batteryPower: Double
    ) {
        self.batteryVoltage = batteryVoltage
        self.batteryCurrent = batteryCurrent
        self.batteryPower = batteryPower
    }
}

public struct SMCAdapterReading: Sendable {
    public let adapterVoltage: Double
    public let adapterCurrent: Double
    public let adapterPower: Double

    public init(
        adapterVoltage: Double,
        adapterCurrent: Double,
        adapterPower: Double
    ) {
        self.adapterVoltage = adapterVoltage
        self.adapterCurrent = adapterCurrent
        self.adapterPower = adapterPower
    }
}

public struct DeviceCapabilities: Sendable {
    public let chargingControl: Bool
    public let adapterControl: Bool
    public let hasMagSafe: Bool
    public let magsafeLEDControl: Bool

    public init(
        chargingControl: Bool,
        adapterControl: Bool,
        hasMagSafe: Bool,
        magsafeLEDControl: Bool
    ) {
        self.chargingControl = chargingControl
        self.adapterControl = adapterControl
        self.hasMagSafe = hasMagSafe
        self.magsafeLEDControl = magsafeLEDControl
    }

    public static func from(
        battery: BatteryCapabilities,
        adapter: AdapterCapabilities
    ) -> DeviceCapabilities {
        DeviceCapabilities(
            chargingControl: battery.inhibitChargeControl,
            adapterControl: battery.forceDischargeControl,
            hasMagSafe: adapter.magSafeControl,
            magsafeLEDControl: adapter.magSafeControl
        )
    }
}

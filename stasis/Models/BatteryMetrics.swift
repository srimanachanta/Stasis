import Foundation

struct BatteryMetrics: Codable, Equatable {
    var batteryPercentage: Int = 0
    var hardwareBatteryPercentage: Int = 0
    var isCharging: Bool = false
    var timeRemaining: Int = 0

    var batteryVoltage: Double = 0
    var batteryCurrent: Double = 0
    var batteryPower: Double = 0
    var batteryTemperature: Double = 0

    var batteryHealth: Int = 0
    var cycleCount: Int = 0

    var adapterConnected: Bool = false
    var adapterVoltage: Double = 0
    var adapterCurrent: Double = 0
    var adapterPower: Double = 0

    var systemPower: Double = 0
    var powerSource: PowerSource = .battery
}

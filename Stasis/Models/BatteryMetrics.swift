import Foundation

struct OutputPortPower: Codable, Equatable, Identifiable {
    var portIndex: Int
    var powerWatts: Double

    var id: Int { portIndex }
}

struct BatteryMetrics: Codable, Equatable {
    var batteryPercentage: Int = 0
    var hardwareBatteryPercentage: Int = 0
    var isCharging: Bool = false
    var timeRemaining: Int = 0

    var batteryVoltage: Double = 0
    var batteryCurrent: Double = 0
    var batteryPower: Double = 0
    var outputPower: Double = 0
    var outputPorts: [OutputPortPower] = []
    var batteryTemperature: Double = 0

    var batteryHealth: Int = 0
    var cycleCount: Int = 0

    var externalConnected: Bool = false
}

struct AdapterMetrics: Equatable {
    var adapterConnected: Bool = false
    var adapterCapacityWatts: Int = 0
    var adapterVoltage: Double = 0
    var adapterCurrent: Double = 0
    var adapterPower: Double = 0
}

struct BatteryControlState: Equatable {
    var batteryPercentage: Int = 0
    var hardwareBatteryPercentage: Int = 0
    var adapterConnected: Bool = false
    var batteryTemperature: Double = 0
}

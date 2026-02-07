import Defaults
import Foundation

extension MagSafeLEDState: Defaults.Serializable {}

extension Defaults.Keys {
    // General
    public static let launchAtLogin = Key<Bool>("launchAtLogin", default: true)

    // Menu Bar
    // Status Icon
    public static let showBatteryPercentageInStatusIcon = Key<Bool>(
        "showBatteryPercentageInStatusIcon",
        default: false
    )
    // Menu Dashboard
    public static let showTimeTillDischarge = Key<Bool>(
        "showTimeTillDischarge",
        default: true
    )
    public static let showBatteryCycleCount = Key<Bool>(
        "showBatteryCycleCount",
        default: true
    )
    public static let showBatteryHealth = Key<Bool>(
        "showBatteryHealth",
        default: true
    )
    public static let showBatteryTemperature = Key<Bool>(
        "showBatteryTemperature",
        default: false
    )
    public static let showPowerSource = Key<Bool>(
        "showPowerSource",
        default: false
    )
    public static let showUptime = Key<Bool>("showUptime", default: true)
    public static let showLastDischarge = Key<Bool>(
        "showLastDischarge",
        default: false
    )
    public static let showLastFullCharge = Key<Bool>(
        "showLastFullCharge",
        default: false
    )
    public static let showBatteryMode = Key<Bool>(
        "showBatteryMode",
        default: true
    )
    public static let showInternalPower = Key<Bool>(
        "showInternalPower",
        default: true
    )
    public static let showExternalPower = Key<Bool>(
        "showExternalPower",
        default: true
    )

    public static let showPowerDistribution = Key<Bool>(
        "showPowerDistribution",
        default: false
    )
    // Advanced
    public static let useHardwarePercentage = Key<Bool>(
        "useHardwarePercentage",
        default: false
    )
}

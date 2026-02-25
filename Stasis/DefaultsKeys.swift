import Defaults
import Foundation
import smc_power

extension MagSafeLEDState: Defaults.Serializable {}

extension Defaults.Keys {
    // General
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)

    // Status Icon
    static let showBatteryPercentageInStatusIcon = Key<Bool>(
        "showBatteryPercentageInStatusIcon", default: false)
    static let showBatteryStateInStatusIcon = Key<Bool>(
        "showBatteryStateInStatusIcon", default: true)

    // Notifications
    static let disableNotifications = Key<Bool>("disableNotifications", default: false)
    static let showChargingStatusChangedNotification = Key<Bool>(
        "showChargingStatusChangedNotification", default: true)

    // Menu Dashboard
    static let showTimeTillDischarge = Key<Bool>("showTimeTillDischarge", default: true)
    static let showBatteryCycleCount = Key<Bool>("showBatteryCycleCount", default: true)
    static let showBatteryHealth = Key<Bool>("showBatteryHealth", default: true)
    static let showBatteryTemperature = Key<Bool>("showBatteryTemperature", default: false)
    static let showPowerSource = Key<Bool>("showPowerSource", default: false)
    static let showUptime = Key<Bool>("showUptime", default: true)
    static let showBatteryMode = Key<Bool>("showBatteryMode", default: true)
    static let showInternalPower = Key<Bool>("showInternalPower", default: true)
    static let showExternalPower = Key<Bool>("showExternalPower", default: true)
    static let showPowerDistribution = Key<Bool>("showPowerDistribution", default: false)

    // Charging
    static let manageCharging = Key<Bool>("manageCharging", default: false)
    static let chargeLimit = Key<Int>("chargeLimit", default: 80)
    static let sailingMode = Key<Bool>("sailingMode", default: true)
    static let sailingModeLimit = Key<Int>("sailingModeLimit", default: 5)
    static let automaticDischarge = Key<Bool>("automaticDischarge", default: true)
    static let disableSleepUntilChargeLimit = Key<Bool>("disableSleepUntilChargeLimit", default: false)

    // Charging - Heat Protection
    static let enableHeatProtectionMode = Key<Bool>(
        "enableHeatProtectionMode", default: true)
    static let heatProtectionLimit = Key<Int>("heatProtectionLimit", default: 40)

    // Charging - MagSafe LED Control
    static let manageMagSafeLED = Key<Bool>("manageMagSafeLED", default: true)
    static let heatProtectionMagSafeLEDState = Key<MagSafeLEDState>(
        "heatProtectionMagSafeLEDState", default: MagSafeLEDState.blinkOrangeSlow)
    // Advanced
    static let useHardwarePercentage = Key<Bool>("useHardwarePercentage", default: false)
}

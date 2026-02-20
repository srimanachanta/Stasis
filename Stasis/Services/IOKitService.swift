import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import os.log

@MainActor
class IOKitService {
    private var runLoopSource: CFRunLoopSource?
    private var batteryService: io_service_t = 0

    private var continuation: AsyncStream<BatteryMetrics>.Continuation?

    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "IOKitService"
    )

    func metricsStream() -> AsyncStream<BatteryMetrics> {
        AsyncStream { continuation in
            self.continuation = continuation

            continuation.onTermination = { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.stop()
                }
            }

            self.startNotifications()
        }
    }

    private func startNotifications() {
        logger.info("Starting IOKit monitoring")

        batteryService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        if batteryService == 0 {
            logger.error("Failed to get AppleSmartBattery service")
        }

        let context = UnsafeMutableRawPointer(
            Unmanaged.passUnretained(self).toOpaque()
        )
        runLoopSource = IOPSNotificationCreateRunLoopSource(
            { context in
                guard let context = context else { return }
                let monitor = Unmanaged<IOKitService>.fromOpaque(context)
                    .takeUnretainedValue()
                MainActor.assumeIsolated {
                    monitor.emitMetrics()
                }
            },
            context
        ).takeRetainedValue()

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            logger.info("IOKit notification source added to main run loop")
        } else {
            logger.error("Failed to create IOKit notification source")
        }

        emitMetrics()
    }

    private func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if batteryService != 0 {
            IOObjectRelease(batteryService)
            batteryService = 0
        }
        continuation = nil
    }

    private func emitMetrics() {
        logger.debug("IOKit notification triggered")

        let powerInfo = getPowerSourceInfo() as? [String: Any]
        var metrics = BatteryMetrics()

        let percentages = getBatteryPercentages(powerInfo: powerInfo)
        metrics.batteryPercentage = percentages.displayed
        metrics.hardwareBatteryPercentage = percentages.hardware

        metrics.isCharging = powerInfo?[kIOPSIsChargingKey] as? Bool ?? false
        if metrics.isCharging {
            metrics.timeRemaining = getTimeToFull(powerInfo: powerInfo) ?? -1
        } else {
            metrics.timeRemaining = getTimeRemaining(powerInfo: powerInfo) ?? -1
        }

        let capacities = getBatteryCapacities()
        metrics.batteryHealth =
            capacities.design > 0
            ? (capacities.max * 100) / capacities.design
            : 100

        metrics.adapterConnected = isAdapterConnected()

        if let temp = getBatteryTemperature(powerInfo: powerInfo) {
            metrics.batteryTemperature = temp
        }

        metrics.cycleCount =
            getPropertyValue(batteryService, key: "CycleCount") ?? 0

        if metrics.adapterConnected {
            metrics.powerSource = .acAdapter
        } else {
            metrics.powerSource = .battery
        }

        logger.debug(
            "IOKit metrics: battery=\(metrics.batteryPercentage)%, hardwareBattery=\(metrics.hardwareBatteryPercentage)%, health=\(metrics.batteryHealth)%, charging=\(metrics.isCharging), temp=\(metrics.batteryTemperature)°C, cycles=\(metrics.cycleCount), timeRemaining=\(metrics.timeRemaining), adapterConnected=\(metrics.adapterConnected)"
        )

        continuation?.yield(metrics)
    }

    private nonisolated func getPowerSourceInfo() -> CFDictionary? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources =
            IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        guard let source = sources.first else { return nil }
        return IOPSGetPowerSourceDescription(snapshot, source)
            .takeUnretainedValue()
    }

    private nonisolated func getPropertyValue<T>(_ service: io_service_t, key: String) -> T? {
        guard
            let prop = IORegistryEntryCreateCFProperty(
                service,
                key as CFString,
                kCFAllocatorDefault,
                0
            )
        else {
            return nil
        }
        return prop.takeRetainedValue() as? T
    }

    private func getBatteryPercentages(powerInfo: [String: Any]?) -> (
        displayed: Int, hardware: Int
    ) {
        let displayedPercent = powerInfo?[kIOPSCurrentCapacityKey] as? Int ?? 0

        let rawCurrentCapacity: Int =
            getPropertyValue(batteryService, key: "AppleRawCurrentCapacity")
            ?? 0
        let rawMaxCapacity: Int =
            getPropertyValue(batteryService, key: "AppleRawMaxCapacity") ?? 0

        let hardwarePercent: Int
        if rawMaxCapacity > 0 {
            hardwarePercent = (rawCurrentCapacity * 100) / rawMaxCapacity
        } else {
            let currentCapacity: Int =
                getPropertyValue(batteryService, key: "CurrentCapacity")
                ?? displayedPercent
            hardwarePercent = currentCapacity
        }

        return (displayedPercent, hardwarePercent)
    }

    private func getTimeRemaining(powerInfo: [String: Any]?) -> Int? {
            guard let timeToEmpty = powerInfo?[kIOPSTimeToEmptyKey] as? Int,
                  timeToEmpty > 0,
                  timeToEmpty != Int(kIOPSTimeRemainingUnknown) else {
                return nil
            }

            return timeToEmpty
        }

    private func getTimeToFull(powerInfo: [String: Any]?) -> Int? {
        guard let timeToFull = powerInfo?[kIOPSTimeToFullChargeKey] as? Int,
              timeToFull > 0,
              timeToFull != Int(kIOPSTimeRemainingUnknown) else {
            return nil
        }

        return timeToFull
    }

    private func isAdapterConnected() -> Bool {
        guard let adapterDetails: [String: Any] = getPropertyValue(batteryService, key: "AdapterDetails"),
                  let watts = adapterDetails["Watts"] as? Int else {
                return false
            }
            
            return watts > 0
    }

    private func getBatteryTemperature(powerInfo: [String: Any]?) -> Double? {
        if let powerInfo,
            let temp = powerInfo[kIOPSTemperatureKey] as? Int,
            temp > 0
        {
            return decikelvinToCelsius(temp)
        }

        guard
            let temp: Int = getPropertyValue(
                batteryService,
                key: "Temperature"
            ),
            temp > 0, temp <= 5000
        else {
            return nil
        }

        return decikelvinToCelsius(temp)
    }

    private nonisolated func decikelvinToCelsius(_ decikelvin: Int) -> Double? {
        let celsius = (Double(decikelvin) / 10.0) - 273.15
        return (0...80).contains(celsius) ? celsius : nil
    }

    private func getBatteryCapacities() -> (current: Int, max: Int, design: Int) {
        let currentCapacity: Int =
            getPropertyValue(batteryService, key: "AppleRawCurrentCapacity")
            ?? 0
        let maxCapacity: Int =
            getPropertyValue(batteryService, key: "AppleRawMaxCapacity") ?? 0
        let designCapacity: Int =
            getPropertyValue(batteryService, key: "DesignCapacity") ?? 0

        return (currentCapacity, maxCapacity, designCapacity)
    }
}

import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import os.log

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
                DispatchQueue.main.async {
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
                monitor.emitMetrics()
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
        logger.info("IOKit notification triggered")

        let powerInfo = getPowerSourceInfo() as? [String: Any]
        var metrics = BatteryMetrics()

        let percentages = getBatteryPercentages(powerInfo: powerInfo)
        metrics.batteryPercentage = percentages.displayed
        metrics.hardwareBatteryPercentage = percentages.hardware

        metrics.isCharging = powerInfo?[kIOPSIsChargingKey] as? Bool ?? false
        metrics.isFullyCharged =
            getPropertyValue(batteryService, key: "FullyCharged") ?? false

        if metrics.isCharging {
            metrics.timeRemaining = getTimeToFull(powerInfo: powerInfo) ?? -1
        } else {
            metrics.timeRemaining = getTimeRemaining(powerInfo: powerInfo) ?? -1
        }

        let batteryInfo = getBatteryVoltageAndCurrent(powerInfo: powerInfo)
        metrics.batteryVoltage = batteryInfo.voltage
        metrics.batteryCurrent = batteryInfo.current

        let capacities = getBatteryCapacities()
        metrics.currentCapacity = capacities.current
        metrics.maxCapacity = capacities.max
        metrics.designCapacity = capacities.design
        metrics.batteryHealth =
            capacities.design > 0
            ? (capacities.max * 100) / capacities.design
            : 100

        if let adapterInfo = getACAdapterInfo(powerInfo: powerInfo) {
            metrics.adapterCurrent = adapterInfo.current
            metrics.adapterVoltage = adapterInfo.voltage
            metrics.adapterWatts = adapterInfo.watts
            metrics.adapterConnected = true
        } else {
            metrics.adapterConnected = false
        }

        if let temp = getBatteryTemperature(powerInfo: powerInfo) {
            metrics.batteryTemperature = temp
        }

        metrics.cycleCount =
            getPropertyValue(batteryService, key: "CycleCount") ?? 0

        if metrics.adapterConnected {
            metrics.powerSource =
                metrics.batteryCurrent < 0 ? .Both : .ACAdapter
        } else {
            metrics.powerSource = .Battery
        }

        logger.info(
            "IOKit metrics: battery=\(metrics.batteryPercentage)%, health=\(metrics.batteryHealth)%, charging=\(metrics.isCharging), voltage=\(metrics.batteryVoltage)V, current=\(metrics.batteryCurrent)A, temp=\(metrics.batteryTemperature)°C, cycles=\(metrics.cycleCount), timeRemaining=\(metrics.timeRemaining)"
        )

        continuation?.yield(metrics)
    }

    private func getPowerSourceInfo() -> CFDictionary? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources =
            IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        guard let source = sources.first else { return nil }
        return IOPSGetPowerSourceDescription(snapshot, source)
            .takeUnretainedValue()
    }

    private func getPropertyValue<T>(_ service: io_service_t, key: String) -> T? {
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
        let timeToEmpty = powerInfo?[kIOPSTimeToEmptyKey] as? Int ?? -1

        if timeToEmpty <= 0 || timeToEmpty == Int(kIOPSTimeRemainingUnknown) {
            return nil
        }

        return timeToEmpty
    }

    private func getTimeToFull(powerInfo: [String: Any]?) -> Int? {
        let timeToFull = powerInfo?[kIOPSTimeToFullChargeKey] as? Int ?? -1

        if timeToFull <= 0 || timeToFull == Int(kIOPSTimeRemainingUnknown) {
            return nil
        }

        return timeToFull
    }

    private func getACAdapterInfo(powerInfo: [String: Any]?) -> (
        current: Double, voltage: Double, watts: Int
    )? {
        guard let powerInfo else { return nil }

        let voltage = powerInfo[kIOPSVoltageKey] as? Int ?? 0
        let current = powerInfo[kIOPSCurrentKey] as? Int ?? 0

        if let adapterDetails: [String: Any] = getPropertyValue(
            batteryService,
            key: "AdapterDetails"
        ) {
            let adapterVoltage =
                adapterDetails["AdapterVoltage"] as? Int ?? voltage
            let adapterCurrent = adapterDetails["Current"] as? Int ?? current
            let watts = adapterDetails["Watts"] as? Int ?? 0

            guard adapterVoltage != 0 || watts != 0 else { return nil }

            return (
                Double(adapterCurrent) / 1000.0,
                Double(adapterVoltage) / 1000.0,
                watts
            )
        }

        guard voltage != 0 else { return nil }

        return (
            Double(current) / 1000.0,
            Double(voltage) / 1000.0,
            (voltage * current) / 1000
        )
    }

    private func getBatteryVoltageAndCurrent(powerInfo: [String: Any]?) -> (
        voltage: Double, current: Double
    ) {
        if let powerInfo {
            let voltage = powerInfo[kIOPSVoltageKey] as? Int ?? 0
            let current = powerInfo[kIOPSCurrentKey] as? Int ?? 0

            if voltage > 0 {
                return (Double(voltage) / 1000.0, Double(current) / 1000.0)
            }
        }

        let voltage: Int = getPropertyValue(batteryService, key: "Voltage") ?? 0
        let current: Int =
            getPropertyValue(batteryService, key: "InstantAmperage") ?? 0
        return (Double(voltage) / 1000.0, Double(current) / 1000.0)
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

    private func decikelvinToCelsius(_ decikelvin: Int) -> Double? {
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

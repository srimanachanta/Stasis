import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import os.log

@MainActor
class IOKitService {
    private var notificationPort: IONotificationPortRef?
    private var interestNotification: io_object_t = 0
    private var batteryService: io_service_t = 0

    private var continuation: AsyncStream<(BatteryMetrics, AdapterMetrics)>.Continuation?
    private var refreshTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "IOKitService"
    )
    private var outputTelemetryAvailabilityLogged = false

    func metricsStream() -> AsyncStream<(BatteryMetrics, AdapterMetrics)> {
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

        guard batteryService != 0 else { return }

        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notificationPort else {
            logger.error("Failed to create IONotificationPort")
            return
        }

        let notificationSource = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), notificationSource, .commonModes)

        let context = UnsafeMutableRawPointer(
            Unmanaged.passUnretained(self).toOpaque()
        )

        let callback: IOServiceInterestCallback = { refcon, _, _, _ in
            guard let refcon else { return }
            let monitor = Unmanaged<IOKitService>.fromOpaque(refcon)
                .takeUnretainedValue()
            MainActor.assumeIsolated {
                monitor.emitMetrics()
            }
        }

        let result = IOServiceAddInterestNotification(
            notificationPort,
            batteryService,
            kIOGeneralInterest,
            callback,
            context,
            &interestNotification
        )

        if result == KERN_SUCCESS {
            logger.info("IORegistry interest notification registered for AppleSmartBattery")
        } else {
            logger.error("Failed to register interest notification: \(result)")
        }

        emitMetrics()
        startRefreshLoop()
    }

    private func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        if interestNotification != 0 {
            IOObjectRelease(interestNotification)
            interestNotification = 0
        }
        if let notificationPort {
            let source = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
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
        var batteryMetrics = BatteryMetrics()
        var adapterMetrics = AdapterMetrics()

        let percentages = getBatteryPercentages(powerInfo: powerInfo)
        batteryMetrics.batteryPercentage = percentages.displayed
        batteryMetrics.hardwareBatteryPercentage = percentages.hardware

        batteryMetrics.isCharging = powerInfo?[kIOPSIsChargingKey] as? Bool ?? false
        if batteryMetrics.isCharging {
            batteryMetrics.timeRemaining = getTimeToFull(powerInfo: powerInfo) ?? -1
        } else {
            batteryMetrics.timeRemaining = getTimeRemaining(powerInfo: powerInfo) ?? -1
        }

        let capacities = getBatteryCapacities()
        batteryMetrics.batteryHealth =
            capacities.design > 0
            ? (capacities.max * 100) / capacities.design
            : 100

        batteryMetrics.externalConnected =
            getPropertyValue(batteryService, key: "ExternalConnected") ?? false
        batteryMetrics.outputPorts = getOutputPortPowers()
        batteryMetrics.outputPower = batteryMetrics.outputPorts.reduce(0) { $0 + $1.powerWatts }

        let adapterRatedWatts = getAdapterRatedWatts()
        adapterMetrics.adapterCapacityWatts = adapterRatedWatts ?? 0
        adapterMetrics.adapterConnected = (adapterRatedWatts ?? 0) > 0

        if let temp = getBatteryTemperature(powerInfo: powerInfo) {
            batteryMetrics.batteryTemperature = temp
        }

        batteryMetrics.cycleCount =
            getPropertyValue(batteryService, key: "CycleCount") ?? 0

        logger.debug(
            "IOKit metrics: battery=\(batteryMetrics.batteryPercentage)%, hardwareBattery=\(batteryMetrics.hardwareBatteryPercentage)%, health=\(batteryMetrics.batteryHealth)%, charging=\(batteryMetrics.isCharging), temp=\(batteryMetrics.batteryTemperature)°C, cycles=\(batteryMetrics.cycleCount), timeRemaining=\(batteryMetrics.timeRemaining), externalConnected=\(batteryMetrics.externalConnected), adapterConnected=\(adapterMetrics.adapterConnected)"
        )

        continuation?.yield((batteryMetrics, adapterMetrics))
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

    private func getAdapterRatedWatts() -> Int? {
        guard
            let adapterDetails: [String: Any] = getPropertyValue(batteryService, key: "AdapterDetails"),
            let watts = adapterDetails["Watts"] as? Int,
            watts > 0
        else {
            return nil
        }
        return watts
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

    private func getOutputPortPowers() -> [OutputPortPower] {
        guard supportsOutputTelemetry() else {
            return []
        }

        guard
            let powerOutDetails: [[String: Any]] = getPropertyValue(
                batteryService,
                key: "PowerOutDetails"
            )
        else {
            return []
        }

        return powerOutDetails.compactMap { detail in
            guard let portIndex = (detail["PortIndex"] as? NSNumber)?.intValue else {
                return nil
            }

            let milliwatts: Double
            if let wattsMilliwatts = detail["Watts"] as? NSNumber {
                milliwatts = wattsMilliwatts.doubleValue
            } else if let currentMilliamps = detail["Current"] as? NSNumber,
                let voltageMillivolts = detail["AdapterVoltage"] as? NSNumber
            {
                milliwatts = currentMilliamps.doubleValue * voltageMillivolts.doubleValue / 1000.0
            } else {
                milliwatts = 0
            }

            let watts = max(0, milliwatts / 1000.0)
            guard watts > 0.1 else { return nil }
            return OutputPortPower(portIndex: portIndex, powerWatts: watts)
        }
        .sorted { $0.portIndex < $1.portIndex }
    }

    private func supportsOutputTelemetry() -> Bool {
        let osMajor = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        guard osMajor >= 26 else {
            if !outputTelemetryAvailabilityLogged {
                logger.info("Outgoing output telemetry disabled: requires macOS 26+")
                outputTelemetryAvailabilityLogged = true
            }
            return false
        }

        let hasTelemetryData: [String: Any]? = getPropertyValue(
            batteryService,
            key: "PowerTelemetryData"
        )
        let hasPowerOutDetails: [[String: Any]]? = getPropertyValue(
            batteryService,
            key: "PowerOutDetails"
        )
        let supported = (hasTelemetryData != nil) && (hasPowerOutDetails != nil)

        if !outputTelemetryAvailabilityLogged {
            if supported {
                logger.info("Outgoing output telemetry enabled")
            } else {
                logger.info(
                    "Outgoing output telemetry disabled: PowerTelemetryData/PowerOutDetails unavailable"
                )
            }
            outputTelemetryAvailabilityLogged = true
        }

        return supported
    }

    private func startRefreshLoop() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.emitMetrics()
                }
            }
        }
    }
}

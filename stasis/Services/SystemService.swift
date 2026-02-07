import Foundation
import Observation
import os.log

@MainActor
@Observable
class SystemService {
    var bootTimestamp: Date?

    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "SystemService"
    )

    init() {
        logger.info("SystemService initialized")
        bootTimestamp = getBootTime()
    }

    private func getBootTime() -> Date? {
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var bootTime = timeval()
        var bootTimeSize = MemoryLayout<timeval>.size

        let result = sysctl(
            &mib,
            u_int(mib.count),
            &bootTime,
            &bootTimeSize,
            nil,
            0
        )

        if result != 0 {
            logger.error("Failed to get boot time from sysctl")
            return nil
        }

        let timeInterval =
            TimeInterval(bootTime.tv_sec) + TimeInterval(bootTime.tv_usec)
            / 1_000_000.0
        return Date(timeIntervalSince1970: timeInterval)
    }
}

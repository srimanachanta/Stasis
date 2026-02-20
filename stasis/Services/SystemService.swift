import Foundation

enum SystemService {
    static func bootTimestamp() -> Date? {
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

        guard result == 0 else { return nil }

        let timeInterval =
            TimeInterval(bootTime.tv_sec) + TimeInterval(bootTime.tv_usec)
            / 1_000_000.0
        return Date(timeIntervalSince1970: timeInterval)
    }
}

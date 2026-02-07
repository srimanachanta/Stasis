import Foundation
import os.log

enum Constants {
    static let helperSubsystem = "com.srimanachanta.stasis.helper"
}

final class Helper: NSObject, HelperProtocol, Sendable {
    private let smcService = SMCService()
    private let logger = Logger(
        subsystem: Constants.helperSubsystem,
        category: "Helper"
    )

    override init() {
        super.init()
        logger.info("Helper XPC service initialized")
    }

    func readSMCPower(reply: @escaping @Sendable (Double, Double, Double) -> Void) {
        Task {
            do {
                let reading = try await smcService.readPower()
                reply(
                    reading.batteryPower,
                    reading.externalPower,
                    reading.systemPower
                )
            } catch {
                logger.error("SMC read failed: \(error.localizedDescription)")
                reply(0, 0, 0)
            }
        }
    }
}

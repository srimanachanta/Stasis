import Foundation
import os.log

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let helper = ChargingHelper()
    private var activeConnectionCount = 0
    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis.charging-helper",
        category: "ServiceDelegate"
    )

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(
            with: (any ChargingHelperProtocol).self
        )
        newConnection.exportedObject = helper

        activeConnectionCount += 1
        logger.info("XPC connection accepted (active: \(self.activeConnectionCount))")

        newConnection.invalidationHandler = { [weak self] in
            guard let self else { return }
            self.activeConnectionCount -= 1
            self.logger.info("XPC connection invalidated (active: \(self.activeConnectionCount))")
            if self.activeConnectionCount == 0 {
                self.logger.info("No active connections, resetting SMC keys to defaults")
                self.helper.resetToDefaults()
            }
        }

        newConnection.resume()
        return true
    }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener(
    machServiceName: "com.srimanachanta.stasis.charging-helper"
)
listener.delegate = delegate
listener.resume()

dispatchMain()

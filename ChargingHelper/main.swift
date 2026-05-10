import Foundation
import os.log
import smc_power

let logger = Logger(
    subsystem: "com.srimanachanta.stasis.charging-helper",
    category: "ServiceDelegate"
)

let battery: SMCBattery
let adapter: SMCAdapter
do {
    battery = try SMCBattery.probe()
    adapter = try SMCAdapter.probe()
} catch {
    logger.fault("Failed to probe SMC capabilities: \(error.localizedDescription)")
    exit(1)
}

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    let helper: ChargingHelper

    init(helper: ChargingHelper) {
        self.helper = helper
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(
            with: (any ChargingHelperProtocol).self
        )
        newConnection.exportedObject = helper

        logger.info("XPC connection accepted")

        newConnection.invalidationHandler = { [weak self] in
            guard let self else { return }
            logger.info("XPC connection invalidated, resetting SMC keys to defaults")
            self.helper.resetToDefaults()
            exit(0)
        }

        newConnection.resume()
        return true
    }
}

let helper = ChargingHelper(battery: battery, adapter: adapter)
let delegate = ServiceDelegate(helper: helper)
let listener = NSXPCListener(
    machServiceName: "com.srimanachanta.stasis.charging-helper"
)
listener.delegate = delegate
listener.resume()

dispatchMain()

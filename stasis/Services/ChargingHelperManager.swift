import Foundation
import ServiceManagement
import os.log

@MainActor
class ChargingHelperManager {
    static let shared = ChargingHelperManager()

    private static let machServiceName = "com.srimanachanta.stasis.charging-helper"
    private static let plistName = "com.srimanachanta.stasis.charging-helper.plist"

    private let service: SMAppService
    private var connection: NSXPCConnection?
    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "ChargingHelperManager"
    )

    var isInstalled: Bool {
        service.status == .enabled
    }

    private init() {
        service = SMAppService.daemon(plistName: Self.plistName)
    }

    func install() throws {
        logger.info("Registering charging helper daemon")
        try service.register()
        logger.info("Charging helper daemon registered successfully")
    }

    func uninstall() throws {
        logger.info("Unregistering charging helper daemon")
        disconnect()
        try service.unregister()
        logger.info("Charging helper daemon unregistered successfully")
    }

    func getHelper(errorHandler: @escaping @Sendable (Error) -> Void) -> ChargingHelperProtocol? {
        if connection == nil {
            connect()
        }
        guard let connection else { return nil }
        return connection.remoteObjectProxyWithErrorHandler(errorHandler)
            as? ChargingHelperProtocol
    }

    private func connect() {
        logger.info("Setting up XPC connection to charging helper daemon")
        let newConnection = NSXPCConnection(
            machServiceName: Self.machServiceName
        )
        newConnection.remoteObjectInterface = NSXPCInterface(
            with: ChargingHelperProtocol.self
        )

        newConnection.invalidationHandler = { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.logger.warning("Charging helper XPC connection invalidated")
                self.connection = nil
            }
        }

        newConnection.interruptionHandler = { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.logger.warning("Charging helper XPC connection interrupted")
                self.connection = nil
            }
        }

        newConnection.resume()
        connection = newConnection
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
    }
}

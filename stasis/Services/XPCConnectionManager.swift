import Foundation
import os.log

class XPCConnectionManager {
    private var connection: NSXPCConnection?
    private let serviceName: String
    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "XPCConnectionManager"
    )

    private var reconnectAttempts = 0
    private static let maxReconnectAttempts = 5
    private static let baseReconnectDelay: TimeInterval = 1.0

    init(serviceName: String) {
        self.serviceName = serviceName
    }

    func getHelper(errorHandler: @escaping (Error) -> Void) -> HelperProtocol? {
        guard let connection else { return nil }
        return connection.remoteObjectProxyWithErrorHandler(errorHandler)
            as? HelperProtocol
    }

    func connect() {
        logger.info("Setting up XPC connection to \(self.serviceName)")
        connection = NSXPCConnection(serviceName: serviceName)
        connection?.remoteObjectInterface = NSXPCInterface(
            with: HelperProtocol.self
        )

        connection?.invalidationHandler = { [weak self] in
            guard let self else { return }
            self.logger.error("XPC connection invalidated")
            self.connection = nil
        }

        connection?.interruptionHandler = { [weak self] in
            guard let self else { return }
            self.logger.warning("XPC connection interrupted")
            self.connection = nil
            self.scheduleReconnect()
        }

        connection?.resume()
        reconnectAttempts = 0
        logger.info("XPC connection resumed")
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < Self.maxReconnectAttempts else {
            logger.error(
                "Exceeded max reconnect attempts (\(Self.maxReconnectAttempts)), giving up"
            )
            return
        }

        reconnectAttempts += 1
        let delay =
            Self.baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        logger.info(
            "Scheduling reconnect attempt \(self.reconnectAttempts) in \(delay)s"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }

    func disconnect() {
        logger.info("Disconnecting XPC connection")
        connection?.invalidate()
        connection = nil
    }

}

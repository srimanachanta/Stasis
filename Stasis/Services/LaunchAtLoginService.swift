import Foundation
import ServiceManagement
import os.log

class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private let logger = Logger(
        subsystem: "com.srimanachanta.stasis",
        category: "LaunchAtLoginService"
    )

    private init() {}

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error(
                "Failed to \(enabled ? "enable" : "disable") launch at login: \(error)"
            )
        }
    }

    var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }
}

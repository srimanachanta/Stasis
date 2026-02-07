import Foundation
import ServiceManagement

class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private init() {}

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print(
                "Failed to \(enabled ? "enable" : "disable") launch at login: \(error)"
            )
        }
    }

    var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }
}

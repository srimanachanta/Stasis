import AppKit
import Combine
import Defaults

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusBarManager: StatusBarManager!
    private var batteryService: BatteryService!
    private var systemService: SystemService!
    private var viewModel: MenuViewModel!
    private var menuBuilder: MenuBuilder!
    private var settingsWindowController: SettingsWindowController!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupServices()
        setupMenu()
    }

    private func setupServices() {
        batteryService = BatteryService()
        systemService = SystemService()
        viewModel = MenuViewModel(
            batteryService: batteryService,
            systemService: systemService
        )
        settingsWindowController = SettingsWindowController()
        menuBuilder = MenuBuilder(
            viewModel: viewModel,
            settingsWindowController: settingsWindowController
        )
        statusBarManager = StatusBarManager(viewModel: viewModel)
    }

    private func setupMenu() {
        let menu = menuBuilder.buildMenu()
        menu.delegate = self
        statusBarManager.setMenu(menu)
        observeMenuSettingsChanges()
    }

    private func observeMenuSettingsChanges() {
        let dashboardSettings: [Defaults.Key<Bool>] = [
            .showPowerSource,
            .showTimeTillDischarge,
            .showBatteryCycleCount,
            .showBatteryHealth,
            .showBatteryTemperature,
            .showUptime,
            .showBatteryMode,
            .showInternalPower,
            .showExternalPower,
            .showPowerDistribution,
        ]

        for setting in dashboardSettings {
            Defaults.publisher(setting)
                .sink { [weak self] _ in
                    self?.rebuildMenu()
                }
                .store(in: &cancellables)
        }
    }

    private func rebuildMenu() {
        let menu = menuBuilder.buildMenu()
        menu.delegate = self
        statusBarManager.setMenu(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        viewModel.menuWillOpen()
    }

    func menuDidClose(_ menu: NSMenu) {
        viewModel.menuDidClose()
    }
}

func formatTimeRemaining(minutes: Int) -> String {
    if minutes < 0 {
        return ""
    }
    let hours = minutes / 60
    let mins = minutes % 60
    return String(format: "%02d:%02d", hours, mins)
}

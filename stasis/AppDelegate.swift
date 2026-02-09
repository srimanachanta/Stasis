import AppKit
import Defaults
import Observation
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusBarManager: StatusBarManager!
    private var batteryService: BatteryService!
    private var viewModel: MenuViewModel!
    private var menuBuilder: MenuBuilder!
    private var chargeManager: ChargeManager!
    private var settingsWindowController: SettingsWindowController!
    private var menu: NSMenu!
    private var settingsObservations: [Defaults.Observation] = []
    private var adapterObservation: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupServices()
        setupMenu()
        requestNotificationPermissions()
    }

    private func setupServices() {
        batteryService = BatteryService()
        chargeManager = ChargeManager(batteryService: batteryService)
        viewModel = MenuViewModel(
            batteryService: batteryService,
            chargeManager: chargeManager
        )
        settingsWindowController = SettingsWindowController()
        menuBuilder = MenuBuilder(
            viewModel: viewModel,
            settingsWindowController: settingsWindowController
        )
        statusBarManager = StatusBarManager(viewModel: viewModel)
    }

    private func setupMenu() {
        menu = menuBuilder.buildMenu()
        menu.delegate = self
        statusBarManager.setMenu(menu)
        observeMenuSettingsChanges()
    }

    private func observeMenuSettingsChanges() {
        let handler: @Sendable () -> Void = { [weak self] in
            Task { @MainActor [weak self] in
                self?.rebuildMenu()
            }
        }

        settingsObservations = [
            Defaults.observe(.showPowerSource) { _ in handler() },
            Defaults.observe(.showTimeTillDischarge) { _ in handler() },
            Defaults.observe(.showBatteryCycleCount) { _ in handler() },
            Defaults.observe(.showBatteryHealth) { _ in handler() },
            Defaults.observe(.showBatteryTemperature) { _ in handler() },
            Defaults.observe(.showUptime) { _ in handler() },
            Defaults.observe(.showBatteryMode) { _ in handler() },
            Defaults.observe(.showInternalPower) { _ in handler() },
            Defaults.observe(.showExternalPower) { _ in handler() },
            Defaults.observe(.showPowerDistribution) { _ in handler() },
            Defaults.observe(.manageCharging) { _ in handler() },
        ]

        adapterObservation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.rebuildMenu()
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.viewModel.adapterConnected
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }

    private func rebuildMenu() {
        menuBuilder.populateMenu(menu)
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    func menuWillOpen(_ menu: NSMenu) {
        viewModel.menuWillOpen()
    }

    func menuDidClose(_ menu: NSMenu) {
        viewModel.menuDidClose()
    }
}

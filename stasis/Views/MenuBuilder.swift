import AppKit
import Defaults
import SwiftUI

@MainActor
class MenuBuilder {
    private let viewModel: MenuViewModel
    private let settingsWindowController: SettingsWindowController

    init(
        viewModel: MenuViewModel,
        settingsWindowController: SettingsWindowController
    ) {
        self.viewModel = viewModel
        self.settingsWindowController = settingsWindowController
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Stasis")

        let mainInfoItem = createMenuItem(
            view: BatteryMainInfoView(viewModel: viewModel)
        )
        menu.addItem(mainInfoItem)

        let sections: [[NSMenuItem]] = [
            buildInfoSection(),
            buildPowerMetricsSection(),
            buildVisualizationSection(),
            buildHardwareSection(),
        ]

        for section in sections where !section.isEmpty {
            menu.addItem(NSMenuItem.separator())
            for item in section {
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(handleSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func buildInfoSection() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        if Defaults[.showPowerSource] {
            items.append(
                createInfoItem(
                    label: "Power Source",
                    keyPath: \.powerSourceText
                )
            )
        }
        if Defaults[.showTimeTillDischarge] {
            items.append(
                createInfoItem(
                    label: "Time Remaining",
                    keyPath: \.timeRemainingText
                )
            )
        }
        if Defaults[.showUptime] {
            items.append(createInfoItem(label: "Uptime", keyPath: \.uptimeText))
        }
        if Defaults[.showBatteryMode] {
            items.append(
                createInfoItem(
                    label: "Battery Mode",
                    keyPath: \.batteryModeText
                )
            )
        }
        if Defaults[.showBatteryTemperature] {
            items.append(
                createInfoItem(
                    label: "Battery Temperature",
                    keyPath: \.batteryTemperatureText
                )
            )
        }

        return items
    }

    private func buildPowerMetricsSection() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        if Defaults[.showInternalPower] {
            items.append(
                createInfoItem(
                    label: "Internal Input",
                    keyPath: \.internalInputText
                )
            )
        }
        if Defaults[.showExternalPower] {
            items.append(
                createInfoItem(
                    label: "External Input",
                    keyPath: \.externalInputText
                )
            )
        }

        return items
    }

    private func buildVisualizationSection() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        if Defaults[.showPowerDistribution] {
            items.append(
                createMenuItem(
                    view: PowerSankeyViewWrapper(viewModel: viewModel)
                )
            )
        }

        return items
    }

    private func buildHardwareSection() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        if Defaults[.showBatteryCycleCount] {
            items.append(
                createInfoItem(label: "Cycle Count", keyPath: \.cycleCountText)
            )
        }
        if Defaults[.showBatteryHealth] {
            items.append(
                createInfoItem(
                    label: "Battery Health",
                    keyPath: \.batteryHealthText
                )
            )
        }

        return items
    }

    private func createInfoItem(
        label: String,
        keyPath: KeyPath<MenuViewModel, String>
    ) -> NSMenuItem {
        createMenuItem(
            view: BatteryAdditionalInfoObserverView(
                label: label,
                viewModel: viewModel,
                keyPath: keyPath
            )
        )
    }

    private static let menuWidth: CGFloat = 300

    private func createMenuItem<V: View>(view: V) -> NSMenuItem {
        let hostingView = NSHostingView(rootView: view)
        let height = hostingView.fittingSize.height
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: Self.menuWidth,
            height: height
        )

        let menuItem = NSMenuItem()
        menuItem.view = hostingView

        return menuItem
    }

    @objc private func handleSettings() {
        settingsWindowController.showSettings()
    }

    @objc private func handleQuit() {
        viewModel.quit()
    }
}

struct BatteryMainInfoView: View {
    let viewModel: MenuViewModel

    var body: some View {
        BatteryMainInfo(
            label: "Battery",
            value: viewModel.batteryPercentageText
        )
    }
}

struct BatteryAdditionalInfoObserverView: View {
    let label: String
    let viewModel: MenuViewModel
    let keyPath: KeyPath<MenuViewModel, String>

    var body: some View {
        BatteryAdditionalInfo(label: label, value: viewModel[keyPath: keyPath])
    }
}

struct PowerSankeyViewWrapper: View {
    let viewModel: MenuViewModel

    var body: some View {
        PowerSankeyView(
            powerSource: viewModel.powerSource,
            isCharging: viewModel.isCharging,
            batteryPower: viewModel.batteryPower,
            adapterPower: viewModel.adapterPower,
            systemPower: viewModel.systemPower
        )
    }
}

import AppKit
import Defaults
import SwiftUI

@MainActor
class StatusBarManager {
    private let statusItem: NSStatusItem
    private let viewModel: MenuViewModel

    init(viewModel: MenuViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        setupPersistentHostingView()
    }

    func setMenu(_ menu: NSMenu) {
        statusItem.menu = menu
    }

    private func setupPersistentHostingView() {
        guard let button = statusItem.button else { return }

        let rootView = StatusBarContentView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: rootView)

        button.subviews.forEach { $0.removeFromSuperview() }
        button.title = ""
        button.image = nil

        hosting.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: button.topAnchor, constant: 4),
            hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -4),
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 7),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -7),
        ])
    }
}

struct StatusBarContentView: View {
    let viewModel: MenuViewModel
    @Default(.showBatteryPercentageInStatusIcon) var showPercentage

    var body: some View {
        BatteryIndicatorView(
            batteryLevel: viewModel.displayPercentage,
            chargingMode: viewModel.chargingMode,
            showPercentage: showPercentage
        )
        .fixedSize()
    }
}

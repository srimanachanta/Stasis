import AppKit
import Defaults
import SwiftUI

@MainActor
class StatusBarManager {
    private let statusItem: NSStatusItem
    private let viewModel: MenuViewModel
    private static let statusBarHeight: CGFloat = 22
    private static let statusBarWidth: CGFloat = 30

    init(viewModel: MenuViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(
            withLength: Self.statusBarWidth
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

        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: Self.statusBarWidth,
            height: Self.statusBarHeight
        )
        button.addSubview(hosting)
        button.frame = hosting.frame
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
        .padding(.horizontal, 9)
    }
}

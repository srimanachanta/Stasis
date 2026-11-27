import AppKit
import Defaults
import Observation

@MainActor
final class StatusBarManager {
    private let statusItem: NSStatusItem
    private let viewModel: MenuViewModel
    private var displayedState: BatteryIconState?
    private var displayedTitle: String?
    private var viewModelObservation: Task<Void, Never>?
    private var settingsObservation: Task<Void, Never>?

    init(viewModel: MenuViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.imageHugsTitle = true
            // Tabular digits keep the item from shifting its neighbors as the percentage changes.
            button.font = .monospacedDigitSystemFont(
                ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        }
        render()
        startObserving()
    }

    func setMenu(_ menu: NSMenu) {
        statusItem.menu = menu
    }

    private func startObserving() {
        viewModelObservation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                // Rendering inside the tracking closure registers exactly the values that were drawn, so a
                // change landing between a render and re-arming the observer can't be missed.
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        self.render()
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }
        }

        settingsObservation = Task { [weak self] in
            for await _ in Defaults.updates(
                [
                    .batteryPercentageDisplayLocation,
                    .showBatteryStateInStatusIcon,
                    .showWattageInStatusIcon,
                ],
                initial: false
            ) {
                self?.render()
            }
        }
    }

    private var currentState: BatteryIconState {
        BatteryIconState(
            level: viewModel.displayPercentage,
            chargingMode: viewModel.chargingMode,
            isLowPowerModeEnabled: viewModel.isLowPowerModeEnabled,
            percentageDisplayLocation: Defaults[.batteryPercentageDisplayLocation],
            showsLowBatteryWarning: Defaults[.showBatteryStateInStatusIcon]
        )
    }

    private func currentTitle(for state: BatteryIconState) -> String {
        var components: [String] = []
        if Defaults[.showWattageInStatusIcon] {
            let systemWatts = max(0, viewModel.systemPower)
            if viewModel.isCharging && viewModel.adapterPower > 0 {
                let adapterWatts = max(0, viewModel.adapterPower)
                components.append(
                    "\(formatWatts(adapterWatts)) / \(formatWatts(systemWatts))"
                )
            } else {
                components.append(formatWatts(systemWatts))
            }
        }
        if state.percentageDisplayLocation == .nextToIcon {
            components.append("\(state.level)%")
        }
        return components.joined(separator: " ")
    }

    private func formatWatts(_ watts: Double) -> String {
        String(format: "%.1fW", watts)
    }

    // Assigning the button's image and title, rather than hosting a custom view inside it, is what makes
    // AppKit redraw the item immediately, including its copies on other displays, and keeps the native
    // highlight, tinting, and accessibility behavior.
    private func render() {
        let state = currentState
        let title = currentTitle(for: state)
        guard let button = statusItem.button else { return }

        if state != displayedState {
            displayedState = state
            button.image = BatteryIcon.image(for: state)
            button.setAccessibilityLabel(state.accessibilityDescription)
        }

        if title != displayedTitle {
            displayedTitle = title
            button.title = title
            button.imagePosition = title.isEmpty ? .imageOnly : .imageTrailing
        }
    }

    deinit {
        MainActor.assumeIsolated {
            viewModelObservation?.cancel()
            settingsObservation?.cancel()
        }
    }
}

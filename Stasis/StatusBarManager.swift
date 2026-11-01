import AppKit
import Defaults
import Observation

@MainActor
final class StatusBarManager {
    private let statusItem: NSStatusItem
    private let viewModel: MenuViewModel
    private var displayedState: BatteryIconState?
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
                [.batteryPercentageDisplayLocation, .showBatteryStateInStatusIcon],
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

    // Assigning the button's image and title, rather than hosting a custom view inside it, is what makes
    // AppKit redraw the item immediately, including its copies on other displays, and keeps the native
    // highlight, tinting, and accessibility behavior.
    private func render() {
        let state = currentState
        guard state != displayedState, let button = statusItem.button else { return }
        displayedState = state

        button.image = BatteryIcon.image(for: state)
        if state.percentageDisplayLocation == .nextToIcon {
            button.title = "\(state.level)%"
            button.imagePosition = .imageTrailing
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
        button.setAccessibilityLabel(state.accessibilityDescription)
    }

    deinit {
        MainActor.assumeIsolated {
            viewModelObservation?.cancel()
            settingsObservation?.cancel()
        }
    }
}

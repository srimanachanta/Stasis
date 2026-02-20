import SwiftUI
import smc_power

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case dashboard = "Dashboard"
    case charging = "Charging"
    case advanced = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .dashboard:
            return "chart.xyaxis.line"
        case .charging:
            return "battery.100.bolt"
        case .advanced:
            return "slider.horizontal.3"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    private let capabilities: DeviceCapabilities

    init(capabilities: DeviceCapabilities) {
        self.capabilities = capabilities
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label {
                    Text(tab.rawValue)
                } icon: {
                    Image(systemName: tab.icon)
                }
                .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 200)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .dashboard:
                    DashboardSettingsView()
                case .charging:
                    ChargingSettingsView(capabilities: capabilities)
                case .advanced:
                    AdvancedSettingsView()
                }
            }
            .navigationTitle(selectedTab.rawValue)
        }
        .frame(minWidth: 700, minHeight: 450)
    }
}

#Preview {
    SettingsView(
        capabilities: DeviceCapabilities(
            chargingControl: true,
            adapterControl: true,
            hasMagSafe: true,
            magsafeLEDControl: true
        )
    )
}

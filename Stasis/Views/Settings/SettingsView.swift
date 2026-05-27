import SwiftUI
import smc_power

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case dashboard = "Dashboard"
    case charging = "Charging"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }
    
    var title: LocalizedStringKey {
            switch self {
            case .general: return "General"
            case .dashboard: return "Dashboard"
            case .charging: return "Charging"
            case .advanced: return "Advanced"
            case .about: return "About"
            }
    }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .dashboard:
            return "square.grid.2x2"
        case .charging:
            return "battery.100.bolt"
        case .advanced:
            return "gearshape.2"
        case .about:
            return "info.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    private let capabilities: DeviceCapabilities
    private let updaterService: UpdaterService

    init(capabilities: DeviceCapabilities, updaterService: UpdaterService) {
        self.capabilities = capabilities
        self.updaterService = updaterService
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label {
                    Text(tab.title)
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
                case .about:
                    AboutSettingsView(updaterService: updaterService)
                }
            }
            .navigationTitle(selectedTab.title)
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
        ),
        updaterService: UpdaterService.shared
    )
}

import Defaults
import SwiftUI

struct StatusIconSettingsView: View {
    @Default(.showBatteryPercentageInStatusIcon)
    var showBatteryPercentageInStatusIcon

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Status Icon")
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SettingsSection(
                        title: "Menu Bar Icon",
                        description:
                            "Customize what information is displayed in the menu bar status icon."
                    ) {
                        SettingsToggleRow(
                            label: "Show battery percentage",
                            isOn: $showBatteryPercentageInStatusIcon,
                            tooltip:
                                "Display battery percentage next to the icon"
                        )
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 400)
    }
}

#Preview {
    StatusIconSettingsView()
}

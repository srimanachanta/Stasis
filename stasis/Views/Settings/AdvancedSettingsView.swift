import Defaults
import SwiftUI

struct AdvancedSettingsView: View {
    @Default(.useHardwarePercentage) var useHardwarePercentage

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced")
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SettingsSection(
                        title: "Battery Reading",
                        description:
                            "Choose how battery percentage is calculated and displayed."
                    ) {
                        SettingsToggleRow(
                            label: "Use hardware percentage",
                            isOn: $useHardwarePercentage,
                            tooltip:
                                "Use raw hardware battery percentage instead of macOS calibrated value"
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
    AdvancedSettingsView()
}

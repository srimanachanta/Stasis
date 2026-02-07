import Defaults
import SwiftUI

struct GeneralSettingsView: View {
    @Default(.launchAtLogin) var launchAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SettingsSection(title: "Startup") {
                        SettingsToggleRow(
                            label: "Launch at login",
                            isOn: $launchAtLogin,
                            tooltip:
                                "Automatically start Stasis when you log in to your Mac"
                        )
                    }
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLoginService.shared.setLaunchAtLogin(newValue)
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 400)
    }
}

#Preview {
    GeneralSettingsView()
}

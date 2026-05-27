import Defaults
import SwiftUI

struct AboutSettingsView: View {
    @Default(.automaticallyCheckForUpdates) var automaticallyCheckForUpdates
    @Default(.updateAutomationMode) var updateAutomationMode

    private let updaterService: UpdaterService

    init(updaterService: UpdaterService) {
        self.updaterService = updaterService
    }

    var body: some View {
        Form {
            Section("About Stasis") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Stasis")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Battery and charging control for MacBook.")
                        .foregroundStyle(.secondary)

                    if let versionText {
                        Text(versionText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            Section("Developer") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Srimana Achanta")
                        .fontWeight(.medium)
                    Text("Built with a focus on practical battery health and charging workflows.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            if UpdaterService.isHomebrewInstall {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Updates managed by Homebrew")
                                .fontWeight(.medium)
                            Text("Stasis was installed via Homebrew Cask. To update, run:")
                                .foregroundStyle(.secondary)
                            Text("brew upgrade --cask stasis")
                                .font(.system(.callout, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Updates")
                }
            } else {
                Section {
                    Toggle("Automatically check for updates", isOn: $automaticallyCheckForUpdates)

                    Picker("When updates are found", selection: $updateAutomationMode) {
                        Text("Notify only").tag(UpdaterService.UpdateAutomationMode.notify)
                        Text("Auto-download to Downloads folder").tag(UpdaterService.UpdateAutomationMode.autoDownload)
                    }
                    .disabled(!automaticallyCheckForUpdates)

                    Button("Check for updates now") {
                        updaterService.checkForUpdates()
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Updates")
                        Text("Stasis can check and download updates to your Downloads folder.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0)
        .onChange(of: automaticallyCheckForUpdates) { _, _ in
            // Update check preference saved automatically via Defaults
        }
    }

    private var versionText: String? {
        guard let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }

        return "Version \(shortVersion)"
    }
}

#Preview {
    AboutSettingsView(updaterService: UpdaterService.shared)
}

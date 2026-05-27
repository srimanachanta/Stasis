import AppKit
import Defaults
import Foundation

@MainActor
final class UpdaterService: NSObject {
    enum UpdateAutomationMode: String, CaseIterable, Defaults.Serializable {
        case notify
        case autoDownload
    }

    struct GitHubRelease: Decodable {
        let tagName: String
        let htmlUrl: String
        let assets: [Asset]
        
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
            case assets
        }
        
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: String
            
            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadUrl = "browser_download_url"
            }
        }
    }

    static let shared = UpdaterService()
    private var isChecking = false

    /// Returns `true` when the app was installed via Homebrew Cask.
    /// Homebrew manages the update lifecycle for cask-installed apps,
    /// so the built-in updater should be disabled entirely in this case.
    static var isHomebrewInstall: Bool {
        let bundlePath = Bundle.main.bundlePath
        let homebrewPrefixes = [
            "/opt/homebrew/Caskroom",   // Apple Silicon default
            "/usr/local/Caskroom",       // Intel default
            "/home/linuxbrew/.linuxbrew/Caskroom", // Linux Homebrew
        ]
        return homebrewPrefixes.contains { bundlePath.hasPrefix($0) }
    }

    private override init() {
        super.init()
    }

    func startIfAvailable() {
        // Auto-update is disabled for Homebrew installs; Homebrew manages updates.
        guard !UpdaterService.isHomebrewInstall else { return }
        if Defaults[.automaticallyCheckForUpdates] {
            checkForUpdates(automatic: true)
        }
    }

    func checkForUpdates() {
        // Manual update check is also disabled for Homebrew installs.
        guard !UpdaterService.isHomebrewInstall else { return }
        checkForUpdates(automatic: false)
    }

    private func checkForUpdates(automatic: Bool) {
        guard !isChecking else { return }
        isChecking = true
        
        Task {
            defer { isChecking = false }
            do {
                let url = URL(string: "https://api.github.com/repos/srimanachanta/Stasis/releases/latest")!
                var request = URLRequest(url: url)
                request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                
                let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
                guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
                
                if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    await handleUpdateFound(release: release, automatic: automatic, currentVersion: currentVersion)
                } else if !automatic {
                    await showUpToDateAlert()
                }
            } catch {
                print("Failed to check for updates: \(error)")
                if !automatic {
                    await showErrorAlert(error: error)
                }
            }
        }
    }

    private func handleUpdateFound(release: GitHubRelease, automatic: Bool, currentVersion: String) async {
        let mode = Defaults[.updateAutomationMode]
        
        guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }),
              let downloadURL = URL(string: dmgAsset.browserDownloadUrl) else {
            // Fallback to opening the release page if no DMG found
            if mode == .autoDownload || mode == .notify {
                await showNotifyAlert(releaseURL: URL(string: release.htmlUrl)!, version: release.tagName, currentVersion: currentVersion)
            }
            return
        }
        
        if mode == .autoDownload && automatic {
            await downloadAndNotify(url: downloadURL, version: release.tagName)
        } else {
            await showNotifyAlertWithDownload(downloadURL: downloadURL, version: release.tagName, currentVersion: currentVersion)
        }
    }

    private func downloadAndNotify(url: URL, version: String) async {
        do {
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let destinationURL = downloadsURL.appendingPathComponent("Stasis-\(version).dmg")
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            
            await showReadyToInstallAlert(dmgURL: destinationURL)
        } catch {
            print("Download failed: \(error)")
            await showErrorAlert(error: error)
        }
    }

    private func showUpToDateAlert() async {
        let alert = NSAlert()
        alert.messageText = "You're up to date!"
        alert.informativeText = "Stasis \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") is currently the newest version available."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showErrorAlert(error: Error) async {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = "Could not check for updates. \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showNotifyAlert(releaseURL: URL, version: String, currentVersion: String) async {
        let alert = NSAlert()
        alert.messageText = "A new version of Stasis is available!"
        alert.informativeText = "Version \(version) is available (You have \(currentVersion)). Would you like to view the release page?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "View Release")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releaseURL)
        }
    }

    private func showNotifyAlertWithDownload(downloadURL: URL, version: String, currentVersion: String) async {
        let alert = NSAlert()
        alert.messageText = "A new version of Stasis is available!"
        alert.informativeText = "Version \(version) is available (You have \(currentVersion)). Would you like to download it now?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            await downloadAndNotify(url: downloadURL, version: version)
        }
    }

    private func showReadyToInstallAlert(dmgURL: URL) async {
        let alert = NSAlert()
        alert.messageText = "Update Downloaded"
        let command = "xattr -cr /Applications/Stasis.app"
        
        alert.informativeText = """
        Stasis.dmg has been saved to your Downloads folder.
        
        To install the update:
        1. Quit Stasis.
        2. Open Stasis.dmg and drag Stasis to Applications.
        3. Run this command in Terminal to bypass Gatekeeper:
        
        \(command)
        """
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "Show in Finder")
        
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(command, forType: .string)
            
            // Show a quick notification that it was copied
            let copiedAlert = NSAlert()
            copiedAlert.messageText = "Command Copied"
            copiedAlert.informativeText = "The Terminal command has been copied to your clipboard."
            copiedAlert.runModal()
        } else if response == .alertThirdButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([dmgURL])
        }
    }

}

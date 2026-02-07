import AppKit
import SwiftUI

@MainActor
class SettingsWindowController {
    private var window: NSWindow?

    func showSettings() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Stasis Settings"
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        newWindow.center()
        newWindow.setFrameAutosaveName("SettingsWindow")
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        // Activate the app to bring the window to front
        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }
}

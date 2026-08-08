import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController()
        statusBarController?.showPanel()
    }

    // Fires when the Dock icon (manually added by the user, since this LSUIElement
    // app has no Dock tile of its own while running) is clicked while already running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showPanel()
        return true
    }
}

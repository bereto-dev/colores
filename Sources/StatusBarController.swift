import Cocoa

class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var panel: PickerPanel?
    private var aboutWindow: AboutWindow?

    override init() {
        super.init()

        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: "Colores")
            btn.image?.isTemplate = true
            btn.action = #selector(togglePanel)
            btn.target = self
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func togglePanel() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if let panel, panel.isVisible {
            panel.dismiss()
            return
        }

        showPanel()
    }

    /// Also called from the Dock icon (a manually-added launcher, since this is an
    /// LSUIElement app with no Dock tile of its own) via applicationShouldHandleReopen
    /// and on launch, so clicking it always results in the panel being visible instead
    /// of just relaunching a process with nothing to show for it.
    func showPanel() {
        guard let btn = statusItem.button else { return }
        if panel == nil {
            panel = PickerPanel()
        }
        if panel?.isVisible == true {
            panel?.orderFrontRegardless()
        } else {
            panel?.present(relativeTo: btn)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        // Colores has no Settings window, so the automatic-check toggle lives here.
        let autoCheck = NSMenuItem(title: "Check Automatically", action: #selector(toggleAutomaticChecks), keyEquivalent: "")
        autoCheck.target = self
        autoCheck.state = MainActor.assumeIsolated { Updater.shared.automaticallyChecks } ? .on : .off
        menu.addItem(autoCheck)
        menu.addItem(NSMenuItem.separator())

        let about = NSMenuItem(title: "About Colores", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Colores", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func checkForUpdates() {
        MainActor.assumeIsolated { Updater.shared.checkForUpdates() }
    }

    @objc private func toggleAutomaticChecks() {
        MainActor.assumeIsolated { Updater.shared.automaticallyChecks.toggle() }
    }

    @objc private func showAbout() {
        if aboutWindow == nil { aboutWindow = AboutWindow() }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }
}

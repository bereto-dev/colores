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

        guard let btn = statusItem.button else { return }
        if panel == nil {
            panel = PickerPanel()
        }
        panel?.present(relativeTo: btn)
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(openRepo), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        let about = NSMenuItem(title: "About Colores", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Colores", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openRepo() {
        NSWorkspace.shared.open(URL(string: "https://github.com/bereto-dev/colores")!)
    }

    @objc private func showAbout() {
        if aboutWindow == nil { aboutWindow = AboutWindow() }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }
}

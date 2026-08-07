import Cocoa

class AboutWindow: NSWindow {
    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "About Colores"
        isReleasedWhenClosed = false
        center()
        buildUI()
    }

    private func buildUI() {
        let root = NSView(frame: contentView!.bounds)
        contentView = root

        let appName = NSTextField(labelWithString: "Colores")
        appName.font = .boldSystemFont(ofSize: 20)

        let versionLabel = NSTextField(labelWithString: "Version \(Self.appVersionString)")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .tertiaryLabelColor

        let subtitle = NSTextField(wrappingLabelWithString: "A native Apple Silicon screen color picker.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let originHeader = sectionHeader("ORIGIN")
        let originBody = NSTextField(wrappingLabelWithString: "Built by Roberto Pacheco to replace Couleurs after macOS flagged it for losing Intel-app compatibility.")
        originBody.font = .systemFont(ofSize: 12)
        originBody.textColor = .secondaryLabelColor

        let supportHeader = sectionHeader("SUPPORT")
        let updatesBtn = linkButton(title: "🔄  Check for Updates", url: "https://github.com/bereto-dev/colores")
        let coffeeBtn = linkButton(title: "☕  Buy Me a Coffee", url: "https://buymeacoffee.com/bereto")
        let devBtn = linkButton(title: "🌐  devteam.partners", url: "https://devteam.partners/about-us")

        let stack = NSStackView(views: [
            appName, versionLabel, subtitle,
            div(),
            originHeader, originBody,
            div(),
            supportHeader, updatesBtn, coffeeBtn, devBtn,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(2, after: appName)

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
            subtitle.widthAnchor.constraint(equalToConstant: 292),
            originBody.widthAnchor.constraint(equalToConstant: 292),
        ])

        root.layoutSubtreeIfNeeded()
        let h = stack.fittingSize.height
        setContentSize(NSSize(width: 340, height: h))
    }

    private static var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func sectionHeader(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = .systemFont(ofSize: 10, weight: .semibold)
        f.textColor = .tertiaryLabelColor
        return f
    }

    private func div() -> NSView {
        let v = NSBox()
        v.boxType = .separator
        v.widthAnchor.constraint(equalToConstant: 292).isActive = true
        return v
    }

    private func linkButton(title: String, url: String) -> NSButton {
        let b = NSButton(title: title, target: self, action: #selector(openLink(_:)))
        b.bezelStyle = .inline
        b.isBordered = false
        b.font = .systemFont(ofSize: 12)
        b.contentTintColor = .linkColor
        b.identifier = NSUserInterfaceItemIdentifier(url)
        return b
    }

    @objc private func openLink(_ sender: NSButton) {
        guard let urlStr = sender.identifier?.rawValue, let url = URL(string: urlStr) else { return }
        NSWorkspace.shared.open(url)
    }
}

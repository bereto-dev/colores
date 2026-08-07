import Cocoa

private let PANEL_W: CGFloat = 240
private let PAD: CGFloat = 12

class PickerPanel: NSPanel {

    private let swatchView = SwatchView()
    private let valueLabel = ClickableLabel(labelWithString: "Pick a color to start")
    private let formatControl = NSSegmentedControl(labels: ColorFormat.allCases.map(\.label), trackingMode: .selectOne, target: nil, action: nil)
    private let pickButton = NSButton()
    private let copyButton = NSButton()
    private let autoCopyCheckbox = NSButton(checkboxWithTitle: "Auto-copy on pick", target: nil, action: nil)
    private let recentLabel = label("RECENT", size: 9, weight: .semibold, alpha: 0.4)
    private let clearHistoryButton = NSButton(title: "Clear", target: nil, action: nil)
    private let historyStack = NSStackView()
    private var card: CardView!

    private var currentColor: NSColor?
    private var globalClickMonitor: Any?

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: PANEL_W, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        buildUI()
        refreshHistory()
    }

    // MARK: - UI

    private func buildUI() {
        let root = NSView(frame: contentView!.bounds)
        root.autoresizingMask = [.width, .height]
        contentView = root

        card = CardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: root.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 6),
            card.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -6),
            card.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -6),
        ])

        swatchView.translatesAutoresizingMaskIntoConstraints = false
        swatchView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        swatchView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        swatchView.onClick = { [weak self] in self?.copyCurrent() }

        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.maximumNumberOfLines = 1
        valueLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        valueLabel.textColor = NSColor.white.withAlphaComponent(0.9)
        valueLabel.onClick = { [weak self] in self?.copyCurrent() }

        let topRow = NSStackView(views: [swatchView, valueLabel])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 8

        formatControl.segmentDistribution = .fillEqually
        formatControl.selectedSegment = ColorFormat.allCases.firstIndex(of: ColorPreferences.format) ?? 0
        formatControl.target = self
        formatControl.action = #selector(formatChanged)

        pickButton.title = "Pick Color"
        pickButton.bezelStyle = .rounded
        pickButton.target = self
        pickButton.action = #selector(pickColorTapped)
        pickButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

        copyButton.title = "Copy"
        copyButton.bezelStyle = .rounded
        copyButton.target = self
        copyButton.action = #selector(copyCurrent)
        copyButton.isEnabled = false

        let buttonRow = NSStackView(views: [pickButton, copyButton])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 8

        autoCopyCheckbox.font = .systemFont(ofSize: 11)
        (autoCopyCheckbox.cell as? NSButtonCell)?.attributedTitle = NSAttributedString(
            string: "Auto-copy on pick",
            attributes: [.foregroundColor: NSColor.white.withAlphaComponent(0.8), .font: NSFont.systemFont(ofSize: 11)]
        )
        autoCopyCheckbox.state = ColorPreferences.autoCopyOnPick ? .on : .off
        autoCopyCheckbox.target = self
        autoCopyCheckbox.action = #selector(autoCopyToggled)

        clearHistoryButton.bezelStyle = .inline
        clearHistoryButton.isBordered = false
        (clearHistoryButton.cell as? NSButtonCell)?.attributedTitle = NSAttributedString(
            string: "Clear",
            attributes: [.foregroundColor: NSColor.white.withAlphaComponent(0.4), .font: NSFont.systemFont(ofSize: 9, weight: .semibold)]
        )
        clearHistoryButton.target = self
        clearHistoryButton.action = #selector(clearHistoryTapped)

        let historySpacer = NSView()
        historySpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let historyHeaderRow = NSStackView(views: [recentLabel, historySpacer, clearHistoryButton])
        historyHeaderRow.orientation = .horizontal
        historyHeaderRow.alignment = .centerY
        historyHeaderRow.spacing = 4

        historyStack.orientation = .horizontal
        historyStack.alignment = .centerY
        historyStack.spacing = 6

        let rootStack = NSStackView(views: [
            topRow,
            formatControl,
            buttonRow,
            autoCopyCheckbox,
            Divider(),
            historyHeaderRow,
            historyStack,
        ])
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 10
        rootStack.edgeInsets = NSEdgeInsets(top: PAD, left: PAD, bottom: PAD, right: PAD)
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: card.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            formatControl.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -PAD * 2),
            buttonRow.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -PAD * 2),
            historyHeaderRow.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -PAD * 2),
        ])
    }

    private func resize() {
        contentView?.layoutSubtreeIfNeeded()
        let fit = contentView!.fittingSize
        setContentSize(NSSize(width: PANEL_W, height: fit.height))
    }

    // MARK: - Show / hide (with click-away dismissal)

    func present(relativeTo button: NSStatusBarButton) {
        guard let screen = button.window?.screen ?? NSScreen.main else { return }

        let btnFrame = button.window!.convertToScreen(button.frame)
        var x = btnFrame.midX - PANEL_W / 2
        let y = btnFrame.minY - 8
        x = min(x, screen.visibleFrame.maxX - PANEL_W - 8)
        x = max(x, screen.visibleFrame.minX + 8)

        resize()
        setFrameTopLeftPoint(NSPoint(x: x, y: y))
        orderFrontRegardless()

        // The color selector should already be active the moment the panel appears.
        beginPicking()
    }

    func dismiss() {
        orderOut(nil)
        removeClickAwayMonitor()
    }

    private func installClickAwayMonitor() {
        removeClickAwayMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
    }

    private func removeClickAwayMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    // MARK: - Actions

    @objc private func pickColorTapped() {
        beginPicking()
    }

    private func beginPicking() {
        // The sampler's own confirm-click is a real global mouse-down; without
        // pulling the click-away monitor first, that click would immediately
        // dismiss this panel instead of landing on the sampled pixel.
        removeClickAwayMonitor()
        NSColorSampler().show { [weak self] pickedColor in
            guard let self else { return }
            if let color = pickedColor {
                self.updateCurrentColor(color)
            }
            if self.isVisible {
                self.installClickAwayMonitor()
            }
        }
    }

    @objc private func formatChanged() {
        ColorPreferences.format = ColorFormat.allCases[formatControl.selectedSegment]
        refreshValueLabel()
        copyCurrent()
    }

    @objc private func autoCopyToggled() {
        ColorPreferences.autoCopyOnPick = autoCopyCheckbox.state == .on
    }

    @objc private func copyCurrent() {
        guard let color = currentColor, let string = ColorFormatter.string(from: color, format: ColorPreferences.format) else { return }
        PasteboardWriter.copy(string)
    }

    @objc private func clearHistoryTapped() {
        ColorPreferences.clearHistory()
        refreshHistory()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
            copyCurrent()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: - State

    private func updateCurrentColor(_ color: NSColor) {
        currentColor = color
        swatchView.color = color
        copyButton.isEnabled = true
        refreshValueLabel()

        if let hex = ColorFormatter.hexString(from: color) {
            ColorPreferences.pushHistory(hex: hex)
            refreshHistory()
        }
        if ColorPreferences.autoCopyOnPick {
            copyCurrent()
        }
    }

    private func refreshValueLabel() {
        guard let color = currentColor, let string = ColorFormatter.string(from: color, format: ColorPreferences.format) else { return }
        valueLabel.stringValue = string
    }

    private func refreshHistory() {
        for view in historyStack.arrangedSubviews {
            historyStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let items = ColorPreferences.history
        clearHistoryButton.isHidden = items.isEmpty
        for hex in items {
            guard let color = ColorFormatter.color(fromHex: hex) else { continue }
            let swatch = HistorySwatchView(
                color: color,
                hex: hex,
                onClick: { [weak self] _, pickedColor in
                    guard let self else { return }
                    self.currentColor = pickedColor
                    self.swatchView.color = pickedColor
                    self.copyButton.isEnabled = true
                    self.refreshValueLabel()
                    self.copyCurrent()
                },
                onRemove: { [weak self] removedHex in
                    ColorPreferences.removeHistory(hex: removedHex)
                    self?.refreshHistory()
                }
            )
            swatch.translatesAutoresizingMaskIntoConstraints = false
            swatch.widthAnchor.constraint(equalToConstant: 18).isActive = true
            swatch.heightAnchor.constraint(equalToConstant: 18).isActive = true
            historyStack.addArrangedSubview(swatch)
        }
        resize()
    }
}

// MARK: - Helpers

private func label(_ s: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) -> NSTextField {
    let f = NSTextField(labelWithString: s)
    f.font = .systemFont(ofSize: size, weight: weight)
    f.textColor = NSColor.white.withAlphaComponent(alpha)
    return f
}

private class CardView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        NSColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 0.97).setFill()
        path.fill()
    }
}

private class Divider: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: -1, height: 1) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.1).setFill()
        bounds.fill()
    }
}

/// The large color preview swatch at the top of the panel — click it to copy, same as the Copy button.
private class SwatchView: NSView {
    var color: NSColor = .clear { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        color.setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.15).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// A text label that copies the current color when clicked, same as the Copy button.
private class ClickableLabel: NSTextField {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// A small swatch in the recent-colors strip: click to copy, right-click to remove.
private class HistorySwatchView: NSView {
    private let color: NSColor
    private let hex: String
    private let onClick: (String, NSColor) -> Void
    private let onRemove: (String) -> Void

    init(color: NSColor, hex: String, onClick: @escaping (String, NSColor) -> Void, onRemove: @escaping (String) -> Void) {
        self.color = color
        self.hex = hex
        self.onClick = onClick
        self.onRemove = onRemove
        super.init(frame: .zero)
        toolTip = hex
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        color.setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.15).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        onClick(hex, color)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let remove = NSMenuItem(title: "Remove from History", action: #selector(removeSelf), keyEquivalent: "")
        remove.target = self
        menu.items = [remove]
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func removeSelf() {
        onRemove(hex)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

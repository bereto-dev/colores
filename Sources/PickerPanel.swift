import Cocoa

// Sized so the history row (+ tile plus 6 colors, 7 × HISTORY_SWATCH + 6 × spacing = 202)
// exactly fills the same content width as every other row: card width (PANEL_W - 12
// for the outer margin) minus PAD on each side.
private let PANEL_W: CGFloat = 238
private let PAD: CGFloat = 12
private let HISTORY_SWATCH: CGFloat = 22

class PickerPanel: NSPanel {

    private let swatchView = SwatchView()
    private let valueLabel = ClickableLabel(labelWithString: "Pick a color to start")
    private let formatControl = NSSegmentedControl(labels: ColorFormat.allCases.map(\.label), trackingMode: .selectOne, target: nil, action: nil)
    private let copyFeedbackLabel = label("✓ Copied to clipboard", size: 10, weight: .medium, alpha: 0.8)
    private let recentLabel = label("RECENT", size: 9, weight: .semibold, alpha: 0.4)
    private let clearHistoryButton = NSButton(title: "Clear", target: nil, action: nil)
    private let historyStack = NSStackView()
    private var card: CardView!

    private var currentColor: NSColor?
    private var globalClickMonitor: Any?
    private var copyFeedbackTimer: Timer?

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
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let topRow = NSStackView(views: [swatchView, valueLabel])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 8

        formatControl.segmentDistribution = .fillEqually
        formatControl.selectedSegment = ColorFormat.allCases.firstIndex(of: ColorPreferences.format) ?? 0
        formatControl.target = self
        formatControl.action = #selector(formatChanged)

        copyFeedbackLabel.alphaValue = 0

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
        historyStack.spacing = 8

        let rootStack = NSStackView(views: [
            topRow,
            formatControl,
            copyFeedbackLabel,
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
            topRow.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -PAD * 2),
            formatControl.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -PAD * 2),
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
        installClickAwayMonitor()
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

    @objc private func copyCurrent() {
        guard let color = currentColor, let string = ColorFormatter.string(from: color, format: ColorPreferences.format) else { return }
        PasteboardWriter.copy(string)
        showCopyFeedback()
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
        refreshValueLabel()

        if let hex = ColorFormatter.hexString(from: color) {
            ColorPreferences.pushHistory(hex: hex)
            refreshHistory()
        }
        copyCurrent()
    }

    private func refreshValueLabel() {
        guard let color = currentColor, let string = ColorFormatter.string(from: color, format: ColorPreferences.format) else { return }
        valueLabel.stringValue = string
    }

    private func showCopyFeedback() {
        copyFeedbackTimer?.invalidate()
        copyFeedbackLabel.animator().alphaValue = 1
        copyFeedbackTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                self?.copyFeedbackLabel.animator().alphaValue = 0
            }
        }
    }

    private func refreshHistory() {
        for view in historyStack.arrangedSubviews {
            historyStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let addTile = AddSwatchView()
        addTile.onClick = { [weak self] in self?.beginPicking() }
        constrainToHistorySize(addTile)
        historyStack.addArrangedSubview(addTile)

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
                    self.refreshValueLabel()
                    self.copyCurrent()
                },
                onRemove: { [weak self] removedHex in
                    ColorPreferences.removeHistory(hex: removedHex)
                    self?.refreshHistory()
                }
            )
            constrainToHistorySize(swatch)
            historyStack.addArrangedSubview(swatch)
        }
        resize()
    }

    private func constrainToHistorySize(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: HISTORY_SWATCH).isActive = true
        view.heightAnchor.constraint(equalToConstant: HISTORY_SWATCH).isActive = true
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

/// The large color preview swatch at the top of the panel — click it to copy.
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

/// A text label that copies the current color when clicked, same as clicking the swatch.
private class ClickableLabel: NSTextField {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// The first tile in the history strip: an empty dashed box with a "+", the only way to start picking a color.
private class AddSwatchView: NSView {
    var onClick: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
        NSColor.white.withAlphaComponent(0.06).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.25).setStroke()
        path.lineWidth = 1
        path.stroke()

        let inset = bounds.width * 0.3
        let plus = NSBezierPath()
        plus.move(to: NSPoint(x: bounds.midX, y: inset))
        plus.line(to: NSPoint(x: bounds.midX, y: bounds.height - inset))
        plus.move(to: NSPoint(x: inset, y: bounds.midY))
        plus.line(to: NSPoint(x: bounds.width - inset, y: bounds.midY))
        plus.lineWidth = 1.5
        NSColor.white.withAlphaComponent(0.65).setStroke()
        plus.stroke()
    }

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// A small swatch in the recent-colors strip: click to copy, hover to reveal a remove button.
private class HistorySwatchView: NSView {
    private let color: NSColor
    private let hex: String
    private let onClick: (String, NSColor) -> Void
    private let onRemove: (String) -> Void
    private var trackingArea: NSTrackingArea?

    private let removeButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove")!, target: nil, action: nil)
        b.bezelStyle = .inline
        b.isBordered = false
        b.imageScaling = .scaleProportionallyUpOrDown
        b.contentTintColor = .white
        b.isHidden = true
        return b
    }()

    init(color: NSColor, hex: String, onClick: @escaping (String, NSColor) -> Void, onRemove: @escaping (String) -> Void) {
        self.color = color
        self.hex = hex
        self.onClick = onClick
        self.onRemove = onRemove
        super.init(frame: .zero)
        toolTip = hex
        addSubview(removeButton)
        removeButton.target = self
        removeButton.action = #selector(removeSelf)
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

    override func layout() {
        super.layout()
        let size: CGFloat = 13
        removeButton.frame = NSRect(x: bounds.width - size + 4, y: bounds.height - size + 4, width: size, height: size)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { removeButton.isHidden = false }
    override func mouseExited(with event: NSEvent) { removeButton.isHidden = true }

    override func mouseDown(with event: NSEvent) {
        onClick(hex, color)
    }

    @objc private func removeSelf() {
        onRemove(hex)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

import Cocoa

// Sized so the history row (+ tile plus 5 colors, 6 × HISTORY_SWATCH + 5 × spacing = 172)
// exactly fills the same content width as every other row: card width (PANEL_W - 12
// for the outer margin) minus PAD on each side.
private let PANEL_W: CGFloat = 208
private let PAD: CGFloat = 12
private let HISTORY_SWATCH: CGFloat = 22
private let SWATCH_PREVIEW: CGFloat = 32
private let TOP_ROW_SPACING: CGFloat = 8
// Space left for the value label once the preview swatch and row spacing are subtracted.
private let VALUE_LABEL_WIDTH: CGFloat = PANEL_W - 12 - PAD * 2 - SWATCH_PREVIEW - TOP_ROW_SPACING

class PickerPanel: NSPanel {

    private let swatchView = SwatchView()
    private let valueLabel = ClickableLabel(labelWithString: "Pick a color")
    private let formatControl = FormatToggle()
    private let copyToast = CopyToastView()
    private let recentLabel = label("Recent", size: 9, weight: .semibold, alpha: 0.4)
    private let clearHistoryButton = NSButton(title: "Clear", target: nil, action: nil)
    private let historyDivider = Divider()
    private let historyHeaderRow = NSStackView()
    private let historyStack = NSStackView()
    private var card: CardView!

    private var currentColor: NSColor?
    private var copyFeedbackTimer: Timer?
    private var hasBeenPositioned = false

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: PANEL_W, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        // .floating (not .popUpMenu) is the level persistent utility palettes use to
        // stay above other apps' windows indefinitely — this panel is meant to be
        // left open on screen while working in another app, not dismissed the moment
        // you click elsewhere.
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
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
        swatchView.widthAnchor.constraint(equalToConstant: SWATCH_PREVIEW).isActive = true
        swatchView.heightAnchor.constraint(equalToConstant: SWATCH_PREVIEW).isActive = true
        swatchView.onClick = { [weak self] in
            guard let self else { return }
            if self.currentColor == nil {
                self.beginPicking()
            } else {
                self.copyCurrent()
            }
        }

        valueLabel.maximumNumberOfLines = 1
        valueLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        valueLabel.textColor = NSColor.white.withAlphaComponent(0.9)
        valueLabel.onClick = { [weak self] in self?.copyCurrent() }
        valueLabel.lineBreakMode = .byClipping
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let topRow = NSStackView(views: [swatchView, valueLabel])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = TOP_ROW_SPACING

        formatControl.selectedSegment = ColorFormat.allCases.firstIndex(of: ColorPreferences.format) ?? 0
        formatControl.target = self
        formatControl.action = #selector(formatChanged)

        let trashConfig = NSImage.SymbolConfiguration(pointSize: 8, weight: .regular)
        clearHistoryButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear history")?
            .withSymbolConfiguration(trashConfig)
        clearHistoryButton.image?.isTemplate = true
        clearHistoryButton.imagePosition = .imageLeading
        clearHistoryButton.imageScaling = .scaleProportionallyDown
        clearHistoryButton.bezelStyle = .inline
        clearHistoryButton.isBordered = false
        clearHistoryButton.contentTintColor = NSColor.white.withAlphaComponent(0.4)
        (clearHistoryButton.cell as? NSButtonCell)?.attributedTitle = NSAttributedString(
            string: "Clear",
            attributes: [.foregroundColor: NSColor.white.withAlphaComponent(0.4), .font: NSFont.systemFont(ofSize: 9, weight: .semibold)]
        )
        clearHistoryButton.target = self
        clearHistoryButton.action = #selector(clearHistoryTapped)

        let historySpacer = NSView()
        historySpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        historyHeaderRow.addArrangedSubview(recentLabel)
        historyHeaderRow.addArrangedSubview(historySpacer)
        historyHeaderRow.addArrangedSubview(clearHistoryButton)
        historyHeaderRow.orientation = .horizontal
        historyHeaderRow.alignment = .centerY
        historyHeaderRow.spacing = 4

        historyStack.orientation = .horizontal
        historyStack.alignment = .centerY
        historyStack.spacing = 8

        let rootStack = NSStackView(views: [
            topRow,
            formatControl,
            historyDivider,
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

        // Added last so it renders above the card and everything in it, and lives
        // outside rootStack so it never reserves its own row height.
        copyToast.translatesAutoresizingMaskIntoConstraints = false
        copyToast.alphaValue = 0
        root.addSubview(copyToast)
        NSLayoutConstraint.activate([
            copyToast.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            copyToast.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
        ])
    }

    private func resize() {
        contentView?.layoutSubtreeIfNeeded()
        let fit = contentView!.fittingSize
        setContentSize(NSSize(width: PANEL_W, height: fit.height))
    }

    // MARK: - Show / hide

    func present(relativeTo button: NSStatusBarButton) {
        // Auto-position under the menu bar icon the first time this panel is ever
        // shown, and also re-anchor it any time its last known position no longer
        // falls on any currently connected screen — e.g. it was parked on an external
        // monitor that then got unplugged. Otherwise leave it wherever the user last
        // dragged it, since it's meant to stay parked on screen across app switches
        // and snapping it back under the icon on every reopen would undo that.
        if !hasBeenPositioned || !isOnAnyScreen() {
            if let screen = button.window?.screen ?? NSScreen.main {
                let btnFrame = button.window!.convertToScreen(button.frame)
                var x = btnFrame.midX - PANEL_W / 2
                let y = btnFrame.minY - 8
                x = min(x, screen.visibleFrame.maxX - PANEL_W - 8)
                x = max(x, screen.visibleFrame.minX + 8)
                setFrameTopLeftPoint(NSPoint(x: x, y: y))
            }
            hasBeenPositioned = true
        }
        resize()
        orderFrontRegardless()
    }

    private func isOnAnyScreen() -> Bool {
        NSScreen.screens.contains { $0.frame.intersects(frame) }
    }

    func dismiss() {
        orderOut(nil)
    }

    // MARK: - Actions

    private func beginPicking() {
        NSColorSampler().show { [weak self] pickedColor in
            guard let self, let color = pickedColor else { return }
            self.updateCurrentColor(color)
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
        swatchView.isEmpty = false
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
        valueLabel.font = Self.fittedMonospaceFont(for: string, maxWidth: VALUE_LABEL_WIDTH)
    }

    /// AppKit has no `adjustsFontSizeToFitWidth` (that's UIKit); shrink manually instead
    /// of letting rgba(...), the longest string this ever shows, get clipped or ellipsized.
    private static func fittedMonospaceFont(for text: String, maxWidth: CGFloat, maxSize: CGFloat = 12, minSize: CGFloat = 9) -> NSFont {
        let full = NSFont.monospacedSystemFont(ofSize: maxSize, weight: .medium)
        let measured = (text as NSString).size(withAttributes: [.font: full]).width
        guard measured > maxWidth, measured > 0 else { return full }
        let scaledSize = max(minSize, maxSize * maxWidth / measured)
        return .monospacedSystemFont(ofSize: scaledSize, weight: .medium)
    }

    private func showCopyFeedback() {
        copyFeedbackTimer?.invalidate()
        copyToast.animator().alphaValue = 1
        copyFeedbackTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                self?.copyToast.animator().alphaValue = 0
            }
        }
    }

    private func refreshHistory() {
        for view in historyStack.arrangedSubviews {
            historyStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let items = ColorPreferences.history
        let isEmpty = items.isEmpty
        historyDivider.isHidden = isEmpty
        historyHeaderRow.isHidden = isEmpty
        historyStack.isHidden = isEmpty
        guard !isEmpty else {
            // No colors left anywhere — whether from Clear or from removing every
            // swatch one by one — so the add tile that lived in this now-hidden strip
            // is gone too. Reset the top preview back to its own "+" state so there's
            // still a way to start picking again, matching a first launch.
            currentColor = nil
            swatchView.isEmpty = true
            valueLabel.stringValue = "Pick a color"
            valueLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            resize()
            return
        }

        let addTile = AddSwatchView()
        addTile.onClick = { [weak self] in self?.beginPicking() }
        constrainToHistorySize(addTile)
        historyStack.addArrangedSubview(addTile)

        for hex in items {
            guard let color = ColorFormatter.color(fromHex: hex) else { continue }
            let swatch = HistorySwatchView(
                color: color,
                hex: hex,
                onClick: { [weak self] _, pickedColor in
                    guard let self else { return }
                    self.currentColor = pickedColor
                    self.swatchView.color = pickedColor
                    self.swatchView.isEmpty = false
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

/// Custom Hex/RGB toggle. NSSegmentedControl's Aqua bezel draws a white selected
/// pill with dark labels — unreadable on this dark panel, especially on Intel.
private class FormatToggle: NSControl {
    private static let activeFill = NSColor(srgbRed: 81 / 255, green: 81 / 255, blue: 83 / 255, alpha: 1) // #515153
    private static let inactiveFill = NSColor(srgbRed: 42 / 255, green: 42 / 255, blue: 44 / 255, alpha: 1) // #2A2A2C
    private static let titles = ColorFormat.allCases.map(\.label)

    var selectedSegment: Int = 0 {
        didSet { if selectedSegment != oldValue { needsDisplay = true } }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 24)
    }

    override func draw(_ dirtyRect: NSRect) {
        let count = Self.titles.count
        let segmentW = bounds.width / CGFloat(count)

        let track = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        Self.inactiveFill.setFill()
        track.fill()

        let selectedRect = NSRect(
            x: CGFloat(selectedSegment) * segmentW + 1,
            y: 1,
            width: segmentW - 2,
            height: bounds.height - 2
        )
        let selected = NSBezierPath(roundedRect: selectedRect, xRadius: 5, yRadius: 5)
        Self.activeFill.setFill()
        selected.fill()

        for (i, title) in Self.titles.enumerated() {
            let isSelected = i == selectedSegment
            let rect = NSRect(x: CGFloat(i) * segmentW, y: 0, width: segmentW, height: bounds.height)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: isSelected ? .semibold : .medium),
                .foregroundColor: isSelected ? NSColor.white : NSColor.white.withAlphaComponent(0.55),
            ]
            let size = title.size(withAttributes: attrs)
            title.draw(
                at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                withAttributes: attrs
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let count = Self.titles.count
        let index = min(count - 1, max(0, Int(loc.x / (bounds.width / CGFloat(count)))))
        selectedSegment = index
        sendAction(action, to: target)
        needsDisplay = true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

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

/// The large color preview swatch at the top of the panel. Before any color has
/// been picked this session it shows the same empty "+" tile as the history strip's
/// add tile and triggers picking when clicked; once a color is set, it shows that
/// color and copies it when clicked instead.
private class SwatchView: NSView {
    var color: NSColor = .clear { didSet { needsDisplay = true } }
    var isEmpty: Bool = true { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        if isEmpty {
            drawPlusTile(in: bounds, radius: 6)
            return
        }
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

/// Floating "Copied" pill overlaid on top of the whole panel — has its own opaque
/// background since it can appear over any swatch color underneath it.
private class CopyToastView: NSView {
    private let label = NSTextField(labelWithString: "✓ Copied")

    override init(frame: NSRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        NSColor.black.withAlphaComponent(0.88).setFill()
        path.fill()
    }
}

/// Shared look for an empty, dashed "+" tile — used by the history strip's add tile
/// and by the top preview swatch before any color has been picked.
private func drawPlusTile(in bounds: NSRect, radius: CGFloat) {
    let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
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

/// The first tile in the history strip: an empty dashed box with a "+", the only way to start picking a color.
private class AddSwatchView: NSView {
    var onClick: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        drawPlusTile(in: bounds, radius: 4)
    }

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// The hover-revealed delete badge on a history swatch. Draws its own opaque white
/// circle behind the × so it stays legible over any swatch color underneath — an
/// SF Symbol tinted white alone let the swatch color show through and vanished on
/// light backgrounds.
private class RemoveBadge: NSView {
    var onClick: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds)
        NSColor.white.setFill()
        circle.fill()

        let inset = bounds.width * 0.32
        let x = NSBezierPath()
        x.move(to: NSPoint(x: inset, y: inset))
        x.line(to: NSPoint(x: bounds.width - inset, y: bounds.height - inset))
        x.move(to: NSPoint(x: bounds.width - inset, y: inset))
        x.line(to: NSPoint(x: inset, y: bounds.height - inset))
        x.lineWidth = 1.3
        x.lineCapStyle = .round
        NSColor.black.setStroke()
        x.stroke()
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

    private let removeButton = RemoveBadge()

    init(color: NSColor, hex: String, onClick: @escaping (String, NSColor) -> Void, onRemove: @escaping (String) -> Void) {
        self.color = color
        self.hex = hex
        self.onClick = onClick
        self.onRemove = onRemove
        super.init(frame: .zero)
        toolTip = hex
        removeButton.isHidden = true
        addSubview(removeButton)
        removeButton.onClick = { [weak self] in self?.removeSelf() }
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
        let size: CGFloat = 10
        removeButton.frame = NSRect(x: bounds.width - size + 3, y: bounds.height - size + 3, width: size, height: size)
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

    private func removeSelf() {
        onRemove(hex)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

import Carbon
import AppKit

@MainActor
final class CalculatorPanelController: NSWindowController, NSWindowDelegate {
    private enum Layout {
        static let width: CGFloat = 244
        static let height: CGFloat = 348
        static let padding: CGFloat = 14
        static let gap: CGFloat = 10
        static let chromeHeight: CGFloat = 26
        static let keyHeight: CGFloat = 44
        static let keyWidth: CGFloat = 46
        static let zeroWidth: CGFloat = (keyWidth * 2) + gap
    }

    private let calculator: CalculatorEngine
    private let displayLabel = CopyableDisplayField(labelWithString: "0")
    private let displayContainer = NSView()
    private let copyButton = NSButton()
    private let pinButton = NSButton()
    private let keyView: CalculatorKeyView
    private var buttonsByKey: [String: CalculatorButton] = [:]
    private var keyMonitor: Any?
    private var shortcutPanel: NSPanel?
    private var isPinned = UserDefaults.standard.bool(forKey: DefaultsKey.isPinned) {
        didSet {
            UserDefaults.standard.set(isPinned, forKey: DefaultsKey.isPinned)
            updatePinnedMode()
        }
    }

    var onQuit: (() -> Void)?

    var isVisible: Bool {
        window?.isVisible == true
    }

    init(calculator: CalculatorEngine) {
        self.calculator = calculator
        keyView = CalculatorKeyView(calculator: calculator)

        let panel = CalculatorPanel(
            contentRect: NSRect(x: 0, y: 0, width: Layout.width, height: Layout.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        super.init(window: panel)
        panel.delegate = self
        buildContent()

        calculator.onChange = { [weak self] in
            self?.updateDisplay()
        }
        displayLabel.onDoubleClick = { [weak self] in
            self?.copyOutput()
        }
        keyView.onKeyboardAction = { [weak self] key in
            self?.flashKey(key)
        }
        keyView.onClose = { [weak self] in
            self?.hide()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show(relativeTo button: NSStatusBarButton) {
        guard let window else { return }

        updatePinnedMode()

        if isPinned, let savedOrigin = savedPinnedOrigin() {
            window.setFrameOrigin(constrainedOrigin(savedOrigin, for: window))
        } else if isPinned, window.frame.origin != .zero {
            window.setFrameOrigin(constrainedOrigin(window.frame.origin, for: window))
        } else {
            let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
            let screenFrame = button.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            let proposedX = buttonFrame.midX - window.frame.width + 28
            let x = min(max(proposedX, screenFrame.minX + 8), screenFrame.maxX - window.frame.width - 8)
            let y = buttonFrame.minY - window.frame.height - 8

            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(keyView)
        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()
    }

    func hide() {
        hideShortcutPanel()
        window?.orderOut(nil)
        removeKeyMonitor()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Persistent by design: the user can keep the calculator open while checking numbers elsewhere.
    }

    func windowDidMove(_ notification: Notification) {
        guard isPinned, let window else { return }
        savePinnedOrigin(window.frame.origin)
        positionShortcutPanel()
    }

    private func buildContent() {
        let root = DraggableVisualEffectView()
        root.material = .underWindowBackground
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 0.96).cgColor
        root.layer?.cornerRadius = 16
        root.layer?.cornerCurve = .continuous
        root.layer?.masksToBounds = true
        root.layer?.borderWidth = 1
        root.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor

        let titleButton = makeHeaderMenuButton()
        configurePinButton()
        let closeButton = makeCloseButton()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(
            top: Layout.padding + Layout.chromeHeight,
            left: Layout.padding,
            bottom: Layout.padding,
            right: Layout.padding
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(makeDisplay())
        stack.addArrangedSubview(makeButtonPad())

        root.addSubview(titleButton)
        root.addSubview(pinButton)
        root.addSubview(closeButton)
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            titleButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            titleButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleButton.trailingAnchor.constraint(lessThanOrEqualTo: pinButton.leadingAnchor, constant: -12),
            pinButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            pinButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            pinButton.widthAnchor.constraint(equalToConstant: 24),
            pinButton.heightAnchor.constraint(equalToConstant: 24),
            closeButton.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        window?.contentView = root
        updatePinnedMode()
    }

    private func makeHeaderMenuButton() -> NSButton {
        let button = NSButton(title: "Calc Bar ▾", target: self, action: #selector(headerMenuButtonPressed(_:)))
        button.isBordered = false
        button.alignment = .left
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        button.contentTintColor = NSColor.black.withAlphaComponent(0.72)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private func configurePinButton() {
        pinButton.isBordered = false
        pinButton.imagePosition = .imageOnly
        pinButton.target = self
        pinButton.action = #selector(pinButtonPressed)
        pinButton.wantsLayer = true
        pinButton.layer?.cornerRadius = 12
        pinButton.layer?.cornerCurve = .continuous
        pinButton.layer?.borderWidth = 0.5
        pinButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func makeCloseButton() -> NSButton {
        let closeButton = NSButton(title: "×", target: self, action: #selector(closeButtonPressed))
        closeButton.isBordered = false
        closeButton.font = .systemFont(ofSize: 18, weight: .bold)
        closeButton.contentTintColor = NSColor.white.withAlphaComponent(0.86)
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 12
        closeButton.layer?.cornerCurve = .continuous
        closeButton.layer?.backgroundColor = NSColor(calibratedWhite: 0.22, alpha: 0.92).cgColor
        closeButton.layer?.borderWidth = 0.5
        closeButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        return closeButton
    }

    private func makeDisplay() -> NSView {
        let container = displayContainer
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.cornerCurve = .continuous
        container.layer?.backgroundColor = displayBackgroundColor.cgColor

        displayLabel.alignment = .right
        displayLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .light)
        displayLabel.textColor = .white
        displayLabel.backgroundColor = .clear
        displayLabel.isBordered = false
        displayLabel.isEditable = false
        displayLabel.isSelectable = true
        displayLabel.focusRingType = .none
        displayLabel.lineBreakMode = .byTruncatingHead
        displayLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        configureCopyButton()

        container.addSubview(copyButton)
        container.addSubview(displayLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 60),
            copyButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            copyButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 22),
            copyButton.heightAnchor.constraint(equalToConstant: 22),
            displayLabel.leadingAnchor.constraint(equalTo: copyButton.trailingAnchor, constant: 6),
            displayLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            displayLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: 1)
        ])

        return container
    }

    private func updateDisplay() {
        displayLabel.stringValue = calculator.outputText
        displayContainer.layer?.backgroundColor = displayBackgroundColor.cgColor
        updateCopyButtonTint()
    }

    private var displayBackgroundColor: NSColor {
        if calculator.isComplete {
            return NSColor(calibratedRed: 0.16, green: 0.58, blue: 0.44, alpha: 1)
        }
        return NSColor(calibratedWhite: 0.015, alpha: 0.84)
    }

    @objc private func closeButtonPressed() {
        hide()
    }

    @objc private func copyButtonPressed() {
        copyOutput()
    }

    @objc private func headerMenuButtonPressed(_ sender: NSButton) {
        if shortcutPanel?.isVisible == true {
            hideShortcutPanel()
        } else {
            showShortcutPanel()
        }
    }

    @objc private func pinButtonPressed() {
        isPinned.toggle()
        if isPinned, let window {
            savePinnedOrigin(window.frame.origin)
        }
    }

    private func configureCopyButton() {
        copyButton.isBordered = false
        copyButton.imagePosition = .imageOnly
        copyButton.target = self
        copyButton.action = #selector(copyButtonPressed)
        copyButton.wantsLayer = true
        copyButton.layer?.cornerRadius = 7
        copyButton.layer?.cornerCurve = .continuous
        copyButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy output")
        updateCopyButtonTint()
    }

    private func copyOutput() {
        let output = calculator.outputText
        guard !output.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        flashCopyButton()
        window?.makeFirstResponder(keyView)
    }

    private func flashCopyButton() {
        let original = copyButton.layer?.backgroundColor
        copyButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.30).cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.copyButton.layer?.backgroundColor = original
        }
    }

    private func updateCopyButtonTint() {
        copyButton.contentTintColor = calculator.isComplete
            ? NSColor.white.withAlphaComponent(0.90)
            : NSColor.white.withAlphaComponent(0.64)
    }

    private func makeButtonPad() -> NSView {
        keyView.translatesAutoresizingMaskIntoConstraints = false

        let vertical = NSStackView()
        vertical.orientation = .vertical
        vertical.spacing = Layout.gap
        vertical.translatesAutoresizingMaskIntoConstraints = false

        let rows: [[ButtonSpec]] = [
            [.init("C", .clear, .utility), .init("+/-", .toggleSign, .utility), .init("%", .percent, .utility), .init("/", .operation(.divide), .operator)],
            [.init("7", .digit(7), .number), .init("8", .digit(8), .number), .init("9", .digit(9), .number), .init("x", .operation(.multiply), .operator)],
            [.init("4", .digit(4), .number), .init("5", .digit(5), .number), .init("6", .digit(6), .number), .init("-", .operation(.subtract), .operator)],
            [.init("1", .digit(1), .number), .init("2", .digit(2), .number), .init("3", .digit(3), .number), .init("+", .operation(.add), .operator)],
            [.init("0", .digit(0), .number, width: 2), .init(".", .decimal, .number), .init("=", .equals, .equals)]
        ]

        for row in rows {
            vertical.addArrangedSubview(makeRow(row))
        }

        keyView.addSubview(vertical)

        NSLayoutConstraint.activate([
            vertical.leadingAnchor.constraint(equalTo: keyView.leadingAnchor),
            vertical.trailingAnchor.constraint(equalTo: keyView.trailingAnchor),
            vertical.topAnchor.constraint(equalTo: keyView.topAnchor),
            vertical.bottomAnchor.constraint(equalTo: keyView.bottomAnchor),
            keyView.heightAnchor.constraint(equalToConstant: (Layout.keyHeight * 5) + (Layout.gap * 4))
        ])

        return keyView
    }

    private func makeRow(_ specs: [ButtonSpec]) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = Layout.gap
        row.distribution = .fill
        row.translatesAutoresizingMaskIntoConstraints = false

        for spec in specs {
            let button = button(spec.title, spec.action, role: spec.role)
            row.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: Layout.keyHeight).isActive = true
            let width = spec.width > 1 ? Layout.zeroWidth : Layout.keyWidth
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
        }

        return row
    }

    private func button(_ title: String, _ action: CalculatorAction, role: CalculatorButton.Role) -> CalculatorButton {
        let button = CalculatorButton(title: title, role: role)
        button.actionHandler = { [weak self] in
            self?.perform(action)
            self?.flashKey(title)
        }
        register(button, for: title)
        return button
    }

    private func register(_ button: CalculatorButton, for title: String) {
        let keys: [String]
        switch title {
        case "x": keys = ["x", "X", "*"]
        case "/": keys = ["/"]
        case "=": keys = ["=", "\r", "\n"]
        case "C": keys = ["C", "c", "clear", "escape", "delete"]
        case "+/-": keys = ["+/-"]
        default: keys = [title]
        }

        for key in keys {
            buttonsByKey[key] = button
        }
    }

    private func flashKey(_ key: String) {
        buttonsByKey[key]?.flash()
    }

    private func perform(_ action: CalculatorAction) {
        switch action {
        case let .digit(value):
            calculator.inputDigit(value)
        case .decimal:
            calculator.inputDecimalSeparator()
        case let .operation(operation):
            calculator.setOperation(operation)
        case .equals:
            calculator.equals()
        case .clear:
            calculator.clear()
        case .toggleSign:
            calculator.toggleSign()
        case .percent:
            calculator.percent()
        case .backspace:
            calculator.backspace()
        }
        window?.makeFirstResponder(keyView)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            if self.keyView.handle(event: event) {
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    private func showShortcutPanel() {
        if shortcutPanel == nil {
            shortcutPanel = makeShortcutPanel()
        }
        positionShortcutPanel()
        shortcutPanel?.orderFront(nil)
    }

    private func hideShortcutPanel() {
        shortcutPanel?.orderOut(nil)
    }

    private func positionShortcutPanel() {
        guard let window, let shortcutPanel else { return }

        let gap: CGFloat = 10
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let rightX = window.frame.maxX + gap
        let leftX = window.frame.minX - shortcutPanel.frame.width - gap
        let x = rightX + shortcutPanel.frame.width <= screenFrame.maxX - 8 ? rightX : max(screenFrame.minX + 8, leftX)
        let y = min(
            max(window.frame.maxY - shortcutPanel.frame.height, screenFrame.minY + 8),
            screenFrame.maxY - shortcutPanel.frame.height - 8
        )

        shortcutPanel.setFrameOrigin(NSPoint(x: x, y: y))
        shortcutPanel.level = window.level
    }

    private func makeShortcutPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 278, height: 272),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = makeShortcutPanelContent()
        return panel
    }

    private func makeShortcutPanelContent() -> NSView {
        let root = NSVisualEffectView()
        root.material = .underWindowBackground
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true
        root.layer?.cornerRadius = 14
        root.layer?.cornerCurve = .continuous
        root.layer?.masksToBounds = true
        root.layer?.backgroundColor = NSColor(calibratedWhite: 0.94, alpha: 0.98).cgColor
        root.layer?.borderWidth = 1
        root.layer?.borderColor = NSColor.black.withAlphaComponent(0.12).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 9
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Shortcuts")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = NSColor.black.withAlphaComponent(0.86)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(separator())

        let rows = [
            ("Open / close", "Control + Option + C"),
            ("Close panel", "Esc or ×"),
            ("Keep on top", "Pin button"),
            ("Move pinned", "Drag the panel"),
            ("Numbers", "0-9 or numeric keypad"),
            ("Operators", "+  -  x  /"),
            ("Calculate", "Enter, Return, or ="),
            ("Clear", "C or Delete")
        ]

        for (index, row) in rows.enumerated() {
            if index == 4 {
                stack.addArrangedSubview(separator())
            }
            stack.addArrangedSubview(shortcutRow(label: row.0, value: row.1))
        }

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        return root
    }

    private func shortcutRow(label: String, value: String) -> NSView {
        let labelField = NSTextField(labelWithString: "\(label):")
        labelField.font = .systemFont(ofSize: 13, weight: .semibold)
        labelField.textColor = NSColor.black.withAlphaComponent(0.74)
        labelField.translatesAutoresizingMaskIntoConstraints = false

        let valueField = NSTextField(labelWithString: value)
        valueField.font = .systemFont(ofSize: 13, weight: .regular)
        valueField.textColor = NSColor.black.withAlphaComponent(0.78)
        valueField.lineBreakMode = .byTruncatingTail
        valueField.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [labelField, valueField])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .firstBaseline
        row.translatesAutoresizingMaskIntoConstraints = false

        labelField.widthAnchor.constraint(equalToConstant: 92).isActive = true
        return row
    }

    private func separator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }

    private func updatePinnedMode() {
        window?.level = isPinned ? .floating : .statusBar
        window?.collectionBehavior = isPinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let imageName = isPinned ? "pin.fill" : "pin"
        pinButton.image = NSImage(systemSymbolName: imageName, accessibilityDescription: isPinned ? "Unpin calculator" : "Keep calculator on top")
        pinButton.contentTintColor = isPinned ? NSColor.white : NSColor.black.withAlphaComponent(0.68)
        pinButton.layer?.backgroundColor = isPinned
            ? NSColor(calibratedRed: 0.26, green: 0.40, blue: 0.72, alpha: 0.98).cgColor
            : NSColor.white.withAlphaComponent(0.40).cgColor
        pinButton.layer?.borderColor = NSColor.black.withAlphaComponent(0.10).cgColor
    }

    private func savedPinnedOrigin() -> NSPoint? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: DefaultsKey.pinnedX) != nil,
              defaults.object(forKey: DefaultsKey.pinnedY) != nil else {
            return nil
        }
        return NSPoint(
            x: defaults.double(forKey: DefaultsKey.pinnedX),
            y: defaults.double(forKey: DefaultsKey.pinnedY)
        )
    }

    private func savePinnedOrigin(_ origin: NSPoint) {
        UserDefaults.standard.set(origin.x, forKey: DefaultsKey.pinnedX)
        UserDefaults.standard.set(origin.y, forKey: DefaultsKey.pinnedY)
    }

    private func constrainedOrigin(_ origin: NSPoint, for window: NSWindow) -> NSPoint {
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        return NSPoint(
            x: min(max(origin.x, screenFrame.minX + 8), screenFrame.maxX - window.frame.width - 8),
            y: min(max(origin.y, screenFrame.minY + 8), screenFrame.maxY - window.frame.height - 8)
        )
    }
}

private final class CalculatorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class DraggableVisualEffectView: NSVisualEffectView {
    override var mouseDownCanMoveWindow: Bool { true }
}

private final class CopyableDisplayField: NSTextField {
    var onDoubleClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.clickCount == 2 {
            onDoubleClick?()
        }
    }
}

private enum DefaultsKey {
    static let isPinned = "CalcBar.isPinned"
    static let pinnedX = "CalcBar.pinnedX"
    static let pinnedY = "CalcBar.pinnedY"
}

enum ShortcutMenuFactory {
    @MainActor
    static func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(disabled("Shortcuts"))
        menu.addItem(.separator())
        menu.addItem(disabled("Open / close:  Control + Option + C"))
        menu.addItem(disabled("Close panel:  Esc or ×"))
        menu.addItem(disabled("Keep on top:  Pin button"))
        menu.addItem(disabled("Move pinned:  Drag the panel"))
        menu.addItem(.separator())
        menu.addItem(disabled("Numbers:  0-9 or numeric keypad"))
        menu.addItem(disabled("Operators:  +  -  x  /"))
        menu.addItem(disabled("Calculate:  Enter, Return, or ="))
        menu.addItem(disabled("Clear:  C or Delete"))
        return menu
    }

    @MainActor
    private static func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

private struct ButtonSpec {
    let title: String
    let action: CalculatorAction
    let role: CalculatorButton.Role
    let width: Int

    init(_ title: String, _ action: CalculatorAction, _ role: CalculatorButton.Role, width: Int = 1) {
        self.title = title
        self.action = action
        self.role = role
        self.width = width
    }
}

private enum CalculatorAction {
    case digit(Int)
    case decimal
    case operation(CalculatorEngine.Operation)
    case equals
    case clear
    case toggleSign
    case percent
    case backspace
}

private final class CalculatorKeyView: NSView {
    private let calculator: CalculatorEngine
    var onKeyboardAction: ((String) -> Void)?
    var onClose: (() -> Void)?

    init(calculator: CalculatorEngine) {
        self.calculator = calculator
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if !handle(event: event) {
            super.keyDown(with: event)
        }
    }

    func handle(event: NSEvent) -> Bool {
        if Int(event.keyCode) == kVK_Escape {
            onClose?()
            return true
        }

        if calculator.handleSpecialKey(event.keyCode) {
            onKeyboardAction?(keyName(for: event.keyCode))
            return true
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return false
        }

        guard calculator.handleKey(characters) else {
            return false
        }

        onKeyboardAction?(characters)
        return true
    }

    private func keyName(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_Keypad0:
            return "0"
        case kVK_ANSI_Keypad1:
            return "1"
        case kVK_ANSI_Keypad2:
            return "2"
        case kVK_ANSI_Keypad3:
            return "3"
        case kVK_ANSI_Keypad4:
            return "4"
        case kVK_ANSI_Keypad5:
            return "5"
        case kVK_ANSI_Keypad6:
            return "6"
        case kVK_ANSI_Keypad7:
            return "7"
        case kVK_ANSI_Keypad8:
            return "8"
        case kVK_ANSI_Keypad9:
            return "9"
        case kVK_ANSI_KeypadDecimal:
            return "."
        case kVK_ANSI_KeypadPlus:
            return "+"
        case kVK_ANSI_KeypadMinus:
            return "-"
        case kVK_ANSI_KeypadMultiply:
            return "x"
        case kVK_ANSI_KeypadDivide:
            return "/"
        case kVK_ANSI_KeypadEquals:
            return "="
        case kVK_Delete, kVK_ForwardDelete:
            return "delete"
        case kVK_Escape:
            return "escape"
        case kVK_ANSI_KeypadEnter, kVK_Return:
            return "="
        default:
            return ""
        }
    }
}

private final class CalculatorButton: NSButton {
    enum Role {
        case number
        case utility
        case `operator`
        case equals
    }

    var actionHandler: (() -> Void)?
    private let role: Role

    init(title: String, role: Role) {
        self.role = role
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        bezelStyle = .regularSquare
        font = .monospacedDigitSystemFont(ofSize: 16, weight: role == .number ? .medium : .semibold)
        target = self
        action = #selector(runAction)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = backgroundColor.cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        contentTintColor = textColor
        setButtonType(.momentaryChange)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func updateLayer() {
        layer?.backgroundColor = backgroundColor.cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    func flash() {
        guard let layer else { return }
        let original = backgroundColor.cgColor
        layer.backgroundColor = flashColor.cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            self?.layer?.backgroundColor = original
        }
    }

    @objc private func runAction() {
        actionHandler?()
    }

    private var backgroundColor: NSColor {
        switch role {
        case .number:
            NSColor(calibratedWhite: 0.23, alpha: 0.98)
        case .utility:
            NSColor(calibratedWhite: 0.32, alpha: 0.98)
        case .operator:
            NSColor(calibratedRed: 0.26, green: 0.40, blue: 0.72, alpha: 0.98)
        case .equals:
            NSColor(calibratedRed: 0.16, green: 0.58, blue: 0.44, alpha: 1)
        }
    }

    private var flashColor: NSColor {
        switch role {
        case .number, .utility:
            NSColor.white.withAlphaComponent(0.30)
        case .operator:
            NSColor(calibratedRed: 0.38, green: 0.55, blue: 0.92, alpha: 1)
        case .equals:
            NSColor(calibratedRed: 0.22, green: 0.76, blue: 0.58, alpha: 1)
        }
    }

    private var textColor: NSColor {
        switch role {
        case .number:
            .white
        case .utility:
            NSColor.white.withAlphaComponent(0.82)
        case .operator, .equals:
            .white
        }
    }
}

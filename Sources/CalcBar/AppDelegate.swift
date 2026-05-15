import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let calculator = CalculatorEngine()
    private var panelController: CalculatorPanelController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()

        let controller = CalculatorPanelController(calculator: calculator)
        controller.onQuit = { NSApp.terminate(nil) }
        panelController = controller

        hotKey = GlobalHotKey(keyCode: KeyCode.c, modifiers: [.option]) { [weak self] in
            self?.toggleCalculator()
        }
    }

    private func configureStatusItem() {
        statusItem.button?.image = NSImage(systemSymbolName: "plus.forwardslash.minus", accessibilityDescription: "Calc Bar")
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            toggleCalculator()
            return
        }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleCalculator()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Calculator", action: #selector(showCalculatorFromMenu), keyEquivalent: ""))
        menu.addItem(.separator())
        for item in ShortcutMenuFactory.makeMenu().items {
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Calc Bar", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func showCalculatorFromMenu() {
        showCalculator()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func toggleCalculator() {
        guard let panelController else { return }

        if panelController.isVisible {
            panelController.hide()
        } else {
            showCalculator()
        }
    }

    private func showCalculator() {
        guard let button = statusItem.button, let panelController else { return }
        panelController.show(relativeTo: button)
    }
}

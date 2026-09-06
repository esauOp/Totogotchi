import AppKit
import TotogotchiCore
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "app")
    private let settings = AppSettings()

    lazy var hotKeyController = HotKeyController(settings: settings)

    private var statusItem: NSStatusItem?
    private var taskStore: TaskStore?
    private var capturePanel: CapturePanelController?
    private let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        openTaskStore()
        hotKeyController.activate { [weak self] in
            self?.presentCapture(startedAt: CFAbsoluteTimeGetCurrent())
        }
    }

    // MARK: - Storage

    private func openTaskStore() {
        do {
            let url = try TaskStorageLocation.defaultStoreURL()
            let repository = try SwiftDataTaskRepository(url: url)
            let store = TaskStore(repository: repository)
            taskStore = store
            capturePanel = CapturePanelController(model: CaptureModel(store: store))

            let purged = try store.performLaunchMaintenance()
            log.info("Opened store at \(url.path, privacy: .public); purged \(purged) dead records")
        } catch {
            log.error("Could not open the task store: \(String(describing: error), privacy: .public)")
            presentStorageFailure(error)
        }
    }

    private func presentStorageFailure(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Totogotchi cannot open its task list"
        alert.informativeText = "\(error.localizedDescription)\n\nThe app will keep running, but nothing can be saved."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }

    // MARK: - Capture

    private func presentCapture(startedAt: CFAbsoluteTime) {
        guard let capturePanel else {
            log.error("Hot key fired with no capture panel available")
            return
        }
        capturePanel.present(startedAt: startedAt)
    }

    // MARK: - Status item

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "checkmark.circle",
            accessibilityDescription: "Totogotchi"
        )

        let menu = NSMenu()
        let capture = menu.addItem(
            withTitle: "Capture Task\u{2026}",
            action: #selector(captureFromMenu),
            keyEquivalent: ""
        )
        capture.target = self
        menu.addItem(.separator())
        let settingsItem = menu.addItem(
            withTitle: "Settings\u{2026}",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Totogotchi",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
        statusItem = item
    }

    @objc private func captureFromMenu() {
        presentCapture(startedAt: CFAbsoluteTimeGetCurrent())
    }

    @objc private func openSettings() {
        log.info("Opening settings")
        settingsWindow.show(controller: hotKeyController)
    }
}

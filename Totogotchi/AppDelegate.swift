import AppKit
import TotogotchiCore
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "app")
    private let settings = AppSettings()

    lazy var hotKeyController = HotKeyController(settings: settings)

    private var statusItem: NSStatusItem?
    private var toggleWidgetItem: NSMenuItem?
    private var taskStore: TaskStore?
    private var widgetModel: WidgetViewModel?
    private var widgetPanel: WidgetPanelController?
    private var capturePanel: CapturePanelController?
    private var storeObservation: TaskStoreObservation?
    private let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        openTaskStore()
        showWidgetAtLaunch()
        hotKeyController.activate { [weak self] in
            self?.presentCapture(startedAt: CFAbsoluteTimeGetCurrent())
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Every write is already synchronous, so the only thing left to keep is
        // where the user parked the widget.
        widgetPanel?.persistState()
    }

    // MARK: - Storage

    private func openTaskStore() {
        do {
            let url = try TaskStorageLocation.defaultStoreURL()
            let repository = try SwiftDataTaskRepository(url: url)
            let store = TaskStore(repository: repository)
            taskStore = store

            let model = WidgetViewModel(store: store)
            widgetModel = model
            capturePanel = CapturePanelController(model: CaptureModel(store: store))
            widgetPanel = WidgetPanelController(
                model: model,
                settings: settings,
                onOpenSettings: { [weak self] in self?.openSettings() }
            )
            storeObservation = store.observeChanges { [weak self] in
                MainActor.assumeIsolated { self?.refreshStatusItem() }
            }

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

    // MARK: - Widget

    private func showWidgetAtLaunch() {
        let launchedAt = NSRunningApplication.current.launchDate.map {
            $0.timeIntervalSinceReferenceDate
        }
        widgetPanel?.show(measuringLaunchFrom: launchedAt)
        refreshStatusItem()
    }

    @objc private func toggleWidget() {
        widgetPanel?.toggleVisibility()
        refreshStatusItem()
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

        let menu = NSMenu()
        menu.delegate = self

        let capture = menu.addItem(
            withTitle: "Capture Task\u{2026}",
            action: #selector(captureFromMenu),
            keyEquivalent: ""
        )
        capture.target = self

        let toggle = menu.addItem(
            withTitle: "Hide Widget",
            action: #selector(toggleWidget),
            keyEquivalent: ""
        )
        toggle.target = self
        toggleWidgetItem = toggle

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
        refreshStatusItem()
    }

    /// The status item carries the overdue count only while the widget is
    /// hidden. With the widget on screen the badge would just repeat what the
    /// list already says.
    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }
        let widgetHidden = !(widgetPanel?.isVisible ?? false)
        let overdue = widgetModel?.overdueCount ?? 0

        if widgetHidden, overdue > 0 {
            button.image = NSImage(
                systemSymbolName: "exclamationmark.circle.fill",
                accessibilityDescription: "Totogotchi, \(overdue) tasks overdue"
            )
            button.title = " \(overdue)"
        } else {
            button.image = NSImage(
                systemSymbolName: "pawprint.circle",
                accessibilityDescription: "Totogotchi"
            )
            button.title = ""
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleWidgetItem?.title = (widgetPanel?.isVisible ?? false) ? "Hide Widget" : "Show Widget"
    }

    @objc private func captureFromMenu() {
        presentCapture(startedAt: CFAbsoluteTimeGetCurrent())
    }

    @objc private func openSettings() {
        log.info("Opening settings")
        settingsWindow.show(controller: hotKeyController)
    }
}

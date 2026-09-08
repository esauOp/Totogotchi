import AppKit
import TotogotchiCore
import UserNotifications
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "app")
    private let settings = AppSettings()

    lazy var hotKeyController = HotKeyController(settings: settings)
    private lazy var notificationsController = NotificationsController(settings: settings)
    private lazy var launchAtLoginController = LaunchAtLoginController()
    private var transferController: DataTransferController?

    private var statusItem: NSStatusItem?
    private var toggleWidgetItem: NSMenuItem?
    private var taskStore: TaskStore?
    private var usage: UsageLog?
    private var counters: WeeklyStatsRepository?
    private var widgetModel: WidgetViewModel?
    private var widgetPanel: WidgetPanelController?
    private var capturePanel: CapturePanelController?
    private var reminders: ReminderScheduler?
    private var storeObservation: TaskStoreObservation?
    private let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        openTaskStore()
        showWidgetAtLaunch()
        // The first pass is the one that reports in summary what came due while
        // the app was closed, so it has to run before any tick.
        reminders?.evaluate()
        hotKeyController.activate { [weak self] in
            self?.presentCapture(startedAt: CFAbsoluteTimeGetCurrent())
        }
    }

    // MARK: - Notifications

    /// Show reminders even when Totogotchi is the active app, which for a
    /// menu-bar app it briefly is whenever the user touches the widget.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let raw = info[ReminderScheduler.taskIdentifierKey] as? String,
              let id = UUID(uuidString: raw)
        else {
            widgetPanel?.show()
            return
        }
        usage?.record(.notificationClicked, taskID: id)
        log.info("Opening the widget from a reminder")
        widgetPanel?.showExpanded()
        widgetModel?.selection = id
        refreshStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        usage?.record(.appQuit)
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

            // Tasks and events share one store file, so one backup carries both.
            let usageLog = UsageLog(repository: try SwiftDataUsageLogRepository(url: url))
            usage = usageLog
            usageLog.record(.appLaunched)

            let statsCounters = try SwiftDataWeeklyStatsRepository(url: url)
            counters = statsCounters
            transferController = DataTransferController(
                store: store,
                usage: usageLog,
                counters: statsCounters
            )

            let model = WidgetViewModel(
                store: store,
                settings: settings,
                usage: usageLog,
                counters: statsCounters
            )
            widgetModel = model
            let capture = CapturePanelController(model: CaptureModel(store: store, usage: usageLog))
            capture.onVisibilityChanged = { [weak model] isOpen in
                model?.isCapturing = isOpen
            }
            capturePanel = capture

            let scheduler = ReminderScheduler(store: store, settings: settings, usage: usageLog)
            reminders = scheduler
            UNUserNotificationCenter.current().delegate = self
            model.onTick = { scheduler.evaluate() }

            widgetPanel = WidgetPanelController(
                model: model,
                settings: settings,
                onOpenSettings: { [weak self] in self?.openSettings() }
            )
            storeObservation = store.observeChanges { [weak self] in
                MainActor.assumeIsolated { self?.refreshStatusItem() }
            }

            let purged = try store.performLaunchMaintenance()
            let purgedEvents = try usageLog.purgeOldEvents()
            _ = try store.purgeOldWeeklyStats(counters: statsCounters)
            log.info("Opened store at \(url.path, privacy: .public); purged \(purged) dead records and \(purgedEvents) old events")
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

    private func presentCapture(startedAt: CFAbsoluteTime, source: TaskSource = .hotkey) {
        guard let capturePanel else {
            log.error("Hot key fired with no capture panel available")
            return
        }
        usage?.record(.captureOpened)
        capturePanel.present(startedAt: startedAt, source: source)
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

        let summary = menu.addItem(
            withTitle: "This Week's Summary",
            action: #selector(showSummary),
            keyEquivalent: ""
        )
        summary.target = self

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

    @objc private func showSummary() {
        widgetPanel?.showExpanded()
        widgetModel?.showSummary()
    }

    @objc private func captureFromMenu() {
        presentCapture(startedAt: CFAbsoluteTimeGetCurrent(), source: .widget)
    }

    @objc private func openSettings() {
        log.info("Opening settings")
        guard let transferController else {
            log.error("Settings opened before the store was ready")
            return
        }
        settingsWindow.show(
            hotKeys: hotKeyController,
            notifications: notificationsController,
            transfer: transferController,
            launchAtLogin: launchAtLoginController
        )
    }
}

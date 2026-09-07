import Foundation
import TotogotchiCore
import UserNotifications
import os

/// Tells the user when a task comes due.
///
/// Posts notifications itself rather than handing the system a schedule. A
/// system-scheduled notification fires whether or not Totogotchi is running,
/// which would make the launch summary in `specs/reminders` meaningless: the
/// spec describes an app that notices on start-up that things came due while it
/// was away and says so once. Deciding in-process is the only way to get that.
///
/// Rides the widget's existing one-minute tick, so there is no second timer.
@MainActor
final class ReminderScheduler {
    /// Carried on each notification so a click can find its task again.
    static let taskIdentifierKey = "taskID"
    private static let summaryIdentifier = "totogotchi.due-summary"

    private let store: TaskStore
    private let settings: AppSettings
    private let center: UNUserNotificationCenter
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "reminders")

    /// The first pass after launch reports in summary; later passes report each
    /// task as it comes due.
    private var hasRunLaunchPass = false

    init(store: TaskStore, settings: AppSettings, center: UNUserNotificationCenter = .current()) {
        self.store = store
        self.settings = settings
        self.center = center
    }

    /// Called once at launch and then from every tick.
    func evaluate(now: Date = Date()) {
        do {
            let tasks = try store.openTasks()
            pruneRecords(against: tasks)

            let pending = tasks.filter { task in
                task.dueDate <= now && settings.notifiedDueDates[task.id.uuidString] != task.dueDate
            }
            guard !pending.isEmpty else {
                hasRunLaunchPass = true
                return
            }

            requestAuthorizationIfNeeded()

            if hasRunLaunchPass {
                for task in pending { post(for: task) }
            } else {
                postSummary(for: pending)
            }
            record(pending)
            hasRunLaunchPass = true
        } catch {
            log.error("Could not check reminders: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Posting

    private func post(for task: TaskItem) {
        guard settings.notificationsEnabled else {
            log.info("Reminders are switched off; not posting for a due task")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Task due"
        content.body = task.title
        content.userInfo = [Self.taskIdentifierKey: task.id.uuidString]
        content.sound = .default

        // A nil trigger posts immediately, which is what "within 60 seconds of
        // the due time" means when the check itself runs every minute.
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: nil)
        center.add(request) { [log] error in
            if let error {
                log.error("Could not post a reminder: \(String(describing: error), privacy: .public)")
            }
        }
        log.info("Posted a reminder for a task due at \(task.dueDate, privacy: .public)")
    }

    /// One notification for everything that came due while the app was not
    /// running, rather than a pile of them.
    private func postSummary(for tasks: [TaskItem]) {
        guard settings.notificationsEnabled else { return }

        if tasks.count == 1, let only = tasks.first {
            post(for: only)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "\(tasks.count) tasks came due"
        content.body = "They were waiting while Totogotchi was closed."
        content.sound = .default

        let request = UNNotificationRequest(identifier: Self.summaryIdentifier, content: content, trigger: nil)
        center.add(request) { [log] error in
            if let error {
                log.error("Could not post the summary: \(String(describing: error), privacy: .public)")
            }
        }
        log.info("Posted a launch summary for \(tasks.count) tasks")
    }

    // MARK: - Records

    private func record(_ tasks: [TaskItem]) {
        var records = settings.notifiedDueDates
        for task in tasks { records[task.id.uuidString] = task.dueDate }
        settings.notifiedDueDates = records
    }

    /// Drops records for tasks that no longer exist, so the dictionary does not
    /// grow without bound as tasks are completed and purged.
    private func pruneRecords(against tasks: [TaskItem]) {
        let live = Set(tasks.map(\.id.uuidString))
        let records = settings.notifiedDueDates
        let kept = records.filter { live.contains($0.key) }
        if kept.count != records.count {
            settings.notifiedDueDates = kept
            log.info("Pruned \(records.count - kept.count) stale reminder records")
        }
    }

    // MARK: - Permission

    /// Asks once, the first time there is something that could need announcing.
    ///
    /// Never caches a refusal: the user can grant permission in System Settings
    /// later and the next due task should simply work.
    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [center, log] current in
            guard current.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error {
                    log.error("Notification permission failed: \(String(describing: error), privacy: .public)")
                } else {
                    log.info("Notification permission \(granted ? "granted" : "denied", privacy: .public)")
                }
            }
        }
    }

    /// Whether macOS will currently let the app post anything.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }
}

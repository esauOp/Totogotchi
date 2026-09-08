import Foundation

/// Why a store operation failed.
public enum TaskStoreError: Error, Equatable, Sendable {
    case notFound(UUID)
}

/// The application's entry point for reading and changing tasks.
///
/// Enforces title validation, soft delete with undo, and the purge of long-dead
/// records. Time is injected so the rules can be tested without waiting.
public final class TaskStore {
    /// How long a deleted task can be restored through the user interface.
    public static let undoWindow: TimeInterval = 5
    /// How long a soft-deleted task is kept before it is purged.
    public static let retentionAfterDelete: TimeInterval = 30 * 24 * 60 * 60

    private let repository: TaskRepository
    private let week: WeekCalendar
    private let clock: () -> Date

    public init(
        repository: TaskRepository,
        week: WeekCalendar = WeekCalendar(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.week = week
        self.clock = clock
    }

    /// The calendar the store was built with, so callers derive weeks the same way.
    var weekCalendar: WeekCalendar { week }

    /// The store's notion of now.
    func currentDate() -> Date { clock() }

    // MARK: - Change notification

    /// Advances on every mutation. Useful as a cheap "did anything change" check.
    public private(set) var revision: Int = 0

    private var observers: [UUID: () -> Void] = [:]

    /// Calls `handler` after every mutation, until the returned token is released
    /// or invalidated.
    public func observeChanges(_ handler: @escaping () -> Void) -> TaskStoreObservation {
        let id = UUID()
        observers[id] = handler
        return TaskStoreObservation { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    private func recordChange() {
        revision &+= 1
        for handler in observers.values { handler() }
    }

    // MARK: - Reading

    /// Tasks that are not soft-deleted, including completed ones.
    public func activeTasks() throws -> [TaskItem] {
        try repository.fetchAll().filter { !$0.isDeleted }
    }

    /// Tasks that are neither soft-deleted nor completed.
    public func openTasks() throws -> [TaskItem] {
        try activeTasks().filter { !$0.isCompleted }
    }

    /// A task by identifier, whether or not it is deleted.
    public func task(id: UUID) throws -> TaskItem? {
        try repository.fetch(id: id)
    }

    // MARK: - Pet state

    /// How far back `streakDays(now:)` looks, so a long history cannot make the
    /// walk unbounded.
    public static let maximumStreakDays = 365

    /// Consecutive days, counting back from `now`, on which the user either
    /// completed something or had nothing due.
    ///
    /// Today never breaks the streak while it is still in progress: work due
    /// today that has not been done yet has not failed yet.
    ///
    /// Counting stops at the day the user's first task was created. Without that
    /// floor every day before the app existed would count as "nothing was due",
    /// and an empty store would report a year-long streak.
    public func streakDays(now: Date? = nil) throws -> Int {
        let moment = now ?? clock()
        let tasks = try activeTasks()
        guard let firstDay = tasks.map({ week.startOfDay(for: $0.createdAt) }).min() else {
            return 0
        }

        var completionDays: Set<Date> = []
        var dueDays: Set<Date> = []
        for task in tasks {
            if let completedAt = task.completedAt {
                completionDays.insert(week.startOfDay(for: completedAt))
            }
            dueDays.insert(week.startOfDay(for: task.dueDate))
        }

        let today = week.startOfDay(for: moment)
        var day = today
        var streak = 0

        for _ in 0..<Self.maximumStreakDays {
            if day < firstDay { break }
            let kept = completionDays.contains(day) || !dueDays.contains(day)
            if kept {
                streak += 1
            } else if day != today {
                break
            }
            day = week.dayBefore(day)
        }
        return streak
    }

    /// The pet's current state.
    ///
    /// Derived on demand rather than stored, so it can never drift from the
    /// tasks it describes.
    public func petState(now: Date? = nil) throws -> PetState {
        let moment = now ?? clock()
        return MoodEngine.evaluate(
            weekView: try weekView(now: moment),
            streakDays: try streakDays(now: moment)
        )
    }

    // MARK: - Writing

    /// Creates a task. Priority defaults to medium and the due date to the end of
    /// the current ISO week.
    @discardableResult
    public func create(
        title: String,
        notes: String? = nil,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        recurrence: Recurrence = .none
    ) throws -> TaskItem {
        let now = clock()
        let task = try TaskItem(
            title: title,
            notes: notes,
            priority: priority,
            dueDate: dueDate ?? week.defaultDueDate(now: now),
            createdAt: now,
            recurrence: recurrence
        )
        try repository.upsert(task)
        recordChange()
        return task
    }

    /// Reads capture text without creating anything, for the live preview beside
    /// the field. Uses the store's own calendar and clock so the preview cannot
    /// disagree with what pressing Enter will do.
    public func parseCapture(_ text: String) -> ParsedCapture {
        CaptureTokens.parse(text, now: clock(), calendar: week)
    }

    /// Creates a task from a line of capture text, applying any tokens in it.
    @discardableResult
    public func createFromCapture(_ text: String) throws -> TaskItem {
        let parsed = parseCapture(text)
        return try create(
            title: parsed.title,
            priority: parsed.priority ?? .medium,
            dueDate: parsed.dueDate
        )
    }

    @discardableResult
    public func rename(_ id: UUID, to newTitle: String) throws -> TaskItem {
        var task = try require(id)
        try task.rename(to: newTitle)
        try repository.upsert(task)
        recordChange()
        return task
    }

    @discardableResult
    public func complete(_ id: UUID) throws -> TaskItem {
        let now = clock()
        var task = try require(id)
        task.markCompleted(at: now, now: now)
        try repository.upsert(task)
        recordChange()
        return task
    }

    @discardableResult
    public func uncomplete(_ id: UUID) throws -> TaskItem {
        var task = try require(id)
        task.markIncomplete()
        try repository.upsert(task)
        recordChange()
        return task
    }

    /// Soft-deletes a task. It disappears from queries but keeps every field, so
    /// `undoDelete(_:)` restores it exactly.
    public func delete(_ id: UUID) throws {
        var task = try require(id)
        task.markDeleted(at: clock())
        try repository.upsert(task)
        recordChange()
    }

    @discardableResult
    public func undoDelete(_ id: UUID) throws -> TaskItem {
        var task = try require(id)
        task.restore()
        try repository.upsert(task)
        recordChange()
        return task
    }

    /// Permanently removes tasks deleted longer ago than the retention window.
    /// Returns how many were removed.
    @discardableResult
    public func purgeDeleted() throws -> Int {
        let cutoff = clock().addingTimeInterval(-Self.retentionAfterDelete)
        let expired = try repository.fetchAll()
            .filter { task in
                guard let deletedAt = task.deletedAt else { return false }
                return deletedAt < cutoff
            }
            .map(\.id)
        guard !expired.isEmpty else { return 0 }
        try repository.remove(ids: expired)
        recordChange()
        return expired.count
    }

    /// Housekeeping the app runs once at launch. Returns how many dead records
    /// were purged.
    @discardableResult
    public func performLaunchMaintenance() throws -> Int {
        try purgeDeleted()
    }

    // MARK: - Archive support

    /// Every stored task, soft-deleted ones included, so an export can restore
    /// the store exactly as it stood.
    func allTasksForExport() throws -> [TaskItem] {
        try repository.fetchAll().sorted { $0.createdAt < $1.createdAt }
    }

    /// Writes a task verbatim, without touching timestamps or validation.
    func replace(_ task: TaskItem) throws {
        try repository.upsert(task)
        recordChange()
    }

    var exportClock: () -> Date { clock }

    /// Test hooks for the archive helpers, which are internal to the module.
    public func replaceForTesting(_ task: TaskItem) throws { try replace(task) }
    public func allTasksForExportTesting() throws -> [TaskItem] { try allTasksForExport() }

    private func require(_ id: UUID) throws -> TaskItem {
        guard let task = try repository.fetch(id: id) else {
            throw TaskStoreError.notFound(id)
        }
        return task
    }
}

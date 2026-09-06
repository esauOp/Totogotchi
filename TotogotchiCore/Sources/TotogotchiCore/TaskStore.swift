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
        return task
    }

    @discardableResult
    public func rename(_ id: UUID, to newTitle: String) throws -> TaskItem {
        var task = try require(id)
        try task.rename(to: newTitle)
        try repository.upsert(task)
        return task
    }

    @discardableResult
    public func complete(_ id: UUID) throws -> TaskItem {
        let now = clock()
        var task = try require(id)
        task.markCompleted(at: now, now: now)
        try repository.upsert(task)
        return task
    }

    @discardableResult
    public func uncomplete(_ id: UUID) throws -> TaskItem {
        var task = try require(id)
        task.markIncomplete()
        try repository.upsert(task)
        return task
    }

    /// Soft-deletes a task. It disappears from queries but keeps every field, so
    /// `undoDelete(_:)` restores it exactly.
    public func delete(_ id: UUID) throws {
        var task = try require(id)
        task.markDeleted(at: clock())
        try repository.upsert(task)
    }

    @discardableResult
    public func undoDelete(_ id: UUID) throws -> TaskItem {
        var task = try require(id)
        task.restore()
        try repository.upsert(task)
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

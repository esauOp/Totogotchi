import Foundation

/// A single thing the user intends to do.
///
/// Named `TaskItem` rather than `Task` to avoid colliding with Swift
/// concurrency's `Task`.
public struct TaskItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public private(set) var title: String
    public var notes: String?
    public var priority: Priority
    public var dueDate: Date
    public let createdAt: Date
    public private(set) var completedAt: Date?
    public var recurrence: Recurrence
    public private(set) var deletedAt: Date?

    /// Creates a task, validating the title.
    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        priority: Priority = .medium,
        dueDate: Date,
        createdAt: Date,
        completedAt: Date? = nil,
        recurrence: Recurrence = .none,
        deletedAt: Date? = nil
    ) throws {
        self.id = id
        self.title = try TaskTitle.validated(title)
        self.notes = notes
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.recurrence = recurrence
        self.deletedAt = deletedAt
    }

    /// Rebuilds a task from storage without re-running title validation.
    ///
    /// Every title reaches storage through the throwing initializer above, so it
    /// was already trimmed and length-checked. Re-validating on read would let a
    /// single unexpected row make the whole store unreadable.
    init(
        rehydratedID id: UUID,
        title: String,
        notes: String?,
        priority: Priority,
        dueDate: Date,
        createdAt: Date,
        completedAt: Date?,
        recurrence: Recurrence,
        deletedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.recurrence = recurrence
        self.deletedAt = deletedAt
    }

    public var isCompleted: Bool { completedAt != nil }
    public var isDeleted: Bool { deletedAt != nil }

    /// A task is overdue when its due date has passed and it is neither done nor deleted.
    public func isOverdue(now: Date) -> Bool {
        !isCompleted && !isDeleted && dueDate < now
    }

    /// Replaces the title, validating it first.
    public mutating func rename(to newTitle: String) throws {
        title = try TaskTitle.validated(newTitle)
    }

    /// Marks the task complete. The timestamp never lies in the future: a date
    /// later than `now` is clamped to `now`.
    public mutating func markCompleted(at date: Date, now: Date) {
        completedAt = min(date, now)
    }

    public mutating func markIncomplete() {
        completedAt = nil
    }

    public mutating func markDeleted(at date: Date) {
        deletedAt = date
    }

    public mutating func restore() {
        deletedAt = nil
    }
}

import Foundation
import SwiftData

/// The stored shape of a task.
///
/// Kept separate from `TaskItem` so the domain stays a plain value type with no
/// SwiftData dependency, and so a schema change does not ripple into the rules.
/// Enums are held as their raw strings rather than as codable values: the column
/// stays readable and a future migration can rename a case without rewriting
/// binary blobs.
@Model
final class TaskRecord {
    // `#Unique` and `#Index` both need macOS 15; the deployment target is 14,
    // so uniqueness uses the attribute form and there are no explicit indexes.
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var priorityRaw: String = Priority.medium.rawValue
    var dueDate: Date = Date.distantFuture
    var createdAt: Date = Date.distantPast
    var completedAt: Date?
    var recurrenceRaw: String = Recurrence.none.rawValue
    var deletedAt: Date?

    init(_ task: TaskItem) {
        id = task.id
        apply(task)
    }

    /// Overwrites every mutable column from the domain value.
    func apply(_ task: TaskItem) {
        title = task.title
        notes = task.notes
        priorityRaw = task.priority.rawValue
        dueDate = task.dueDate
        createdAt = task.createdAt
        completedAt = task.completedAt
        recurrenceRaw = task.recurrence.rawValue
        deletedAt = task.deletedAt
    }

    /// Unknown raw values fall back to the defaults rather than failing the read,
    /// so one odd row cannot make the store unreadable.
    var taskItem: TaskItem {
        TaskItem(
            rehydratedID: id,
            title: title,
            notes: notes,
            priority: Priority(rawValue: priorityRaw) ?? .medium,
            dueDate: dueDate,
            createdAt: createdAt,
            completedAt: completedAt,
            recurrence: Recurrence(rawValue: recurrenceRaw) ?? .none,
            deletedAt: deletedAt
        )
    }
}

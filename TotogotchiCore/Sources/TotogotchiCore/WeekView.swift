import Foundation

/// The tasks that matter right now, split into the groups the widget shows.
///
/// Every group arrives sorted, so a view renders it as given.
public struct WeekView: Equatable, Sendable {
    /// The ISO week this view describes.
    public let week: ISOWeek
    /// Not completed and past due, oldest first. Takes precedence over `thisWeek`.
    public let overdue: [TaskItem]
    /// Not completed and due later in this ISO week.
    public let thisWeek: [TaskItem]
    /// Completed during this ISO week, most recently completed first.
    public let completed: [TaskItem]

    public init(week: ISOWeek, overdue: [TaskItem], thisWeek: [TaskItem], completed: [TaskItem]) {
        self.week = week
        self.overdue = overdue
        self.thisWeek = thisWeek
        self.completed = completed
    }

    public var overdueCount: Int { overdue.count }
    public var completedCount: Int { completed.count }
    public var openCount: Int { overdue.count + thisWeek.count }
    public var isEmpty: Bool { overdue.isEmpty && thisWeek.isEmpty && completed.isEmpty }

    /// Share of this week's work that is done, used later by the pet. Zero when
    /// nothing was due.
    public var completionRate: Double {
        let total = openCount + completedCount
        guard total > 0 else { return 0 }
        return Double(completedCount) / Double(total)
    }
}

extension TaskStore {
    /// Builds the week view for `now`, defaulting to the store's clock.
    ///
    /// A task due earlier than `now` is overdue even when its due date still
    /// falls inside this week, so the two open groups never overlap.
    public func weekView(now: Date? = nil) throws -> WeekView {
        let moment = now ?? currentDate()
        let tasks = try activeTasks()

        var overdue: [TaskItem] = []
        var thisWeek: [TaskItem] = []
        var completed: [TaskItem] = []

        for task in tasks {
            if task.isCompleted {
                if let completedAt = task.completedAt, weekCalendar.contains(completedAt, weekOf: moment) {
                    completed.append(task)
                }
            } else if task.dueDate < moment {
                overdue.append(task)
            } else if weekCalendar.contains(task.dueDate, weekOf: moment) {
                thisWeek.append(task)
            }
        }

        return WeekView(
            week: weekCalendar.isoWeek(of: moment),
            overdue: overdue.sorted(by: WeekView.byDueDateThenPriority),
            thisWeek: thisWeek.sorted(by: WeekView.byDueDateThenPriority),
            completed: completed.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        )
    }
}

extension WeekView {
    /// Due date ascending, then high before medium before low. Ties break on the
    /// identifier so the order never flickers between reads.
    static func byDueDateThenPriority(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.dueDate != rhs.dueDate { return lhs.dueDate < rhs.dueDate }
        if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

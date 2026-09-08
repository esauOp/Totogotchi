import Foundation

/// How one ISO week went.
///
/// `due` and `completed` are recomputed from the tasks themselves, because they
/// are derivable and recomputing keeps them honest. `deleted` and `deferred`
/// cannot be: a deleted task is purged after thirty days, and a task moved out of
/// a week leaves no trace in that week once its due date has changed. Those two
/// are counted as they happen, which is also why they are the ones that can
/// drift, and why both appear in the summary where a wrong number would be seen.
public struct WeeklyStats: Equatable, Codable, Sendable {
    public let week: ISOWeek
    public var due: Int
    public var completed: Int
    public var deleted: Int
    public var deferred: Int

    public init(week: ISOWeek, due: Int = 0, completed: Int = 0, deleted: Int = 0, deferred: Int = 0) {
        self.week = week
        self.due = due
        self.completed = completed
        self.deleted = deleted
        self.deferred = deferred
    }

    /// Share of the week's work that got done. Zero when nothing was due.
    public var completionRate: Double {
        let total = due + completed
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    /// The guardrail from PRD §8: work that left the week rather than getting
    /// done. A completion rate that rises while this rises with it is the metric
    /// being gamed, not the habit improving.
    public var slippedRate: Double {
        let total = due + completed
        guard total > 0 else { return 0 }
        return Double(deleted + deferred) / Double(total)
    }

    public var isEmpty: Bool { due == 0 && completed == 0 && deleted == 0 && deferred == 0 }
}

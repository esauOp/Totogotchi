import Foundation

/// Where the counts that cannot be recomputed are kept.
public protocol WeeklyStatsRepository: AnyObject {
    /// The accumulated deleted and deferred counts for a week, if any.
    func counters(for week: ISOWeek) throws -> (deleted: Int, deferred: Int)?
    func setCounters(deleted: Int, deferred: Int, for week: ISOWeek) throws
    /// Every week with recorded counters, oldest first.
    func allWeeks() throws -> [ISOWeek]
    @discardableResult
    func purge(before week: ISOWeek) throws -> Int
}

public final class InMemoryWeeklyStatsRepository: WeeklyStatsRepository {
    private var storage: [ISOWeek: (deleted: Int, deferred: Int)] = [:]

    public init() {}

    public func counters(for week: ISOWeek) throws -> (deleted: Int, deferred: Int)? {
        storage[week]
    }

    public func setCounters(deleted: Int, deferred: Int, for week: ISOWeek) throws {
        storage[week] = (deleted, deferred)
    }

    public func allWeeks() throws -> [ISOWeek] {
        storage.keys.sorted()
    }

    @discardableResult
    public func purge(before week: ISOWeek) throws -> Int {
        let doomed = storage.keys.filter { $0 < week }
        for key in doomed { storage.removeValue(forKey: key) }
        return doomed.count
    }
}

extension TaskStore {
    /// How many weeks of statistics are kept. The spec asks for at least 52.
    public static let weeklyStatsRetentionWeeks = 104

    /// The full picture for a week: counts recomputed from tasks, plus the two
    /// that had to be recorded when they happened.
    public func weeklyStats(
        for week: ISOWeek? = nil,
        now: Date? = nil,
        counters: WeeklyStatsRepository
    ) throws -> WeeklyStats {
        let moment = now ?? currentDate()
        let currentWeek = weekCalendar.isoWeek(of: moment)
        let target = week ?? currentWeek

        let due: Int
        let completed: Int
        if target == currentWeek {
            // The current week uses exactly what the widget is showing, so the
            // summary can never disagree with the list above it.
            let view = try weekView(now: moment)
            due = view.openCount
            completed = view.completedCount
        } else {
            let tasks = try activeTasks()
            due = tasks.filter { !$0.isCompleted && weekCalendar.isoWeek(of: $0.dueDate) == target }.count
            completed = tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return weekCalendar.isoWeek(of: completedAt) == target
            }.count
        }

        let recorded = try counters.counters(for: target) ?? (deleted: 0, deferred: 0)
        return WeeklyStats(
            week: target,
            due: due,
            completed: completed,
            deleted: recorded.deleted,
            deferred: recorded.deferred
        )
    }

    /// Records that a task left a week without being done.
    public func recordSlip(
        _ kind: SlipKind,
        inWeekOf date: Date,
        counters: WeeklyStatsRepository
    ) throws {
        let week = weekCalendar.isoWeek(of: date)
        var current = try counters.counters(for: week) ?? (deleted: 0, deferred: 0)
        switch kind {
        case .deleted: current.deleted += 1
        case .deferred: current.deferred += 1
        }
        try counters.setCounters(deleted: current.deleted, deferred: current.deferred, for: week)
    }

    /// Drops statistics older than the retention window.
    @discardableResult
    public func purgeOldWeeklyStats(now: Date? = nil, counters: WeeklyStatsRepository) throws -> Int {
        let moment = now ?? currentDate()
        let cutoffDate = moment.addingTimeInterval(-Double(Self.weeklyStatsRetentionWeeks) * 7 * 86_400)
        return try counters.purge(before: weekCalendar.isoWeek(of: cutoffDate))
    }
}

/// The two ways work leaves a week without being finished.
public enum SlipKind: String, Sendable {
    case deleted
    case deferred
}

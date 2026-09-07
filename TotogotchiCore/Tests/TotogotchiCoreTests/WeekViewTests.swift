import Foundation
import Testing
import TotogotchiCore

@Suite("WeekView")
struct WeekViewTests {

    /// Wednesday of ISO week 2026-W37, which runs Mon 7 Sep to Sun 13 Sep.
    private let now = makeDate(2026, 9, 9, 10, 0)

    private func task(
        _ title: String,
        due: Date,
        priority: Priority = .medium,
        completedAt: Date? = nil
    ) throws -> TaskItem {
        var task = try TaskItem(title: title, priority: priority, dueDate: due, createdAt: now)
        if let completedAt { task.markCompleted(at: completedAt, now: completedAt) }
        return task
    }

    private func view(_ tasks: [TaskItem]) throws -> WeekView {
        let (store, _, _) = makeStore(now: now)
        for task in tasks { try store.replaceForTesting(task) }
        return try store.weekView()
    }

    @Test("A task due after this week ends is not listed")
    func nextWeekExcluded() throws {
        let result = try view([try task("Next Monday", due: makeDate(2026, 9, 14, 9, 0))])
        #expect(result.isEmpty)
    }

    @Test("A task still open from a previous week shows as overdue")
    func previousWeekOverdue() throws {
        let result = try view([try task("Two weeks ago", due: makeDate(2026, 8, 26, 9, 0))])
        #expect(result.overdue.map(\.title) == ["Two weeks ago"])
        #expect(result.thisWeek.isEmpty)
    }

    @Test("A task due later this week is listed under this week")
    func laterThisWeek() throws {
        let result = try view([try task("Friday", due: makeDate(2026, 9, 11, 17, 0))])
        #expect(result.thisWeek.map(\.title) == ["Friday"])
        #expect(result.overdue.isEmpty)
    }

    @Test("A task due exactly now is this week, not overdue")
    func dueExactlyNow() throws {
        let result = try view([try task("Right now", due: now)])
        #expect(result.thisWeek.map(\.title) == ["Right now"])
        #expect(result.overdue.isEmpty)
    }

    @Test("A task due earlier today is overdue even though it belongs to this week")
    func overdueBeatsThisWeek() throws {
        let result = try view([try task("This morning", due: makeDate(2026, 9, 9, 8, 0))])
        #expect(result.overdue.map(\.title) == ["This morning"])
        #expect(result.thisWeek.isEmpty)
    }

    @Test("Groups are sorted by due date, then high before medium before low")
    func sortOrder() throws {
        let friday = makeDate(2026, 9, 11, 17, 0)
        let result = try view([
            try task("Low Friday", due: friday, priority: .low),
            try task("High Friday", due: friday, priority: .high),
            try task("Medium Friday", due: friday, priority: .medium),
            try task("Thursday", due: makeDate(2026, 9, 10, 9, 0), priority: .low),
        ])
        #expect(result.thisWeek.map(\.title) == ["Thursday", "High Friday", "Medium Friday", "Low Friday"])
    }

    @Test("Only tasks completed during this week are counted as completed")
    func completedThisWeekOnly() throws {
        let result = try view([
            try task("Done Monday", due: makeDate(2026, 9, 7, 9, 0), completedAt: makeDate(2026, 9, 7, 12, 0)),
            try task("Done last week", due: makeDate(2026, 9, 4, 9, 0), completedAt: makeDate(2026, 9, 4, 12, 0)),
        ])
        #expect(result.completed.map(\.title) == ["Done Monday"])
        #expect(result.overdue.isEmpty)
    }

    @Test("Completed tasks are listed most recently finished first")
    func completedOrder() throws {
        let result = try view([
            try task("Earlier", due: now, completedAt: makeDate(2026, 9, 8, 9, 0)),
            try task("Later", due: now, completedAt: makeDate(2026, 9, 9, 9, 0)),
        ])
        #expect(result.completed.map(\.title) == ["Later", "Earlier"])
    }

    @Test("Deleted tasks never appear in any group")
    func deletedExcluded() throws {
        let (store, _, _) = makeStore(now: now)
        let doomed = try store.create(title: "Deleted", dueDate: makeDate(2026, 9, 11, 9, 0))
        try store.delete(doomed.id)
        #expect(try store.weekView().isEmpty)
    }

    @Test("The view reports the ISO week it describes")
    func reportsWeek() throws {
        #expect(try view([]).week == ISOWeek(year: 2026, week: 37))
    }

    @Test("Completion rate counts open and completed work for this week")
    func completionRate() throws {
        let empty = try view([])
        #expect(empty.completionRate == 0)

        let result = try view([
            try task("Open", due: makeDate(2026, 9, 11, 9, 0)),
            try task("Done", due: now, completedAt: makeDate(2026, 9, 8, 9, 0)),
        ])
        #expect(result.completionRate == 0.5)
        #expect(result.openCount == 1)
        #expect(result.completedCount == 1)
    }

    @Test("Crossing into Monday moves unfinished work to overdue")
    func weekRollover() throws {
        let tasks = [try task("Friday", due: makeDate(2026, 9, 11, 17, 0))]
        let (store, clock, _) = makeStore(now: now)
        for task in tasks { try store.replaceForTesting(task) }

        #expect(try store.weekView().thisWeek.count == 1)

        // One minute past Sunday 23:59:59, so the next ISO week has begun.
        clock.now = makeDate(2026, 9, 14, 0, 1)
        let after = try store.weekView()
        #expect(after.week == ISOWeek(year: 2026, week: 38))
        #expect(after.overdue.map(\.title) == ["Friday"])
        #expect(after.thisWeek.isEmpty)
    }
}

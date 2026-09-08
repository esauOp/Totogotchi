import Foundation
import Testing
import TotogotchiCore

@Suite("WeeklyStats")
struct WeeklyStatsTests {

    /// Wednesday of ISO week 2026-W37.
    private let now = makeDate(2026, 9, 9, 10, 0)
    private let thisWeek = ISOWeek(year: 2026, week: 37)
    private let lastWeek = ISOWeek(year: 2026, week: 36)

    private func setUp() -> (TaskStore, TestClock, InMemoryWeeklyStatsRepository) {
        let (store, clock, _) = makeStore(now: now)
        return (store, clock, InMemoryWeeklyStatsRepository())
    }

    private func add(
        _ store: TaskStore,
        due: Date,
        completedAt: Date? = nil
    ) throws {
        var task = try TaskItem(
            title: "Task \(UUID().uuidString.prefix(4))",
            dueDate: due,
            createdAt: now.addingTimeInterval(-86_400 * 30)
        )
        if let completedAt { task.markCompleted(at: completedAt, now: completedAt) }
        try store.replaceForTesting(task)
    }

    // MARK: - Recomputed counts

    @Test("The current week's counts match what the widget shows")
    func currentWeekMatchesWidget() throws {
        let (store, _, counters) = setUp()
        try add(store, due: makeDate(2026, 9, 11, 17, 0))
        try add(store, due: makeDate(2026, 9, 12, 17, 0))
        try add(store, due: makeDate(2026, 9, 8, 17, 0), completedAt: makeDate(2026, 9, 8, 18, 0))

        let stats = try store.weeklyStats(now: now, counters: counters)
        let view = try store.weekView(now: now)

        #expect(stats.week == thisWeek)
        #expect(stats.due == view.openCount)
        #expect(stats.completed == view.completedCount)
        #expect(stats.due == 2)
        #expect(stats.completed == 1)
    }

    @Test("A past week counts what was due and done in it")
    func pastWeek() throws {
        let (store, _, counters) = setUp()
        // Due last week, still open.
        try add(store, due: makeDate(2026, 9, 3, 17, 0))
        // Completed last week.
        try add(store, due: makeDate(2026, 9, 2, 17, 0), completedAt: makeDate(2026, 9, 2, 18, 0))
        // This week, should not count towards last week.
        try add(store, due: makeDate(2026, 9, 11, 17, 0))

        let stats = try store.weeklyStats(for: lastWeek, now: now, counters: counters)
        #expect(stats.due == 1)
        #expect(stats.completed == 1)
    }

    @Test("A week with nothing in it is empty and has no rate")
    func emptyWeek() throws {
        let (store, _, counters) = setUp()
        let stats = try store.weeklyStats(now: now, counters: counters)
        #expect(stats.isEmpty)
        #expect(stats.completionRate == 0)
        #expect(stats.slippedRate == 0)
    }

    // MARK: - Accumulated counts

    @Test("Deleting and deferring accumulate against the week they happened in")
    func slipsAccumulate() throws {
        let (store, _, counters) = setUp()
        try store.recordSlip(.deleted, inWeekOf: now, counters: counters)
        try store.recordSlip(.deferred, inWeekOf: now, counters: counters)
        try store.recordSlip(.deferred, inWeekOf: now, counters: counters)

        let stats = try store.weeklyStats(now: now, counters: counters)
        #expect(stats.deleted == 1)
        #expect(stats.deferred == 2)
    }

    @Test("A slip is recorded against its own week, not the current one")
    func slipsLandInTheRightWeek() throws {
        let (store, _, counters) = setUp()
        try store.recordSlip(.deferred, inWeekOf: makeDate(2026, 9, 2, 12, 0), counters: counters)

        #expect(try store.weeklyStats(for: lastWeek, now: now, counters: counters).deferred == 1)
        #expect(try store.weeklyStats(for: thisWeek, now: now, counters: counters).deferred == 0)
    }

    // MARK: - Rates

    @Test("The completion rate is completed over everything the week held")
    func completionRate() throws {
        let stats = WeeklyStats(week: thisWeek, due: 1, completed: 7, deleted: 1, deferred: 0)
        #expect(stats.completed == 7)
        #expect(abs(stats.completionRate - 0.875) < 0.0001)
    }

    @Test("The guardrail rate counts work that left the week unfinished")
    func slippedRate() throws {
        // Eight tasks: seven done, one deleted rather than done.
        let stats = WeeklyStats(week: thisWeek, due: 1, completed: 7, deleted: 1, deferred: 0)
        #expect(abs(stats.slippedRate - 0.125) < 0.0001)
    }

    @Test("A perfect completion rate built on deferrals shows in the guardrail")
    func gamedWeekIsVisible() throws {
        // Everything due was either done or pushed to next week: the completion
        // rate looks perfect and the guardrail says why.
        let stats = WeeklyStats(week: thisWeek, due: 0, completed: 10, deleted: 0, deferred: 5)
        #expect(stats.completionRate == 1.0)
        #expect(stats.slippedRate == 0.5)
    }

    // MARK: - Retention

    @Test("Statistics older than the retention window are dropped")
    func retention() throws {
        let (store, _, counters) = setUp()
        try store.recordSlip(.deleted, inWeekOf: now, counters: counters)
        // Three years back, well past the window.
        try store.recordSlip(.deleted, inWeekOf: makeDate(2023, 9, 6, 12, 0), counters: counters)

        #expect(try counters.allWeeks().count == 2)
        #expect(try store.purgeOldWeeklyStats(now: now, counters: counters) == 1)
        #expect(try counters.allWeeks() == [thisWeek])
    }

    @Test("At least 52 weeks are kept")
    func keepsAYear() throws {
        let (store, _, counters) = setUp()
        // A year ago exactly, which must survive.
        try store.recordSlip(.deleted, inWeekOf: now.addingTimeInterval(-52 * 7 * 86_400), counters: counters)
        #expect(try store.purgeOldWeeklyStats(now: now, counters: counters) == 0)
        #expect(TaskStore.weeklyStatsRetentionWeeks >= 52)
    }
}

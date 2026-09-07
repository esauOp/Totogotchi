import Foundation
import Testing
import TotogotchiCore

@Suite("Streak")
struct StreakTests {

    /// Wednesday of ISO week 2026-W37.
    private let now = makeDate(2026, 9, 9, 18, 0)

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        makeDate(2026, 9, 9 + offset, hour, 0)
    }

    /// Seeds a store whose tasks were all created a fortnight ago, so the
    /// creation floor never interferes with what a test is actually checking.
    private func store() -> (TaskStore, TestClock) {
        let (store, clock, _) = makeStore(now: now)
        return (store, clock)
    }

    private func add(
        _ store: TaskStore,
        due: Date,
        completedAt: Date? = nil,
        createdAt: Date? = nil
    ) throws {
        var task = try TaskItem(
            title: "Task \(UUID().uuidString.prefix(4))",
            dueDate: due,
            createdAt: createdAt ?? day(-14)
        )
        if let completedAt { task.markCompleted(at: completedAt, now: completedAt) }
        try store.replaceForTesting(task)
    }

    @Test("An empty store has no streak")
    func emptyStore() throws {
        let (store, _) = store()
        #expect(try store.streakDays(now: now) == 0)
    }

    @Test("Three days of completions in a row count three")
    func unbrokenRun() throws {
        let (store, _) = store()
        for offset in [0, -1, -2] {
            try add(store, due: day(offset), completedAt: day(offset))
        }
        // The day before the run had a task due and nothing done, which ends it.
        try add(store, due: day(-3))
        #expect(try store.streakDays(now: now) == 3)
    }

    @Test("A day with nothing due keeps the streak alive")
    func emptyDayCounts() throws {
        let (store, _) = store()
        try add(store, due: day(0), completedAt: day(0))
        // Nothing at all on day -1.
        try add(store, due: day(-2), completedAt: day(-2))
        try add(store, due: day(-3))
        #expect(try store.streakDays(now: now) == 3)
    }

    @Test("A finished day with work left undone ends the streak")
    func breakOnMissedDay() throws {
        let (store, _) = store()
        try add(store, due: day(0), completedAt: day(0))
        try add(store, due: day(-1))
        try add(store, due: day(-2), completedAt: day(-2))
        #expect(try store.streakDays(now: now) == 1)
    }

    @Test("Today does not break the streak while it is still in progress")
    func todayInProgress() throws {
        let (store, _) = store()
        // Due today, not done yet.
        try add(store, due: day(0))
        try add(store, due: day(-1), completedAt: day(-1))
        try add(store, due: day(-2), completedAt: day(-2))
        try add(store, due: day(-3))

        // Today is skipped rather than counted or held against the user.
        #expect(try store.streakDays(now: now) == 2)
    }

    @Test("Completing today's work adds today to the streak")
    func todayCompleted() throws {
        let (store, _) = store()
        try add(store, due: day(0), completedAt: day(0))
        try add(store, due: day(-1), completedAt: day(-1))
        try add(store, due: day(-2))
        #expect(try store.streakDays(now: now) == 2)
    }

    @Test("The streak cannot start before the first task existed")
    func firstTaskIsTheFloor() throws {
        let (store, _) = store()
        // Created and completed today. Every earlier day had nothing due, but
        // those days predate the user's history and must not count.
        try add(store, due: day(0), completedAt: day(0), createdAt: day(0))
        #expect(try store.streakDays(now: now) == 1)
    }

    @Test("Deleted tasks neither extend nor break a streak")
    func deletedTasksIgnored() throws {
        let (store, _) = store()
        try add(store, due: day(0), completedAt: day(0))
        let doomed = try store.create(title: "Doomed", dueDate: day(-1))
        try store.delete(doomed.id)
        try add(store, due: day(-2), completedAt: day(-2))
        try add(store, due: day(-3))

        // Day -1 has no live task due, so it counts as an empty day.
        #expect(try store.streakDays(now: now) == 3)
    }

    @Test("Walking back is capped at a year")
    func cappedAtAYear() throws {
        let (store, _) = store()
        // One task created two years ago and completed then; every day since had
        // nothing due, so without a cap this would run for 700-odd days.
        try add(store, due: makeDate(2024, 9, 9), completedAt: makeDate(2024, 9, 9), createdAt: makeDate(2024, 9, 9))
        #expect(try store.streakDays(now: now) == TaskStore.maximumStreakDays)
    }

    @Test("The pet state combines the week view and the streak")
    func petStateCombinesBoth() throws {
        let (store, _) = store()
        try add(store, due: day(-5))
        try add(store, due: day(-6))
        try add(store, due: day(-7))

        let state = try store.petState(now: now)
        #expect(state.mood == .sad)
        #expect(state.overdueCount == 3)
    }
}

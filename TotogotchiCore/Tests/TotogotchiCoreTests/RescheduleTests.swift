import Foundation
import Testing
import TotogotchiCore

@Suite("Rescheduling and deferral")
struct RescheduleTests {

    /// Wednesday of ISO week 2026-W37.
    private let now = makeDate(2026, 9, 9, 10, 0)
    private let thisWeek = ISOWeek(year: 2026, week: 37)
    private let nextWeek = ISOWeek(year: 2026, week: 38)

    @Test("Moving a task into a later week counts as a deferral")
    func moveToLaterWeekDefers() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.create(title: "Friday work", dueDate: makeDate(2026, 9, 11, 17, 0))

        let result = try store.reschedule(task.id, to: makeDate(2026, 9, 15, 17, 0))

        #expect(result.task.dueDate == makeDate(2026, 9, 15, 17, 0))
        #expect(result.deferredFrom == makeDate(2026, 9, 11, 17, 0))
    }

    @Test("Moving within the same week is not a deferral")
    func moveWithinWeekDoesNotDefer() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.create(title: "Thursday work", dueDate: makeDate(2026, 9, 10, 17, 0))

        let result = try store.reschedule(task.id, to: makeDate(2026, 9, 12, 17, 0))
        #expect(result.deferredFrom == nil)
    }

    @Test("Pulling a task earlier is not a deferral")
    func movingEarlierDoesNotDefer() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.create(title: "Next week work", dueDate: makeDate(2026, 9, 16, 17, 0))

        let result = try store.reschedule(task.id, to: makeDate(2026, 9, 10, 17, 0))
        #expect(result.deferredFrom == nil)
    }

    @Test("A completed task moving weeks is not a deferral")
    func completedTaskDoesNotDefer() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.create(title: "Already done", dueDate: makeDate(2026, 9, 11, 17, 0))
        _ = try store.complete(task.id)

        let result = try store.reschedule(task.id, to: makeDate(2026, 9, 18, 17, 0))
        #expect(result.deferredFrom == nil)
    }

    @Test("A deferral raises the old week's count and the new week's due count")
    func deferralMovesTheNumbers() throws {
        let (store, _, _) = makeStore(now: now)
        let counters = InMemoryWeeklyStatsRepository()
        let task = try store.create(title: "Friday work", dueDate: makeDate(2026, 9, 11, 17, 0))

        #expect(try store.weeklyStats(for: thisWeek, now: now, counters: counters).due == 1)

        let result = try store.reschedule(task.id, to: makeDate(2026, 9, 15, 17, 0))
        let from = try #require(result.deferredFrom)
        try store.recordSlip(.deferred, inWeekOf: from, counters: counters)

        let before = try store.weeklyStats(for: thisWeek, now: now, counters: counters)
        #expect(before.deferred == 1)
        #expect(before.due == 0)

        let after = try store.weeklyStats(for: nextWeek, now: now, counters: counters)
        #expect(after.due == 1)
    }

    @Test("Rescheduling notifies observers like any other change")
    func rescheduleNotifies() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.create(title: "Watch me")
        var calls = 0
        let observation = store.observeChanges { calls += 1 }

        _ = try store.reschedule(task.id, to: makeDate(2026, 9, 18, 17, 0))
        #expect(calls == 1)
        observation.invalidate()
    }

    @Test("Rescheduling an unknown task reports not found")
    func unknownTask() throws {
        let (store, _, _) = makeStore(now: now)
        let missing = UUID()
        #expect(throws: TaskStoreError.notFound(missing)) {
            _ = try store.reschedule(missing, to: self.now)
        }
    }
}

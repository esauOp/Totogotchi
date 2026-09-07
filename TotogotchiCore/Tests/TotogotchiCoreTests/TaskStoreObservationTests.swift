import Foundation
import Testing
import TotogotchiCore

@Suite("TaskStore change notification")
struct TaskStoreObservationTests {

    private let now = makeDate(2026, 9, 9, 10, 0)

    @Test("Every mutation advances the revision and calls observers")
    func everyMutationNotifies() throws {
        let (store, _, _) = makeStore(now: now)
        var calls = 0
        let observation = store.observeChanges { calls += 1 }

        let task = try store.create(title: "Watch me")
        #expect(calls == 1)

        _ = try store.rename(task.id, to: "Renamed")
        _ = try store.complete(task.id)
        _ = try store.uncomplete(task.id)
        try store.delete(task.id)
        _ = try store.undoDelete(task.id)

        #expect(calls == 6)
        #expect(store.revision == 6)
        observation.invalidate()
    }

    @Test("A purge that removes nothing does not notify")
    func quietPurge() throws {
        let (store, _, _) = makeStore(now: now)
        var calls = 0
        let observation = store.observeChanges { calls += 1 }

        #expect(try store.purgeDeleted() == 0)
        #expect(calls == 0)
        #expect(store.revision == 0)
        observation.invalidate()
    }

    @Test("A purge that removes something notifies once")
    func purgeNotifies() throws {
        let (store, clock, _) = makeStore(now: now)
        let task = try store.create(title: "Old")
        try store.delete(task.id)
        clock.advance(by: TaskStore.retentionAfterDelete + 1)

        var calls = 0
        let observation = store.observeChanges { calls += 1 }
        #expect(try store.purgeDeleted() == 1)
        #expect(calls == 1)
        observation.invalidate()
    }

    @Test("Invalidating stops the callbacks")
    func invalidateStops() throws {
        let (store, _, _) = makeStore(now: now)
        var calls = 0
        let observation = store.observeChanges { calls += 1 }

        _ = try store.create(title: "First")
        observation.invalidate()
        _ = try store.create(title: "Second")

        #expect(calls == 1)
        // The revision keeps moving even with nobody listening.
        #expect(store.revision == 2)
    }

    @Test("Several observers all hear the same change")
    func multipleObservers() throws {
        let (store, _, _) = makeStore(now: now)
        var first = 0
        var second = 0
        let a = store.observeChanges { first += 1 }
        let b = store.observeChanges { second += 1 }

        _ = try store.create(title: "Broadcast")

        #expect(first == 1)
        #expect(second == 1)
        a.invalidate()
        b.invalidate()
    }
}

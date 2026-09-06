import Foundation
import Testing
import TotogotchiCore

@Suite("SwiftDataTaskRepository")
struct SwiftDataTaskRepositoryTests {

    private let now = makeDate(2026, 9, 9, 10, 0)

    @Test("A task saved to a store on disk comes back with every field intact")
    func saveAndReload() throws {
        try withTemporaryDirectory { directory in
            let repository = try SwiftDataTaskRepository(url: directory.appendingPathComponent("Test.store"))
            var task = try TaskItem(
                title: "Book flights",
                notes: "Window seat",
                priority: .high,
                dueDate: makeDate(2026, 9, 11, 17, 0),
                createdAt: now,
                recurrence: .weekly
            )
            task.markCompleted(at: now, now: now)

            try repository.upsert(task)

            let reloaded = try #require(try repository.fetch(id: task.id))
            #expect(reloaded == task)
        }
    }

    @Test("Reopening the store from disk finds what a previous session wrote")
    func survivesReopening() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("Test.store")
            let taskID: UUID

            do {
                let repository = try SwiftDataTaskRepository(url: url)
                let store = TaskStore(repository: repository, week: WeekCalendar(timeZone: TZ.utc), clock: { self.now })
                taskID = try store.create(title: "Survive a restart").id
            }

            let reopened = try SwiftDataTaskRepository(url: url)
            let store = TaskStore(repository: reopened, week: WeekCalendar(timeZone: TZ.utc), clock: { self.now })

            #expect(try store.task(id: taskID)?.title == "Survive a restart")
            #expect(try store.activeTasks().count == 1)
        }
    }

    @Test("Updating a task replaces the stored row instead of adding another")
    func upsertDoesNotDuplicate() throws {
        let repository = try SwiftDataTaskRepository(inMemoryNamed: "upsert-\(UUID().uuidString)")
        let store = TaskStore(repository: repository, week: WeekCalendar(timeZone: TZ.utc), clock: { self.now })
        let task = try store.create(title: "Original")

        _ = try store.rename(task.id, to: "Renamed")
        _ = try store.complete(task.id)

        let all = try repository.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.title == "Renamed")
        #expect(all.first?.completedAt == now)
    }

    @Test("Launch maintenance purges rows deleted over thirty days ago and keeps the rest")
    func launchMaintenancePurges() throws {
        try withTemporaryDirectory { directory in
            let repository = try SwiftDataTaskRepository(url: directory.appendingPathComponent("Test.store"))
            let clock = TestClock(now)
            let store = TaskStore(repository: repository, week: WeekCalendar(timeZone: TZ.utc), clock: clock.read)

            let old = try store.create(title: "Deleted long ago")
            let recent = try store.create(title: "Deleted yesterday")
            let alive = try store.create(title: "Still here")

            try store.delete(old.id)
            clock.advance(by: TaskStore.retentionAfterDelete - 86_400)
            try store.delete(recent.id)
            clock.advance(by: 86_400 + 1)

            #expect(try store.performLaunchMaintenance() == 1)
            #expect(try store.task(id: old.id) == nil)
            #expect(try store.task(id: recent.id)?.isDeleted == true)
            #expect(try store.task(id: alive.id)?.isDeleted == false)
        }
    }

    @Test("Removing several tasks at once leaves only the untouched ones")
    func removeMany() throws {
        let repository = try SwiftDataTaskRepository(inMemoryNamed: "remove-\(UUID().uuidString)")
        let tasks = try makeMixedTasks(count: 10, now: now)
        for task in tasks { try repository.upsert(task) }

        try repository.remove(ids: tasks.prefix(4).map(\.id))

        #expect(try repository.fetchAll().count == 6)
        try repository.remove(ids: [])
        #expect(try repository.fetchAll().count == 6)
    }

    @Test("The default store sits inside Application Support")
    func defaultStoreLocation() throws {
        let url = try TaskStorageLocation.defaultStoreURL()
        #expect(url.pathComponents.contains("Application Support"))
        #expect(url.pathComponents.contains("Totogotchi"))
        #expect(url.lastPathComponent == "Totogotchi.store")
    }

    @Test("An in-memory store reports no location and writes nothing")
    func inMemoryStoreHasNoFile() throws {
        let repository = try SwiftDataTaskRepository(inMemoryNamed: "no-file-\(UUID().uuidString)")
        try repository.upsert(try TaskItem(title: "Ephemeral", dueDate: now, createdAt: now))
        #expect(repository.storeURL == nil)
    }
}

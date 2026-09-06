import Foundation
import Testing
import TotogotchiCore

@Suite("TaskStore")
struct TaskStoreTests {

    private let now = makeDate(2026, 9, 9, 10, 0)

    @Test("A deleted task disappears from every query")
    func deletedTaskIsHidden() throws {
        let (store, _, _) = makeStore(now: now)
        let kept = try store.create(title: "Keep me")
        let removed = try store.create(title: "Remove me")

        try store.delete(removed.id)

        #expect(try store.activeTasks().map(\.id) == [kept.id])
        #expect(try store.openTasks().map(\.id) == [kept.id])
        #expect(try store.task(id: removed.id)?.isDeleted == true)
    }

    @Test("Undo restores a deleted task with every field intact")
    func undoRestoresEveryField() throws {
        let (store, _, _) = makeStore(now: now)
        let dueDate = makeDate(2026, 9, 11, 17, 0)
        var task = try store.create(
            title: "Book flights",
            notes: "Window seat",
            priority: .high,
            dueDate: dueDate,
            recurrence: .weekly
        )
        task = try store.complete(task.id)
        let before = task

        try store.delete(task.id)
        let restored = try store.undoDelete(task.id)

        #expect(restored == before)
        #expect(restored.title == "Book flights")
        #expect(restored.notes == "Window seat")
        #expect(restored.priority == .high)
        #expect(restored.dueDate == dueDate)
        #expect(restored.recurrence == .weekly)
        #expect(restored.completedAt == now)
        #expect(restored.deletedAt == nil)
        #expect(try store.activeTasks().map(\.id) == [task.id])
    }

    @Test("The undo window is five seconds")
    func undoWindowIsFiveSeconds() {
        #expect(TaskStore.undoWindow == 5)
    }

    @Test("Purging removes tasks deleted more than thirty days ago and keeps the rest")
    func purgeRespectsRetention() throws {
        let (store, clock, _) = makeStore(now: now)
        let thirtyDays = TaskStore.retentionAfterDelete

        let old = try store.create(title: "Deleted long ago")
        let borderline = try store.create(title: "Deleted exactly thirty days ago")
        let recent = try store.create(title: "Deleted yesterday")
        let alive = try store.create(title: "Never deleted")

        clock.now = now
        try store.delete(old.id)
        clock.advance(by: 1)
        try store.delete(borderline.id)
        clock.advance(by: thirtyDays - 86_400)
        try store.delete(recent.id)

        // Now sits one second past thirty days after `old` was deleted, and
        // exactly thirty days after `borderline` was deleted.
        clock.now = now + thirtyDays + 1

        let purged = try store.purgeDeleted()

        #expect(purged == 1)
        #expect(try store.task(id: old.id) == nil)
        #expect(try store.task(id: borderline.id)?.isDeleted == true)
        #expect(try store.task(id: recent.id)?.isDeleted == true)
        #expect(try store.task(id: alive.id)?.isDeleted == false)
        #expect(try store.activeTasks().map(\.id) == [alive.id])
    }

    @Test("Purging nothing reports zero")
    func purgeWithNothingExpired() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.create(title: "Fresh")
        try store.delete(task.id)

        #expect(try store.purgeDeleted() == 0)
    }

    @Test("Completing and uncompleting a task round-trips")
    func completeRoundTrip() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.create(title: "Water the plants")

        let completed = try store.complete(task.id)
        #expect(completed.completedAt == now)
        #expect(try store.openTasks().isEmpty)
        #expect(try store.activeTasks().count == 1)

        let reopened = try store.uncomplete(task.id)
        #expect(reopened.completedAt == nil)
        #expect(try store.openTasks().map(\.id) == [task.id])
    }

    @Test("An empty title is refused and nothing is stored")
    func createRejectsEmptyTitle() throws {
        let (store, _, _) = makeStore(now: now)

        #expect(throws: TaskValidationError.emptyTitle) {
            _ = try store.create(title: "   ")
        }
        #expect(try store.activeTasks().isEmpty)
    }

    @Test("Renaming through the store persists the new title")
    func renamePersists() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.create(title: "Old name")

        _ = try store.rename(task.id, to: "New name")

        #expect(try store.task(id: task.id)?.title == "New name")
    }

    @Test("Acting on an unknown identifier reports not found")
    func unknownIdentifier() throws {
        let (store, _, _) = makeStore(now: now)
        let missing = UUID()

        #expect(throws: TaskStoreError.notFound(missing)) { _ = try store.complete(missing) }
        #expect(throws: TaskStoreError.notFound(missing)) { try store.delete(missing) }
        #expect(throws: TaskStoreError.notFound(missing)) { _ = try store.rename(missing, to: "x") }
        #expect(throws: TaskStoreError.notFound(missing)) { _ = try store.undoDelete(missing) }
    }
}

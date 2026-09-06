import Foundation
import Testing
import TotogotchiCore

@Suite("TaskItem")
struct TaskItemTests {

    private let now = makeDate(2026, 9, 9, 10, 0)

    @Test("A new task starts medium priority, due at the end of the week, and unfinished")
    func defaults() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.create(title: "Send weekly report")

        #expect(task.title == "Send weekly report")
        #expect(task.priority == .medium)
        #expect(task.dueDate == makeDate(2026, 9, 13, 23, 59, 59))
        #expect(task.createdAt == now)
        #expect(task.completedAt == nil)
        #expect(task.deletedAt == nil)
        #expect(task.recurrence == .none)
        #expect(task.notes == nil)
        #expect(!task.isCompleted)
        #expect(!task.isDeleted)
    }

    @Test("A completion timestamp is never in the future")
    func completionIsNeverInTheFuture() throws {
        var task = try TaskItem(title: "Call bank", dueDate: now, createdAt: now)
        task.markCompleted(at: now.addingTimeInterval(3_600), now: now)

        #expect(task.completedAt == now)
        #expect(task.isCompleted)
    }

    @Test("Surrounding whitespace is trimmed from a title")
    func titleIsTrimmed() throws {
        let task = try TaskItem(title: "  Call dentist  ", dueDate: now, createdAt: now)
        #expect(task.title == "Call dentist")
    }

    @Test("A title of only whitespace is rejected", arguments: ["", "   ", "\t", "\n  \n"])
    func whitespaceOnlyTitleRejected(raw: String) {
        #expect(throws: TaskValidationError.emptyTitle) {
            _ = try TaskItem(title: raw, dueDate: now, createdAt: now)
        }
    }

    @Test("A title of exactly 200 characters is accepted")
    func maximumLengthTitleAccepted() throws {
        let title = String(repeating: "a", count: 200)
        let task = try TaskItem(title: title, dueDate: now, createdAt: now)
        #expect(task.title.count == 200)
    }

    @Test("A title of 201 characters is rejected and names the limit")
    func overLongTitleRejected() {
        let title = String(repeating: "a", count: 201)
        #expect(throws: TaskValidationError.titleTooLong(maxLength: 200, actualLength: 201)) {
            _ = try TaskItem(title: title, dueDate: now, createdAt: now)
        }
    }

    @Test("Length is measured after trimming")
    func lengthMeasuredAfterTrimming() throws {
        let title = "  " + String(repeating: "a", count: 200) + "  "
        let task = try TaskItem(title: title, dueDate: now, createdAt: now)
        #expect(task.title.count == 200)
    }

    @Test("Renaming validates the new title and leaves the old one on failure")
    func renameValidates() throws {
        var task = try TaskItem(title: "Original", dueDate: now, createdAt: now)

        try task.rename(to: "  Updated  ")
        #expect(task.title == "Updated")

        #expect(throws: TaskValidationError.emptyTitle) {
            try task.rename(to: "  ")
        }
        #expect(task.title == "Updated")
    }

    @Test("Only an unfinished, undeleted task with a past due date is overdue")
    func overdueRules() throws {
        let past = now.addingTimeInterval(-60)
        var task = try TaskItem(title: "Overdue thing", dueDate: past, createdAt: past)
        #expect(task.isOverdue(now: now))

        var completed = task
        completed.markCompleted(at: now, now: now)
        #expect(!completed.isOverdue(now: now))

        task.markDeleted(at: now)
        #expect(!task.isOverdue(now: now))

        let future = try TaskItem(title: "Later", dueDate: now.addingTimeInterval(60), createdAt: now)
        #expect(!future.isOverdue(now: now))
    }

    @Test("A task due exactly now is not yet overdue")
    func dueExactlyNowIsNotOverdue() throws {
        let task = try TaskItem(title: "Right now", dueDate: now, createdAt: now)
        #expect(!task.isOverdue(now: now))
    }

    @Test("Priority sorts high before medium before low")
    func priorityOrdering() {
        #expect([Priority.low, .high, .medium].sorted() == [.high, .medium, .low])
    }
}

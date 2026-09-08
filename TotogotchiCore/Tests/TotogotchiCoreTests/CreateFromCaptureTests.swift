import Foundation
import Testing
import TotogotchiCore

@Suite("Create from capture")
struct CreateFromCaptureTests {

    /// Wednesday 9 September 2026.
    private let now = makeDate(2026, 9, 9, 10, 0)

    @Test("Tokens set the priority and due date on the created task")
    func tokensApplied() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.createFromCapture("Renew passport !high @fri")

        #expect(task.title == "Renew passport")
        #expect(task.priority == .high)
        #expect(task.dueDate == makeDate(2026, 9, 11, 23, 59, 59))
    }

    @Test("Without tokens the usual defaults apply")
    func defaultsWithoutTokens() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.createFromCapture("Send weekly report")

        #expect(task.title == "Send weekly report")
        #expect(task.priority == .medium)
        // End of the current ISO week.
        #expect(task.dueDate == makeDate(2026, 9, 13, 23, 59, 59))
    }

    @Test("Text of nothing but tokens is refused like any empty title")
    func onlyTokensIsEmpty() throws {
        let (store, _, _) = makeStore(now: now)
        #expect(throws: TaskValidationError.emptyTitle) {
            _ = try store.createFromCapture("!high @fri")
        }
        #expect(try store.activeTasks().isEmpty)
    }

    @Test("The preview agrees with what creating actually does")
    func previewMatchesCreation() throws {
        let (store, _, _) = makeStore(now: now)
        let text = "Draft budget !low @mon"

        let preview = store.parseCapture(text)
        let task = try store.createFromCapture(text)

        #expect(preview.title == task.title)
        #expect(preview.priority == task.priority)
        #expect(preview.dueDate == task.dueDate)
    }

    @Test("A title that is only unknown tokens is still a title")
    func unknownTokensAreATitle() throws {
        let (store, _, _) = makeStore(now: now)
        let task = try store.createFromCapture("Email @maria about !urgent issue")

        #expect(task.title == "Email @maria about !urgent issue")
        #expect(task.priority == .medium)
    }
}

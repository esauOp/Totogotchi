import Foundation
import Testing
import TotogotchiCore

@Suite("UsageLog")
struct UsageLogTests {

    private let now = makeDate(2026, 9, 9, 10, 0)

    private func makeLog(now: Date? = nil) -> (UsageLog, TestClock) {
        let clock = TestClock(now ?? self.now)
        return (UsageLog(repository: InMemoryUsageLogRepository(), clock: clock.read), clock)
    }

    @Test("Every kind of event can be recorded and read back")
    func everyKindRoundTrips() throws {
        let (log, _) = makeLog()
        for kind in UsageEventKind.allCases {
            log.record(kind)
        }
        let recorded = try log.allEvents()
        #expect(recorded.count == UsageEventKind.allCases.count)
        #expect(Set(recorded.map(\.kind)) == Set(UsageEventKind.allCases))
    }

    @Test("A creation event carries the task and its source")
    func creationCarriesSource() throws {
        let (log, _) = makeLog()
        let id = UUID()
        log.record(.taskCreated, taskID: id, source: .hotkey)

        let event = try #require(try log.events(ofKind: .taskCreated).first)
        #expect(event.taskID == id)
        #expect(event.source == .hotkey)
        #expect(event.occurredAt == now)
    }

    @Test("A mood change carries both moods")
    func moodChangeCarriesBoth() throws {
        let (log, _) = makeLog()
        log.record(.moodChanged, previousMood: .neutral, newMood: .happy)

        let event = try #require(try log.events(ofKind: .moodChanged).first)
        #expect(event.previousMood == .neutral)
        #expect(event.newMood == .happy)
    }

    @Test("An event has nowhere to put a task's text")
    func noRoomForText() throws {
        let (log, _) = makeLog()
        let id = UUID()
        log.record(.taskCreated, taskID: id, source: .widget)

        // Encoding the whole event is the strongest check available: if a title
        // could leak, it would have to appear here.
        let event = try #require(try log.allEvents().first)
        let encoded = try JSONEncoder().encode(event)
        let text = String(data: encoded, encoding: .utf8) ?? ""

        #expect(text.contains(id.uuidString))
        #expect(!text.lowercased().contains("title"))
        #expect(!text.lowercased().contains("notes"))
    }

    @Test("Events are returned oldest first")
    func orderedOldestFirst() throws {
        let (log, clock) = makeLog()
        log.record(.appLaunched)
        clock.advance(by: 60)
        log.record(.taskCreated)
        clock.advance(by: 60)
        log.record(.appQuit)

        #expect(try log.allEvents().map(\.kind) == [.appLaunched, .taskCreated, .appQuit])
    }

    @Test("Purging keeps the last ninety days and drops what is older")
    func purgeKeepsNinetyDays() throws {
        let (log, clock) = makeLog(now: now.addingTimeInterval(-UsageLog.retention - 86_400))
        log.record(.appLaunched) // 91 days ago

        clock.now = now.addingTimeInterval(-UsageLog.retention + 3_600) // just inside
        log.record(.taskCreated)

        clock.now = now
        log.record(.taskCompleted)

        #expect(try log.purgeOldEvents() == 1)
        #expect(try log.allEvents().map(\.kind) == [.taskCreated, .taskCompleted])
    }

    @Test("Purging with nothing expired removes nothing")
    func quietPurge() throws {
        let (log, _) = makeLog()
        log.record(.appLaunched)
        #expect(try log.purgeOldEvents() == 0)
        #expect(try log.allEvents().count == 1)
    }

    @Test("The retention window is ninety days")
    func retentionIsNinetyDays() {
        #expect(UsageLog.retention == 90 * 24 * 60 * 60)
    }
}

@Suite("UsageLog on disk")
struct SwiftDataUsageLogTests {

    private let now = makeDate(2026, 9, 9, 10, 0)

    @Test("Events survive reopening the store")
    func survivesReopening() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("Usage.store")
            let id = UUID()

            do {
                let log = UsageLog(
                    repository: try SwiftDataUsageLogRepository(url: url),
                    clock: { self.now }
                )
                log.record(.taskCreated, taskID: id, source: .hotkey)
                log.record(.moodChanged, previousMood: .worried, newMood: .happy)
            }

            let reopened = UsageLog(
                repository: try SwiftDataUsageLogRepository(url: url),
                clock: { self.now }
            )
            let events = try reopened.allEvents()
            #expect(events.count == 2)
            #expect(events.first?.taskID == id)
            #expect(events.first?.source == .hotkey)
            #expect(events.last?.newMood == .happy)
        }
    }

    @Test("Tasks and events share one store without disturbing each other")
    func sharesTheStoreWithTasks() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("Shared.store")
            let tasks = TaskStore(repository: try SwiftDataTaskRepository(url: url), clock: { self.now })
            let log = UsageLog(repository: try SwiftDataUsageLogRepository(url: url), clock: { self.now })

            let task = try tasks.create(title: "Shared store")
            log.record(.taskCreated, taskID: task.id, source: .widget)

            #expect(try tasks.activeTasks().count == 1)
            #expect(try log.allEvents().count == 1)
        }
    }

    @Test("Purging on disk drops only what is past retention")
    func purgeOnDisk() throws {
        try withTemporaryDirectory { directory in
            let clock = TestClock(now.addingTimeInterval(-UsageLog.retention - 86_400))
            let log = UsageLog(
                repository: try SwiftDataUsageLogRepository(url: directory.appendingPathComponent("Purge.store")),
                clock: clock.read
            )
            log.record(.appLaunched)
            clock.now = now
            log.record(.appQuit)

            #expect(try log.purgeOldEvents() == 1)
            #expect(try log.allEvents().map(\.kind) == [.appQuit])
        }
    }
}

import Foundation
import Testing
import TotogotchiCore

@Suite("TaskArchive")
struct TaskArchiveTests {

    private let now = makeDate(2026, 9, 9, 10, 0)

    private func makeDiskStore(at directory: URL) throws -> TaskStore {
        let repository = try SwiftDataTaskRepository(url: directory.appendingPathComponent("Test.store"))
        return TaskStore(repository: repository, week: WeekCalendar(timeZone: TZ.utc), clock: { self.now })
    }

    @Test("Exporting then importing fifty mixed tasks reproduces every field")
    func roundTrip() throws {
        try withTemporaryDirectory { directory in
            let source = try makeDiskStore(at: directory)
            let originals = try makeMixedTasks(count: 50, now: now)
            for task in originals { try source.replaceForTesting(task) }

            let exportDirectory = directory.appendingPathComponent("export", isDirectory: true)
            try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
            let file = exportDirectory.appendingPathComponent("totogotchi.json")

            try source.exportArchive(to: file)

            // Exactly one file lands at the chosen location and nothing else.
            let written = try FileManager.default.contentsOfDirectory(atPath: exportDirectory.path)
            #expect(written == ["totogotchi.json"])

            let emptyDirectory = directory.appendingPathComponent("restored", isDirectory: true)
            try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
            let destination = try makeDiskStore(at: emptyDirectory)

            #expect(try destination.importArchive(from: file) == 50)

            let restored = try destination.allTasksForExportTesting().sorted { $0.id.uuidString < $1.id.uuidString }
            let expected = originals.sorted { $0.id.uuidString < $1.id.uuidString }
            #expect(restored == expected)
        }
    }

    @Test("The export includes completed and soft-deleted tasks")
    func exportIncludesEveryState() throws {
        try withTemporaryDirectory { directory in
            let store = try makeDiskStore(at: directory)
            let open = try store.create(title: "Open")
            let done = try store.create(title: "Done")
            let gone = try store.create(title: "Deleted")
            _ = try store.complete(done.id)
            try store.delete(gone.id)

            let file = directory.appendingPathComponent("export.json")
            try store.exportArchive(to: file)

            let archive = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
            let tasks = try #require(archive?["tasks"] as? [[String: Any]])
            #expect(tasks.count == 3)
            #expect(Set(tasks.compactMap { $0["title"] as? String }) == ["Open", "Done", "Deleted"])
            #expect(archive?["formatVersion"] as? Int == TaskArchive.currentFormatVersion)
            _ = open
        }
    }

    @Test("Timestamps survive the round trip to the millisecond")
    func timestampPrecision() throws {
        try withTemporaryDirectory { directory in
            let store = try makeDiskStore(at: directory)
            let odd = now.addingTimeInterval(0.123)
            try store.replaceForTesting(
                try TaskItem(title: "Precise", dueDate: odd, createdAt: odd)
            )

            let file = directory.appendingPathComponent("export.json")
            try store.exportArchive(to: file)

            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(text.contains(".123"))

            let restoredDirectory = directory.appendingPathComponent("restored", isDirectory: true)
            try FileManager.default.createDirectory(at: restoredDirectory, withIntermediateDirectories: true)
            let destination = try makeDiskStore(at: restoredDirectory)
            try destination.importArchive(from: file)

            // Milliseconds are the documented guarantee: the decimal text rounds
            // to three places, so the restored Double is within a millisecond
            // rather than bit-identical.
            let restored = try #require(try destination.allTasksForExportTesting().first)
            #expect(abs(restored.dueDate.timeIntervalSince(odd)) < 0.001)
            #expect(abs(restored.createdAt.timeIntervalSince(odd)) < 0.001)
        }
    }

    @Test("Importing a newer format version is refused")
    func rejectsUnknownFormat() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("future.json")
            let json = #"{"formatVersion":99,"exportedAt":"2026-09-09T10:00:00.000Z","tasks":[]}"#
            try json.write(to: file, atomically: true, encoding: .utf8)

            let store = try makeDiskStore(at: directory)
            #expect(throws: TaskArchiveError.unsupportedFormatVersion(found: 99, supported: TaskArchive.currentFormatVersion)) {
                try store.importArchive(from: file)
            }
        }
    }

    @Test("Importing replaces a task that already exists rather than duplicating it")
    func importReplacesExisting() throws {
        try withTemporaryDirectory { directory in
            let store = try makeDiskStore(at: directory)
            let task = try store.create(title: "Original title")
            let file = directory.appendingPathComponent("export.json")
            try store.exportArchive(to: file)

            _ = try store.rename(task.id, to: "Changed since export")
            try store.importArchive(from: file)

            #expect(try store.activeTasks().count == 1)
            #expect(try store.task(id: task.id)?.title == "Original title")
        }
    }
}

@Suite("Archive format version 2")
struct ArchiveVersionTests {

    private let now = makeDate(2026, 9, 9, 10, 0)

    private func makeStore(at directory: URL) throws -> TaskStore {
        TaskStore(
            repository: try SwiftDataTaskRepository(url: directory.appendingPathComponent("V2.store")),
            week: WeekCalendar(timeZone: TZ.utc),
            clock: { self.now }
        )
    }

    @Test("An export carries tasks, weekly statistics and usage events")
    func roundTripsEverything() throws {
        try withTemporaryDirectory { directory in
            let source = try makeStore(at: directory)
            let counters = InMemoryWeeklyStatsRepository()
            let usage = UsageLog(repository: InMemoryUsageLogRepository(), clock: { self.now })

            let task = try source.create(title: "Carried across")
            try source.recordSlip(.deferred, inWeekOf: now, counters: counters)
            try source.recordSlip(.deleted, inWeekOf: now, counters: counters)
            usage.record(.taskCreated, taskID: task.id, source: .hotkey)
            usage.record(.moodChanged, previousMood: .neutral, newMood: .happy)

            let file = directory.appendingPathComponent("export.json")
            try source.exportArchive(to: file, usage: usage, counters: counters)

            let decoded = try TaskArchiveCoderTestAccess.decode(Data(contentsOf: file))
            #expect(decoded.formatVersion == 2)
            #expect(decoded.tasks.count == 1)
            #expect(decoded.weeklyStats.count == 1)
            #expect(decoded.weeklyStats.first?.deferred == 1)
            #expect(decoded.weeklyStats.first?.deleted == 1)
            #expect(decoded.usageEvents.count == 2)
        }
    }

    @Test("Importing restores the weekly counters")
    func importRestoresCounters() throws {
        try withTemporaryDirectory { directory in
            let source = try makeStore(at: directory)
            let sourceCounters = InMemoryWeeklyStatsRepository()
            _ = try source.create(title: "Something")
            try source.recordSlip(.deferred, inWeekOf: now, counters: sourceCounters)

            let file = directory.appendingPathComponent("export.json")
            try source.exportArchive(to: file, counters: sourceCounters)

            let restoredDirectory = directory.appendingPathComponent("restored", isDirectory: true)
            try FileManager.default.createDirectory(at: restoredDirectory, withIntermediateDirectories: true)
            let destination = try makeStore(at: restoredDirectory)
            let destinationCounters = InMemoryWeeklyStatsRepository()

            try destination.importArchive(from: file, counters: destinationCounters)

            let stats = try destination.weeklyStats(now: now, counters: destinationCounters)
            #expect(stats.deferred == 1)
        }
    }

    @Test("A version 1 file still imports, as tasks with no history")
    func readsVersionOne() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("v1.json")
            let json = """
            {
              "formatVersion" : 1,
              "exportedAt" : "2026-09-09T10:00:00.000Z",
              "tasks" : [
                {
                  "id" : "\(UUID().uuidString)",
                  "title" : "From an older export",
                  "priority" : "medium",
                  "dueDate" : "2026-09-13T23:59:59.000Z",
                  "createdAt" : "2026-09-09T10:00:00.000Z",
                  "recurrence" : "none"
                }
              ]
            }
            """
            try json.write(to: file, atomically: true, encoding: .utf8)

            let store = try makeStore(at: directory)
            let counters = InMemoryWeeklyStatsRepository()

            #expect(try store.importArchive(from: file, counters: counters) == 1)
            #expect(try store.activeTasks().first?.title == "From an older export")
            #expect(try counters.allWeeks().isEmpty)
        }
    }

    @Test("Both readable versions are declared")
    func readableVersions() {
        #expect(TaskArchive.readableFormatVersions == [1, 2])
        #expect(TaskArchive.currentFormatVersion == 2)
    }
}

/// The archive's own coder is internal to the module, so the test builds a
/// decoder with the same date strategy rather than reaching inside.
enum TaskArchiveCoderTestAccess {
    static func decode(_ data: Data) throws -> TaskArchive {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = formatter.date(from: text) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Bad date \(text)")
                )
            }
            return date
        }
        return try decoder.decode(TaskArchive.self, from: data)
    }
}

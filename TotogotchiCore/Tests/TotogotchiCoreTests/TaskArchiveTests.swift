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
            #expect(throws: TaskArchiveError.unsupportedFormatVersion(found: 99, supported: 1)) {
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

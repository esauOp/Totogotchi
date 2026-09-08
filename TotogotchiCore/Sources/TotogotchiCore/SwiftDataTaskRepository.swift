import Foundation
import SwiftData

/// Where the task database lives on disk.
public enum TaskStorageLocation {
    /// `Application Support/Totogotchi/Totogotchi.store`.
    ///
    /// Under the App Sandbox this resolves inside the app's own container, which
    /// is what `specs/task-storage` requires. The directory is created if needed.
    public static func defaultStoreURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("Totogotchi", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Totogotchi.store")
    }
}

/// Durable task storage backed by SwiftData.
///
/// Every mutation saves before returning, so a task that was reported as created
/// survives an immediate crash. Not thread-safe: SwiftData's `ModelContext` is
/// bound to the context that created it, and the app drives it from the main
/// actor.
public final class SwiftDataTaskRepository: TaskRepository {
    private let container: ModelContainer
    private let context: ModelContext

    /// Opens, or creates, the store at `url`.
    public convenience init(url: URL) throws {
        try self.init(configuration: ModelConfiguration(url: url))
    }

    /// A throwaway store that never touches disk. For tests and previews.
    public convenience init(inMemoryNamed name: String = "TotogotchiInMemory") throws {
        try self.init(configuration: ModelConfiguration(name, isStoredInMemoryOnly: true))
    }

    public init(configuration: ModelConfiguration) throws {
        // Both models are declared here because tasks and usage events share
        // one store file; a container that knew only half the schema would
        // fight the other one.
        container = try ModelContainer(
            for: TaskRecord.self, UsageEventRecord.self,
            configurations: configuration
        )
        context = ModelContext(container)
        // Saves are explicit so a mutation cannot be reported as durable before
        // it has actually been written.
        context.autosaveEnabled = false
    }

    /// The store's location on disk, or nil for an in-memory store.
    ///
    /// SwiftData hands in-memory configurations a placeholder URL of
    /// `/dev/null`, which would be misleading to surface.
    public var storeURL: URL? {
        guard let configuration = container.configurations.first,
              !configuration.isStoredInMemoryOnly
        else { return nil }
        return configuration.url
    }

    public func fetchAll() throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskRecord>()).map(\.taskItem)
    }

    public func fetch(id: UUID) throws -> TaskItem? {
        try record(for: id)?.taskItem
    }

    public func upsert(_ task: TaskItem) throws {
        if let existing = try record(for: task.id) {
            existing.apply(task)
        } else {
            context.insert(TaskRecord(task))
        }
        try context.save()
    }

    public func remove(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        for id in ids {
            if let existing = try record(for: id) {
                context.delete(existing)
            }
        }
        try context.save()
    }

    private func record(for id: UUID) throws -> TaskRecord? {
        var descriptor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

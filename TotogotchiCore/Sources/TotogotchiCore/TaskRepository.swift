import Foundation

/// Storage for tasks, including soft-deleted ones.
///
/// The store layer decides which tasks are visible; a repository just persists
/// what it is given.
public protocol TaskRepository: AnyObject {
    /// Every stored task, including completed and soft-deleted ones.
    func fetchAll() throws -> [TaskItem]
    func fetch(id: UUID) throws -> TaskItem?
    /// Inserts the task, or replaces the stored one with the same identifier.
    func upsert(_ task: TaskItem) throws
    /// Permanently removes tasks. Used by the purge, not by user-facing delete.
    func remove(ids: [UUID]) throws
}

/// An in-memory repository, used by tests and previews.
public final class InMemoryTaskRepository: TaskRepository {
    private var storage: [UUID: TaskItem] = [:]

    public init(tasks: [TaskItem] = []) {
        for task in tasks { storage[task.id] = task }
    }

    public func fetchAll() throws -> [TaskItem] {
        Array(storage.values)
    }

    public func fetch(id: UUID) throws -> TaskItem? {
        storage[id]
    }

    public func upsert(_ task: TaskItem) throws {
        storage[task.id] = task
    }

    public func remove(ids: [UUID]) throws {
        for id in ids { storage.removeValue(forKey: id) }
    }
}

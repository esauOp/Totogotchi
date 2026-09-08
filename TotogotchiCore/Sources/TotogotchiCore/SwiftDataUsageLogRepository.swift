import Foundation
import SwiftData

/// Durable usage-event storage, in the same container as the tasks.
///
/// Shares the store file so a single backup or export carries everything, and
/// saves synchronously for the same reason task writes do: an event that was
/// reported as recorded should survive a crash.
public final class SwiftDataUsageLogRepository: UsageLogRepository {
    private let container: ModelContainer
    private let context: ModelContext

    public convenience init(url: URL) throws {
        try self.init(configuration: ModelConfiguration(url: url))
    }

    public convenience init(inMemoryNamed name: String = "TotogotchiUsageInMemory") throws {
        try self.init(configuration: ModelConfiguration(name, isStoredInMemoryOnly: true))
    }

    public init(configuration: ModelConfiguration) throws {
        container = try ModelContainer(
            for: TaskRecord.self, UsageEventRecord.self,
            configurations: configuration
        )
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    public func append(_ event: UsageEvent) throws {
        context.insert(UsageEventRecord(event))
        try context.save()
    }

    public func fetchAll() throws -> [UsageEvent] {
        let descriptor = FetchDescriptor<UsageEventRecord>(
            sortBy: [SortDescriptor(\.occurredAt, order: .forward)]
        )
        return try context.fetch(descriptor).compactMap(\.usageEvent)
    }

    @discardableResult
    public func purge(before cutoff: Date) throws -> Int {
        let descriptor = FetchDescriptor<UsageEventRecord>(
            predicate: #Predicate { $0.occurredAt < cutoff }
        )
        let expired = try context.fetch(descriptor)
        guard !expired.isEmpty else { return 0 }
        for record in expired { context.delete(record) }
        try context.save()
        return expired.count
    }
}

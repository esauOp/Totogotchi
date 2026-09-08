import Foundation
import SwiftData

/// The stored counters for one ISO week.
///
/// Only the two counts that cannot be recomputed live here. Due and completed
/// are derived from the tasks every time they are read.
@Model
final class WeeklyStatsRecord {
    @Attribute(.unique) var key: String = ""
    var isoYear: Int = 0
    var isoWeek: Int = 0
    var deleted: Int = 0
    var deferred: Int = 0

    init(week: ISOWeek, deleted: Int, deferred: Int) {
        key = WeeklyStatsRecord.key(for: week)
        isoYear = week.year
        isoWeek = week.week
        self.deleted = deleted
        self.deferred = deferred
    }

    /// Sortable and unique, so a week can be found without a compound predicate.
    static func key(for week: ISOWeek) -> String {
        String(format: "%04d-%02d", week.year, week.week)
    }

    var week: ISOWeek { ISOWeek(year: isoYear, week: isoWeek) }
}

/// Durable weekly counters, in the same store file as the tasks and events.
public final class SwiftDataWeeklyStatsRepository: WeeklyStatsRepository {
    private let container: ModelContainer
    private let context: ModelContext

    public convenience init(url: URL) throws {
        try self.init(configuration: ModelConfiguration(url: url))
    }

    public convenience init(inMemoryNamed name: String = "TotogotchiStatsInMemory") throws {
        try self.init(configuration: ModelConfiguration(name, isStoredInMemoryOnly: true))
    }

    public init(configuration: ModelConfiguration) throws {
        container = try ModelContainer(
            for: TaskRecord.self, UsageEventRecord.self, WeeklyStatsRecord.self,
            configurations: configuration
        )
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    public func counters(for week: ISOWeek) throws -> (deleted: Int, deferred: Int)? {
        guard let record = try record(for: week) else { return nil }
        return (record.deleted, record.deferred)
    }

    public func setCounters(deleted: Int, deferred: Int, for week: ISOWeek) throws {
        if let existing = try record(for: week) {
            existing.deleted = deleted
            existing.deferred = deferred
        } else {
            context.insert(WeeklyStatsRecord(week: week, deleted: deleted, deferred: deferred))
        }
        try context.save()
    }

    public func allWeeks() throws -> [ISOWeek] {
        let descriptor = FetchDescriptor<WeeklyStatsRecord>(
            sortBy: [SortDescriptor(\.key, order: .forward)]
        )
        return try context.fetch(descriptor).map(\.week)
    }

    @discardableResult
    public func purge(before week: ISOWeek) throws -> Int {
        let cutoff = WeeklyStatsRecord.key(for: week)
        let descriptor = FetchDescriptor<WeeklyStatsRecord>(
            predicate: #Predicate { $0.key < cutoff }
        )
        let expired = try context.fetch(descriptor)
        guard !expired.isEmpty else { return 0 }
        for record in expired { context.delete(record) }
        try context.save()
        return expired.count
    }

    private func record(for week: ISOWeek) throws -> WeeklyStatsRecord? {
        let key = WeeklyStatsRecord.key(for: week)
        var descriptor = FetchDescriptor<WeeklyStatsRecord>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

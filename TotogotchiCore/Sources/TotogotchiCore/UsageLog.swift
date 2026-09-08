import Foundation

/// Where usage events are kept.
public protocol UsageLogRepository: AnyObject {
    func append(_ event: UsageEvent) throws
    /// Every event, oldest first.
    func fetchAll() throws -> [UsageEvent]
    /// Permanently removes events recorded before `cutoff`. Returns how many.
    @discardableResult
    func purge(before cutoff: Date) throws -> Int
}

/// An in-memory log, for tests and previews.
public final class InMemoryUsageLogRepository: UsageLogRepository {
    private var events: [UsageEvent] = []

    public init(events: [UsageEvent] = []) {
        self.events = events
    }

    public func append(_ event: UsageEvent) throws {
        events.append(event)
    }

    public func fetchAll() throws -> [UsageEvent] {
        events.sorted { $0.occurredAt < $1.occurredAt }
    }

    @discardableResult
    public func purge(before cutoff: Date) throws -> Int {
        let before = events.count
        events.removeAll { $0.occurredAt < cutoff }
        return before - events.count
    }
}

/// Records what happened, on this Mac only.
///
/// Nothing here reaches a network, and the app carries no network entitlement to
/// reach one with. The log exists so the weekly summary and the PRD's success
/// metrics are computed from events rather than inferred from current state.
public final class UsageLog {
    /// How long events are kept. The spec asks for at least 90 days.
    public static let retention: TimeInterval = 90 * 24 * 60 * 60

    private let repository: UsageLogRepository
    private let clock: () -> Date

    public init(repository: UsageLogRepository, clock: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.clock = clock
    }

    public func record(
        _ kind: UsageEventKind,
        taskID: UUID? = nil,
        source: TaskSource? = nil,
        previousMood: PetMood? = nil,
        newMood: PetMood? = nil
    ) {
        let event = UsageEvent(
            kind: kind,
            occurredAt: clock(),
            taskID: taskID,
            source: source,
            previousMood: previousMood,
            newMood: newMood
        )
        // A log that cannot be written is not worth failing a user action over.
        try? repository.append(event)
    }

    public func allEvents() throws -> [UsageEvent] {
        try repository.fetchAll()
    }

    public func events(ofKind kind: UsageEventKind) throws -> [UsageEvent] {
        try repository.fetchAll().filter { $0.kind == kind }
    }

    /// Drops events past the retention window. Run at launch, beside the
    /// dead-task purge.
    @discardableResult
    public func purgeOldEvents() throws -> Int {
        try repository.purge(before: clock().addingTimeInterval(-Self.retention))
    }
}

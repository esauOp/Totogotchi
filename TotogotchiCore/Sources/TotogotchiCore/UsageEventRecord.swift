import Foundation
import SwiftData

/// The stored shape of a usage event.
///
/// Separate from `UsageEvent` for the same reason `TaskRecord` is separate from
/// `TaskItem`: the domain value stays a plain struct, and the schema can move
/// without the rules moving with it. Enums are held as raw strings so a column
/// stays readable.
@Model
final class UsageEventRecord {
    @Attribute(.unique) var id: UUID = UUID()
    var kindRaw: String = UsageEventKind.appLaunched.rawValue
    var occurredAt: Date = Date.distantPast
    var taskID: UUID?
    var sourceRaw: String?
    var previousMoodRaw: String?
    var newMoodRaw: String?

    init(_ event: UsageEvent) {
        id = event.id
        kindRaw = event.kind.rawValue
        occurredAt = event.occurredAt
        taskID = event.taskID
        sourceRaw = event.source?.rawValue
        previousMoodRaw = event.previousMood?.rawValue
        newMoodRaw = event.newMood?.rawValue
    }

    /// An unrecognised raw value is dropped rather than failing the read: one odd
    /// row should not make the log unreadable.
    var usageEvent: UsageEvent? {
        guard let kind = UsageEventKind(rawValue: kindRaw) else { return nil }
        return UsageEvent(
            id: id,
            kind: kind,
            occurredAt: occurredAt,
            taskID: taskID,
            source: sourceRaw.flatMap(TaskSource.init(rawValue:)),
            previousMood: previousMoodRaw.flatMap(PetMood.init(rawValue:)),
            newMood: newMoodRaw.flatMap(PetMood.init(rawValue:))
        )
    }
}

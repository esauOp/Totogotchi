import Foundation

/// Something worth counting later.
///
/// The list is fixed by `specs/usage-log`, and it exists so the weekly summary
/// and PRD §8 can be computed from what actually happened rather than from what
/// the current state implies.
public enum UsageEventKind: String, Codable, Sendable, CaseIterable {
    case taskCreated
    case taskCompleted
    case taskDeleted
    case taskDeferred
    case captureOpened
    case captureCancelled
    case moodChanged
    case notificationShown
    case notificationClicked
    case appLaunched
    case appQuit
}

/// Where a task came from, recorded on creation.
public enum TaskSource: String, Codable, Sendable, CaseIterable {
    case hotkey
    case widget
}

/// One recorded moment.
///
/// Deliberately narrow. It carries identifiers and enum values and nothing else:
/// no titles, no notes. That is a spec requirement, and it also means the log can
/// be exported or read back without revealing what the user is working on.
public struct UsageEvent: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let kind: UsageEventKind
    public let occurredAt: Date
    /// The task the event was about, when it was about one.
    public let taskID: UUID?
    public let source: TaskSource?
    public let previousMood: PetMood?
    public let newMood: PetMood?

    public init(
        id: UUID = UUID(),
        kind: UsageEventKind,
        occurredAt: Date,
        taskID: UUID? = nil,
        source: TaskSource? = nil,
        previousMood: PetMood? = nil,
        newMood: PetMood? = nil
    ) {
        self.id = id
        self.kind = kind
        self.occurredAt = occurredAt
        self.taskID = taskID
        self.source = source
        self.previousMood = previousMood
        self.newMood = newMood
    }
}

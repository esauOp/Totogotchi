import Foundation

/// Whether a task recreates itself after completion.
public enum Recurrence: String, Codable, Sendable, CaseIterable {
    /// The task happens once. This is the default.
    case none
    /// The task reappears on the same weekday of the following week.
    case weekly
}

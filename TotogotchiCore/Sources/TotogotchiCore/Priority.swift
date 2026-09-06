import Foundation

/// How urgent a task is. Ordering is high, then medium, then low.
public enum Priority: String, Codable, Sendable, CaseIterable, Comparable {
    case high
    case medium
    case low

    /// Lower ranks sort first: high (0), medium (1), low (2).
    public var sortRank: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    public static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.sortRank < rhs.sortRank
    }
}

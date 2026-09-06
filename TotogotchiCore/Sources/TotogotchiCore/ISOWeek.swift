import Foundation

/// An ISO-8601 week, identified by its week-based year and week number.
public struct ISOWeek: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let week: Int

    public init(year: Int, week: Int) {
        self.year = year
        self.week = week
    }

    public static func < (lhs: ISOWeek, rhs: ISOWeek) -> Bool {
        (lhs.year, lhs.week) < (rhs.year, rhs.week)
    }
}

extension ISOWeek: CustomStringConvertible {
    public var description: String { String(format: "%04d-W%02d", year, week) }
}

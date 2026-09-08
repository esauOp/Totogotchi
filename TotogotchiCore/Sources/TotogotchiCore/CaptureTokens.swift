import Foundation

/// What a line of capture text meant once its tokens were read.
public struct ParsedCapture: Equatable, Sendable {
    /// The text with recognised tokens removed and whitespace tidied.
    public let title: String
    /// Nil when the text carried no priority token.
    public let priority: Priority?
    /// Nil when the text carried no due-date token.
    public let dueDate: Date?

    public init(title: String, priority: Priority?, dueDate: Date?) {
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
    }
}

/// Reads `!high`, `@fri` and friends out of capture text.
///
/// A pure function of the text and the current time, so every case in
/// `specs/quick-capture` is a unit test rather than something to click through.
/// Anything not recognised is left in the title untouched: an unknown token is
/// far more likely to be part of what the user meant to write than a typo of a
/// real one.
public enum CaptureTokens {
    private static let priorities: [String: Priority] = [
        "high": .high,
        "med": .medium,
        "low": .low,
    ]

    /// Weekday numbers as the Gregorian calendar counts them, Sunday first.
    private static let weekdays: [String: Int] = [
        "sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7,
    ]

    public static func parse(
        _ text: String,
        now: Date,
        calendar: WeekCalendar = WeekCalendar()
    ) -> ParsedCapture {
        var keptWords: [String] = []
        var priority: Priority?
        var dueDate: Date?

        for word in text.split(separator: " ", omittingEmptySubsequences: true) {
            let token = String(word)
            if let found = priorityToken(token) {
                // The last one wins: the user's final word on it is the one
                // they meant.
                priority = found
                continue
            }
            if let found = dueDateToken(token, now: now, calendar: calendar) {
                dueDate = found
                continue
            }
            keptWords.append(token)
        }

        return ParsedCapture(
            title: keptWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            dueDate: dueDate
        )
    }

    private static func priorityToken(_ token: String) -> Priority? {
        guard token.hasPrefix("!") else { return nil }
        return priorities[String(token.dropFirst()).lowercased()]
    }

    private static func dueDateToken(_ token: String, now: Date, calendar: WeekCalendar) -> Date? {
        guard token.hasPrefix("@") else { return nil }
        let name = String(token.dropFirst()).lowercased()

        switch name {
        case "today":
            return calendar.endOfDay(for: now)
        case "tomorrow":
            return calendar.endOfDay(for: calendar.dayAfter(now))
        default:
            guard let weekday = weekdays[name] else { return nil }
            return calendar.endOfDay(for: calendar.nextOccurrence(ofWeekday: weekday, onOrAfter: now))
        }
    }
}

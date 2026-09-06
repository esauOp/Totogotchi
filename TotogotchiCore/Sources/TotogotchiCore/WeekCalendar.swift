import Foundation

/// ISO-8601 week arithmetic in a fixed time zone.
///
/// Weeks run Monday 00:00:00 through Sunday 23:59:59 local time. The calendar is
/// pinned to `firstWeekday = 2` and `minimumDaysInFirstWeek = 4` so results do
/// not change with the user's locale.
public struct WeekCalendar: Sendable {
    private let calendar: Calendar

    public init(timeZone: TimeZone = .current, locale: Locale = Locale(identifier: "en_US_POSIX")) {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        calendar.locale = locale
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        self.calendar = calendar
    }

    public var timeZone: TimeZone { calendar.timeZone }

    private func interval(containing date: Date) -> DateInterval {
        // dateInterval(of: .weekOfYear,) is defined for every date on the ISO calendar.
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            preconditionFailure("ISO calendar produced no week interval for \(date)")
        }
        return interval
    }

    /// Monday 00:00:00 local time of the week containing `date`.
    public func startOfWeek(containing date: Date) -> Date {
        interval(containing: date).start
    }

    /// Sunday 23:59:59 local time of the week containing `date`.
    ///
    /// Derived from the week interval, so a week shortened or lengthened by a
    /// daylight-saving transition still ends on Sunday at 23:59:59 wall clock.
    public func endOfWeek(containing date: Date) -> Date {
        interval(containing: date).end.addingTimeInterval(-1)
    }

    /// True when `date` falls in the same ISO week as `reference`.
    public func contains(_ date: Date, weekOf reference: Date) -> Bool {
        let interval = interval(containing: reference)
        return date >= interval.start && date < interval.end
    }

    /// The due date a task gets when the user does not choose one: the end of the
    /// current week.
    public func defaultDueDate(now: Date) -> Date {
        endOfWeek(containing: now)
    }

    /// The ISO week-based year and week number for `date`.
    public func isoWeek(of date: Date) -> ISOWeek {
        ISOWeek(
            year: calendar.component(.yearForWeekOfYear, from: date),
            week: calendar.component(.weekOfYear, from: date)
        )
    }

    /// The same weekday one week later, at the same wall-clock time.
    public func sameWeekdayNextWeek(after date: Date) -> Date {
        guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: date) else {
            preconditionFailure("Could not add a week to \(date)")
        }
        return next
    }
}

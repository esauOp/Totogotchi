import Foundation
import Testing
import TotogotchiCore

@Suite("WeekCalendar")
struct WeekCalendarTests {

    @Test("A week runs Monday 00:00:00 to Sunday 23:59:59")
    func weekBoundaries() {
        let week = WeekCalendar(timeZone: TZ.utc)
        let midweek = makeDate(2026, 9, 9, 14, 30)

        let start = parts(of: week.startOfWeek(containing: midweek), in: TZ.utc)
        #expect(start.weekday == Weekday.monday)
        #expect(start.hour == 0)
        #expect(start.minute == 0)
        #expect(start.second == 0)

        let end = parts(of: week.endOfWeek(containing: midweek), in: TZ.utc)
        #expect(end.weekday == Weekday.sunday)
        #expect(end.hour == 23)
        #expect(end.minute == 59)
        #expect(end.second == 59)
    }

    @Test("Membership is half-open: the next Monday is a different week")
    func membership() {
        let week = WeekCalendar(timeZone: TZ.utc)
        let wednesday = makeDate(2026, 9, 9)
        let start = week.startOfWeek(containing: wednesday)

        #expect(week.contains(start, weekOf: wednesday))
        #expect(week.contains(week.endOfWeek(containing: wednesday), weekOf: wednesday))
        #expect(!week.contains(start.addingTimeInterval(7 * 86_400), weekOf: wednesday))
        #expect(!week.contains(start.addingTimeInterval(-1), weekOf: wednesday))
    }

    @Test("The week spanning New Year belongs to the year holding four of its days")
    func yearBoundary() {
        let week = WeekCalendar(timeZone: TZ.utc)

        // Mon 2026-12-28 through Sun 2027-01-03 has only three days in 2027,
        // so ISO-8601 assigns it to 2026 as week 53.
        #expect(week.isoWeek(of: makeDate(2026, 12, 29)) == ISOWeek(year: 2026, week: 53))
        #expect(week.isoWeek(of: makeDate(2027, 1, 3)) == ISOWeek(year: 2026, week: 53))
        #expect(week.isoWeek(of: makeDate(2027, 1, 4)) == ISOWeek(year: 2027, week: 1))

        #expect(week.startOfWeek(containing: makeDate(2027, 1, 1)) == makeDate(2026, 12, 28))
        #expect(week.endOfWeek(containing: makeDate(2026, 12, 29)) == makeDate(2027, 1, 3, 23, 59, 59))
    }

    @Test("A week shortened by a daylight-saving change still ends Sunday 23:59:59")
    func daylightSavingSpringForward() {
        let zone = TZ.losAngeles
        let week = WeekCalendar(timeZone: zone)
        // Clocks jump forward on Sunday 2026-03-08 at 02:00 local time.
        let inThatWeek = makeDate(2026, 3, 4, 12, 0, 0, in: zone)

        let start = week.startOfWeek(containing: inThatWeek)
        let end = week.endOfWeek(containing: inThatWeek)

        let startParts = parts(of: start, in: zone)
        #expect(startParts.month == 3)
        #expect(startParts.day == 2)
        #expect(startParts.hour == 0)

        let endParts = parts(of: end, in: zone)
        #expect(endParts.month == 3)
        #expect(endParts.day == 8)
        #expect(endParts.hour == 23)
        #expect(endParts.minute == 59)
        #expect(endParts.second == 59)

        // The week is one hour shorter than a standard week.
        #expect(end.timeIntervalSince(start) == 7 * 86_400 - 3_600 - 1)
    }

    @Test("A week lengthened by a daylight-saving change still ends Sunday 23:59:59")
    func daylightSavingFallBack() {
        let zone = TZ.losAngeles
        let week = WeekCalendar(timeZone: zone)
        // Clocks fall back on Sunday 2026-11-01 at 02:00 local time.
        let inThatWeek = makeDate(2026, 10, 28, 12, 0, 0, in: zone)

        let start = week.startOfWeek(containing: inThatWeek)
        let end = week.endOfWeek(containing: inThatWeek)

        let endParts = parts(of: end, in: zone)
        #expect(endParts.month == 11)
        #expect(endParts.day == 1)
        #expect(endParts.hour == 23)
        #expect(endParts.minute == 59)
        #expect(endParts.second == 59)
        #expect(end.timeIntervalSince(start) == 7 * 86_400 + 3_600 - 1)
    }

    @Test(
        "Week boundaries ignore the locale's own calendar and first weekday",
        arguments: ["en_US", "es_ES", "ar_SA@calendar=islamic", "fa_IR@calendar=persian"]
    )
    func localeIndependence(identifier: String) {
        let week = WeekCalendar(timeZone: TZ.utc, locale: Locale(identifier: identifier))
        let start = parts(of: week.startOfWeek(containing: makeDate(2026, 9, 9)), in: TZ.utc)

        #expect(start.weekday == Weekday.monday)
        #expect(start.year == 2026)
        #expect(start.month == 9)
        #expect(start.day == 7)
    }

    @Test("The default due date is the end of the current week")
    func defaultDueDate() {
        let week = WeekCalendar(timeZone: TZ.utc)
        let now = makeDate(2026, 9, 9, 10, 15)
        #expect(week.defaultDueDate(now: now) == makeDate(2026, 9, 13, 23, 59, 59))
    }

    @Test("Adding a week keeps the weekday and the wall-clock time across a DST change")
    func sameWeekdayNextWeek() {
        let zone = TZ.losAngeles
        let week = WeekCalendar(timeZone: zone)
        let friday = makeDate(2026, 3, 6, 9, 0, 0, in: zone)

        let next = parts(of: week.sameWeekdayNextWeek(after: friday), in: zone)
        #expect(next.month == 3)
        #expect(next.day == 13)
        #expect(next.hour == 9)
    }
}

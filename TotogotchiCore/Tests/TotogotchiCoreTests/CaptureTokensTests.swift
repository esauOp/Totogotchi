import Foundation
import Testing
import TotogotchiCore

@Suite("CaptureTokens")
struct CaptureTokensTests {

    private let calendar = WeekCalendar(timeZone: TZ.utc)

    /// Wednesday 9 September 2026, mid-morning.
    private let wednesday = makeDate(2026, 9, 9, 10, 0)
    /// Friday 11 September 2026.
    private let friday = makeDate(2026, 9, 11, 10, 0)

    private func parse(_ text: String, now: Date? = nil) -> ParsedCapture {
        CaptureTokens.parse(text, now: now ?? wednesday, calendar: calendar)
    }

    // MARK: - Priority

    @Test("A priority token sets the priority and leaves the title clean")
    func priorityToken() {
        let result = parse("Renew passport !high")
        #expect(result.title == "Renew passport")
        #expect(result.priority == .high)
        #expect(result.dueDate == nil)
    }

    @Test("A priority token is read anywhere in the text", arguments: [
        "!high Renew passport",
        "Renew !high passport",
        "Renew passport !high",
    ])
    func priorityAnywhere(text: String) {
        let result = parse(text)
        #expect(result.priority == .high)
        #expect(result.title.contains("Renew"))
        #expect(!result.title.contains("!high"))
    }

    @Test("The last priority token wins")
    func lastPriorityWins() {
        let result = parse("!low Fix bug !high")
        #expect(result.title == "Fix bug")
        #expect(result.priority == .high)
    }

    @Test("Each priority token maps to its level", arguments: [
        ("!high", Priority.high), ("!med", .medium), ("!low", .low),
    ])
    func everyPriorityToken(token: String, expected: Priority) {
        #expect(parse("Task \(token)").priority == expected)
    }

    @Test("Priority tokens are case-insensitive")
    func priorityCaseInsensitive() {
        #expect(parse("Task !HIGH").priority == .high)
    }

    // MARK: - Due dates

    @Test("A today token is due at the end of today")
    func todayToken() {
        let result = parse("Call bank @today")
        #expect(result.title == "Call bank")
        #expect(result.dueDate == makeDate(2026, 9, 9, 23, 59, 59))
    }

    @Test("A tomorrow token is due at the end of tomorrow")
    func tomorrowToken() {
        #expect(parse("Call bank @tomorrow").dueDate == makeDate(2026, 9, 10, 23, 59, 59))
    }

    @Test("A weekday later this week resolves forward")
    func weekdayForward() {
        // Wednesday, asking for Friday.
        let result = parse("Prepare demo @fri")
        #expect(result.title == "Prepare demo")
        #expect(result.dueDate == makeDate(2026, 9, 11, 23, 59, 59))
    }

    @Test("A weekday that is today means today")
    func weekdayToday() {
        // Friday, asking for Friday.
        let result = parse("Submit report @fri", now: friday)
        #expect(result.dueDate == makeDate(2026, 9, 11, 23, 59, 59))
    }

    @Test("A weekday already past this week falls in the next one")
    func weekdayNextWeek() {
        // Friday, asking for Monday.
        let result = parse("Plan sprint @mon", now: friday)
        #expect(result.dueDate == makeDate(2026, 9, 14, 23, 59, 59))
    }

    @Test("Every weekday token resolves to that weekday", arguments: [
        ("@wed", 9), ("@thu", 10), ("@fri", 11), ("@sat", 12),
        ("@sun", 13), ("@mon", 14), ("@tue", 15),
    ])
    func everyWeekday(token: String, expectedDay: Int) {
        // From Wednesday 9 September: today's own weekday means today, Thursday
        // through Sunday land later this week, and Monday and Tuesday have
        // already gone so they land in the next one.
        let result = parse("Task \(token)")
        #expect(result.dueDate == makeDate(2026, 9, expectedDay, 23, 59, 59))
    }

    // MARK: - Unknown tokens

    @Test("Unrecognised tokens stay in the title")
    func unknownTokensKept() {
        let result = parse("Email @maria about !urgent issue")
        #expect(result.title == "Email @maria about !urgent issue")
        #expect(result.priority == nil)
        #expect(result.dueDate == nil)
    }

    @Test("A bare marker is not a token")
    func bareMarkers() {
        let result = parse("Cost is 40 ! and @ signs")
        #expect(result.title == "Cost is 40 ! and @ signs")
    }

    // MARK: - Both together

    @Test("Priority and due date are read from the same line")
    func bothTokens() {
        let result = parse("Draft budget !high @fri")
        #expect(result.title == "Draft budget")
        #expect(result.priority == .high)
        #expect(result.dueDate == makeDate(2026, 9, 11, 23, 59, 59))
    }

    @Test("Text made only of tokens leaves an empty title")
    func onlyTokens() {
        let result = parse("!high @fri")
        #expect(result.title.isEmpty)
        #expect(result.priority == .high)
    }

    @Test("Extra spacing between words collapses")
    func spacingCollapses() {
        #expect(parse("Draft   budget  !high").title == "Draft budget")
    }
}

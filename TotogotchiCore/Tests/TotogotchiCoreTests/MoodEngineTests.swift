import Foundation
import Testing
import TotogotchiCore

@Suite("MoodEngine")
struct MoodEngineTests {

    private let week = ISOWeek(year: 2026, week: 37)
    private let due = makeDate(2026, 9, 11, 17, 0)
    private let now = makeDate(2026, 9, 9, 10, 0)

    /// Builds a week view with the shape the rules care about: how many are
    /// overdue, how many are still open, how many are done.
    private func view(overdue: Int, open: Int, completed: Int) throws -> WeekView {
        func tasks(_ count: Int, completed: Bool) throws -> [TaskItem] {
            try (0..<count).map { index in
                var task = try TaskItem(title: "Task \(index)", dueDate: due, createdAt: now)
                if completed { task.markCompleted(at: now, now: now) }
                return task
            }
        }
        return WeekView(
            week: week,
            overdue: try tasks(overdue, completed: false),
            thisWeek: try tasks(open, completed: false),
            completed: try tasks(completed, completed: true)
        )
    }

    private func mood(overdue: Int, open: Int, completed: Int, streak: Int) throws -> PetMood {
        MoodEngine.evaluate(
            weekView: try view(overdue: overdue, open: open, completed: completed),
            streakDays: streak
        ).mood
    }

    // MARK: - Rule order

    @Test("Everything done and something was due means celebrating")
    func celebrating() throws {
        #expect(try mood(overdue: 0, open: 0, completed: 5, streak: 0) == .celebrating)
    }

    @Test("An empty week is not celebrating, because nothing was achieved")
    func emptyWeekIsNotCelebrating() throws {
        #expect(try mood(overdue: 0, open: 0, completed: 0, streak: 0) == .neutral)
    }

    @Test("Three overdue is sad even when most of the week is done")
    func overdueBoundaryAtThree() throws {
        // Three overdue against nine completed is a 75% completion rate, which
        // would otherwise be happy. The overdue rule wins.
        #expect(try mood(overdue: 3, open: 0, completed: 9, streak: 0) == .sad)
    }

    @Test("One overdue is worried, not sad")
    func overdueBoundaryAtOne() throws {
        #expect(try mood(overdue: 1, open: 0, completed: 9, streak: 0) == .worried)
    }

    @Test("Two overdue is still worried")
    func twoOverdueIsWorried() throws {
        #expect(try mood(overdue: 2, open: 0, completed: 9, streak: 0) == .worried)
    }

    @Test("Overdue work outranks a long streak")
    func overdueBeatsStreak() throws {
        #expect(try mood(overdue: 1, open: 0, completed: 0, streak: 10) == .worried)
    }

    // MARK: - Completion rate boundary

    @Test("Exactly half the week done is happy")
    func completionRateAtHalf() throws {
        #expect(try mood(overdue: 0, open: 1, completed: 1, streak: 0) == .happy)
    }

    @Test("Just under half is neutral")
    func completionRateJustUnderHalf() throws {
        // 49 done out of 100 is 0.49, the boundary the spec names.
        let state = MoodEngine.evaluate(
            weekView: try view(overdue: 0, open: 51, completed: 49),
            streakDays: 2
        )
        #expect(state.completionRate == 0.49)
        #expect(state.mood == .neutral)
    }

    // MARK: - Streak boundary

    @Test("A three-day streak is happy even with little done")
    func streakBoundaryAtThree() throws {
        #expect(try mood(overdue: 0, open: 10, completed: 0, streak: 3) == .happy)
    }

    @Test("A two-day streak is not enough on its own")
    func streakBoundaryAtTwo() throws {
        #expect(try mood(overdue: 0, open: 10, completed: 0, streak: 2) == .neutral)
    }

    // MARK: - Reasons

    @Test("The worried reason names the overdue count and what to do")
    func worriedReason() throws {
        let state = MoodEngine.evaluate(
            weekView: try view(overdue: 2, open: 0, completed: 0),
            streakDays: 0
        )
        #expect(state.reason.contains("2 tasks overdue"))
        #expect(state.reason.contains("Clear one"))
    }

    @Test("One overdue task reads in the singular")
    func singularReason() throws {
        let state = MoodEngine.evaluate(
            weekView: try view(overdue: 1, open: 0, completed: 0),
            streakDays: 0
        )
        #expect(state.reason.contains("1 task overdue"))
    }

    @Test("The happy reason names the rate or the streak that earned it")
    func happyReason() throws {
        let byRate = MoodEngine.evaluate(
            weekView: try view(overdue: 0, open: 1, completed: 3),
            streakDays: 0
        )
        #expect(byRate.reason.contains("75%"))

        let byStreak = MoodEngine.evaluate(
            weekView: try view(overdue: 0, open: 10, completed: 0),
            streakDays: 4
        )
        #expect(byStreak.reason.contains("4 days"))
    }

    @Test("No reason blames the user")
    func reasonsAreNotBlaming() throws {
        let blaming = ["you failed", "you didn't", "you should have", "behind", "lazy"]
        for overdue in 0...4 {
            for streak in [0, 3] {
                let state = MoodEngine.evaluate(
                    weekView: try view(overdue: overdue, open: 2, completed: 2),
                    streakDays: streak
                )
                let lowered = state.reason.lowercased()
                for word in blaming {
                    #expect(!lowered.contains(word), "\(state.mood) reason: \(state.reason)")
                }
            }
        }
    }

    @Test("Every mood carries the numbers behind it")
    func stateCarriesNumbers() throws {
        let state = MoodEngine.evaluate(
            weekView: try view(overdue: 2, open: 1, completed: 1),
            streakDays: 7
        )
        #expect(state.overdueCount == 2)
        #expect(state.streakDays == 7)
        #expect(state.completionRate == 0.25)
    }
}

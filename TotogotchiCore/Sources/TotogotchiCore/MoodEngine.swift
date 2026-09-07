import Foundation

/// Turns the week's tasks into the pet's mood.
///
/// A pure function of its inputs: no clock, no store, no view. Every rule in
/// `specs/pet-mood` is a branch here and a test at its boundary.
public enum MoodEngine {
    /// Half the week's work done is enough to cheer the pet up.
    public static let happyCompletionRate = 0.5
    /// Three days of keeping up does it too, even with little completed.
    public static let happyStreakDays = 3
    /// Overdue work at or above this count is the pet's worst state.
    public static let sadOverdueCount = 3

    /// Applies the rules in order and returns the first that matches.
    public static func evaluate(weekView: WeekView, streakDays: Int) -> PetState {
        let overdue = weekView.overdueCount
        let rate = weekView.completionRate

        func state(_ mood: PetMood, _ reason: String) -> PetState {
            PetState(
                mood: mood,
                reason: reason,
                overdueCount: overdue,
                completionRate: rate,
                streakDays: streakDays
            )
        }

        if weekView.openCount == 0, weekView.completedCount > 0 {
            return state(.celebrating, "Everything due this week is done. Go and enjoy it.")
        }
        if overdue >= sadOverdueCount {
            return state(.sad, "\(taskCount(overdue)) overdue. Finishing any one of them will help.")
        }
        if overdue >= 1 {
            return state(.worried, "\(taskCount(overdue)) overdue. Clear one and the sloth settles down.")
        }
        if rate >= happyCompletionRate {
            return state(.happy, "\(percent(rate)) of this week is done. Nicely ahead.")
        }
        if streakDays >= happyStreakDays {
            return state(.happy, "\(dayCount(streakDays)) in a row keeping up. Keep it going.")
        }
        if weekView.isEmpty {
            return state(.neutral, "Nothing due this week. The sloth is dozing.")
        }
        return state(.neutral, "\(taskCount(weekView.openCount)) still to go this week. Nothing overdue.")
    }

    private static func taskCount(_ count: Int) -> String {
        count == 1 ? "1 task" : "\(count) tasks"
    }

    private static func dayCount(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    private static func percent(_ rate: Double) -> String {
        "\(Int((rate * 100).rounded()))%"
    }
}

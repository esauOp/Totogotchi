import Foundation

/// How the pet is feeling about the week.
///
/// Listed from best to worst, which is also the order `MoodEngine` tests its
/// rules in.
public enum PetMood: String, Codable, Sendable, CaseIterable {
    case celebrating
    case happy
    case neutral
    case worried
    case sad
}

/// The pet's mood together with why it holds it.
///
/// The reason travels with the mood, so a tooltip can never explain a state the
/// engine did not produce.
public struct PetState: Equatable, Sendable {
    public let mood: PetMood
    /// One sentence the user reads on hover. Names the cause and, when there is
    /// something to do about it, the next action.
    public let reason: String
    public let overdueCount: Int
    public let completionRate: Double
    public let streakDays: Int

    public init(
        mood: PetMood,
        reason: String,
        overdueCount: Int,
        completionRate: Double,
        streakDays: Int
    ) {
        self.mood = mood
        self.reason = reason
        self.overdueCount = overdueCount
        self.completionRate = completionRate
        self.streakDays = streakDays
    }
}

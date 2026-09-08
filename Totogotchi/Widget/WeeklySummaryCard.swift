import SwiftUI
import TotogotchiCore

/// How the week went, over the task list.
///
/// This is where PRD §8's primary metric becomes something the owner actually
/// sees. The guardrail sits beside it deliberately: a completion rate is easy to
/// make perfect by deleting or deferring, and showing both together is the only
/// thing that makes the number mean anything.
struct WeeklySummaryCard: View {
    let stats: WeeklyStats
    let streakDays: Int
    let mood: PetMood
    let reason: String
    let canStartNextWeek: Bool
    let onDismiss: () -> Void

    private var total: Int { stats.due + stats.completed }

    var body: some View {
        VStack(spacing: 14) {
            PetView(mood: mood, reason: reason, isStirring: true)
                .frame(height: 90)

            Text("Week \(stats.week.week)")
                .font(.headline)

            if total == 0 {
                Text("Nothing was due this week.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(percentText)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                figures
            }

            if stats.deleted + stats.deferred > 0 {
                guardrail
            }

            HStack(spacing: 10) {
                Button(canStartNextWeek ? "Start Next Week" : "Dismiss", action: onDismiss)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(spokenSummary)
    }

    private var figures: some View {
        HStack(spacing: 18) {
            figure("\(stats.completed)", "done")
            figure("\(stats.due)", stats.due == 1 ? "left" : "left")
            figure("\(streakDays)", streakDays == 1 ? "day streak" : "day streak")
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.title3.weight(.medium))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Shown only when something actually slipped, so a clean week is not
    /// cluttered by a zero.
    private var guardrail: some View {
        Label(
            "\(stats.deleted + stats.deferred) deleted or moved to a later week",
            systemImage: "arrow.uturn.right"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }

    private var percentText: String {
        "\(Int((stats.completionRate * 100).rounded()))%"
    }

    private var spokenSummary: String {
        guard total > 0 else { return "Week \(stats.week.week). Nothing was due." }
        var parts = [
            "Week \(stats.week.week)",
            "\(percentText) done",
            "\(stats.completed) completed",
            "\(stats.due) still to go",
            "\(streakDays) day streak",
        ]
        if stats.deleted + stats.deferred > 0 {
            parts.append("\(stats.deleted + stats.deferred) deleted or moved to a later week")
        }
        return parts.joined(separator: ", ")
    }
}

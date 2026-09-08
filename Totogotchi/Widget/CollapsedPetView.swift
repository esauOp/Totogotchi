import SwiftUI
import TotogotchiCore

/// The widget shrunk to the pet alone, with a count of what is overdue.
///
/// Observes the model rather than taking a snapshot: the panel's content view is
/// built once when the widget collapses, so fixed values would leave the pet
/// showing whatever mood it happened to hold at that moment.
struct CollapsedPetView: View {
    @ObservedObject var model: WidgetViewModel
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)

                PetView(
                    mood: model.displayedMood,
                    reason: model.petState.reason,
                    isAnimating: model.isPetAnimating,
                    isStirring: model.isPetStirring,
                    isAttentive: model.isCapturing
                )
                .padding(8)

                if model.overdueCount > 0 {
                    Text("\(model.overdueCount)")
                        .font(.caption.bold())
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.orange))
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 120, height: 120)
        .help(model.petState.reason)
        .accessibilityLabel(
            "Totogotchi. \(model.displayedMood.displayName). \(model.petState.reason) Click to expand."
        )
    }
}

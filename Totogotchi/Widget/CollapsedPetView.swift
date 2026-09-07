import SwiftUI

/// The widget shrunk to the pet alone, with a count of what is overdue.
///
/// The pet is a placeholder until `add-pet-mood-and-reminders` gives it moods
/// and artwork.
struct CollapsedPetView: View {
    let overdueCount: Int
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)

                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(22)
                    .foregroundStyle(.tint)

                if overdueCount > 0 {
                    Text("\(overdueCount)")
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
        .accessibilityLabel(
            overdueCount > 0
                ? "Totogotchi, \(overdueCount) tasks overdue. Click to expand"
                : "Totogotchi. Click to expand"
        )
    }
}

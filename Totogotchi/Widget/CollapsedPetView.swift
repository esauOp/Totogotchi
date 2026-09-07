import SwiftUI
import TotogotchiCore

/// The widget shrunk to the pet alone, with a count of what is overdue.
struct CollapsedPetView: View {
    let mood: PetMood
    let reason: String
    let overdueCount: Int
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)

                Image(mood.assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(8)

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
        .help(reason)
        .accessibilityLabel("Totogotchi. \(mood.displayName). \(reason) Click to expand.")
    }
}

import SwiftUI
import TotogotchiCore

extension PetMood {
    /// The image in `Assets.xcassets` for this mood. All five share one canvas
    /// and a baseline, so the sloth's body does not change size or shift as the
    /// mood changes.
    var assetName: String {
        switch self {
        case .celebrating: "PetCelebrating"
        case .happy: "PetHappy"
        case .neutral: "PetNeutral"
        case .worried: "PetWorried"
        case .sad: "PetSad"
        }
    }

    /// How the mood is spoken to assistive technology.
    var displayName: String {
        switch self {
        case .celebrating: "Celebrating"
        case .happy: "Happy"
        case .neutral: "Dozing"
        case .worried: "Worried"
        case .sad: "Sad"
        }
    }
}

/// The sloth, at whatever size it is given.
struct PetView: View {
    let mood: PetMood
    let reason: String

    var body: some View {
        Image(mood.assetName)
            .resizable()
            .scaledToFit()
            .help(reason)
            .accessibilityLabel("\(mood.displayName). \(reason)")
    }
}

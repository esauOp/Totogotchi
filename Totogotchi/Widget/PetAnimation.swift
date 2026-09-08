import SwiftUI
import TotogotchiCore

/// The motion a mood is drawn with.
///
/// The supplied art is one still per mood, with no animation frames, so each
/// mood is animated by transforming its still rather than by playing a sequence.
/// Frame art would look better; if it ever arrives, only this type changes.
struct PetAnimation {
    /// Seconds for one full cycle.
    let period: Double
    let verticalOffset: CGFloat
    let horizontalOffset: CGFloat
    let verticalScale: CGFloat
    let rotationDegrees: Double

    /// How often the pose is stepped, in frames per second.
    ///
    /// Deliberately low. A continuous SwiftUI animation redraws at the display's
    /// refresh rate, and because an animating layer forces the whole panel to
    /// recomposite, that measured about 5% CPU against a 1% budget. Stepping
    /// discretely at a sprite-animation cadence costs a fraction of that, and
    /// eight to twelve frames a second is what pixel art has always run at.
    var frameRate: Double { 10 }

    static func idle(for mood: PetMood) -> PetAnimation {
        switch mood {
        case .neutral:
            // Dozing: a slow breath, nothing more.
            PetAnimation(period: 5.0, verticalOffset: 0, horizontalOffset: 0, verticalScale: 0.035, rotationDegrees: 0)
        case .happy:
            // Content: a gentle bob.
            PetAnimation(period: 2.4, verticalOffset: -5, horizontalOffset: 0, verticalScale: 0.02, rotationDegrees: 0)
        case .celebrating:
            // Delighted: a bigger bounce with a little sway.
            PetAnimation(period: 0.9, verticalOffset: -11, horizontalOffset: 0, verticalScale: 0.035, rotationDegrees: 4)
        case .worried:
            // Fidgeting: a small, quick side-to-side.
            PetAnimation(period: 0.6, verticalOffset: 0, horizontalOffset: 2.5, verticalScale: 0, rotationDegrees: 0)
        case .sad:
            // Deflating: a slow sink.
            PetAnimation(period: 4.4, verticalOffset: 4, horizontalOffset: 0, verticalScale: -0.025, rotationDegrees: 0)
        }
    }

    /// The pose at a moment in the cycle, as a value swinging between -1 and 1.
    func swing(at date: Date) -> Double {
        let position = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        return sin(position * 2 * .pi)
    }
}

/// The sloth, at whatever size it is given, moving if it is allowed to.
struct PetView: View {
    let mood: PetMood
    let reason: String
    /// False while the widget is covered, hidden, or on another Space.
    var isAnimating: Bool = true
    /// True for the few seconds after something happened. The pet does not loop
    /// an idle; see `specs/pet-mood`.
    var isStirring: Bool = false
    /// True while the capture field is open, which leans the pet towards it.
    var isAttentive: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motion: PetAnimation { .idle(for: mood) }
    private var moves: Bool { isAnimating && !reduceMotion && (isStirring || isAttentive) }

    var body: some View {
        Group {
            if moves {
                // A periodic timeline steps the pose instead of interpolating
                // between two states, which is what keeps the cost down.
                TimelineView(.periodic(from: .now, by: 1 / motion.frameRate)) { context in
                    pet(swing: motion.swing(at: context.date))
                }
            } else {
                pet(swing: 0)
            }
        }
        .help(reason)
        .accessibilityLabel("\(mood.displayName). \(reason)")
    }

    private func pet(swing: Double) -> some View {
        Image(mood.assetName)
            .resizable()
            .scaledToFit()
            .scaleEffect(x: 1, y: 1 + motion.verticalScale * swing, anchor: .bottom)
            .offset(
                x: motion.horizontalOffset * swing,
                y: motion.verticalOffset * swing
            )
            .rotationEffect(.degrees(motion.rotationDegrees * swing), anchor: .bottom)
            // The attentive lean sits on top of the idle so it reads even while
            // the idle is running.
            .rotationEffect(isAttentive && !reduceMotion ? .degrees(-6) : .zero, anchor: .bottom)
            .scaleEffect(isAttentive && !reduceMotion ? 1.06 : 1, anchor: .bottom)
            .animation(.easeOut(duration: 0.2), value: isAttentive)
    }
}

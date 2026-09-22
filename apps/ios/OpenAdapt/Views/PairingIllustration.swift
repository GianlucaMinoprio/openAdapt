import SwiftUI

/// Keep the same shoe in place throughout setup; only its lights ask for attention.
struct PairingIllustration: View {
    let confirming: Bool
    let complete: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private var reduced: Bool { AdaptMotion.reduced(system: systemReduceMotion) }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !confirming || reduced || scenePhase != .active)) { context in
            // A slow, low-contrast light cue explains the physical button to press.
            // Reduced Motion and inactive scenes hold it steady.
            let pulsing = confirming && !reduced && scenePhase == .active
            let glow = pulsing ? 0.75 + 0.25 * sin(context.date.timeIntervalSinceReferenceDate * .pi) : 1
            ZStack {
                GeometryReader { geometry in
                    ZStack {
                        Image("Sneaker").resizable().renderingMode(.template).foregroundStyle(.primary)
                        Image("ShoeLights").resizable().renderingMode(.template).foregroundStyle(.cyan).opacity(glow)
                    }.frame(width: geometry.size.width, height: geometry.size.width)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36, weight: .medium)).foregroundStyle(.green)
                    .background(Color(uiColor: .systemBackground), in: Circle())
                    .opacity(complete ? 1 : 0).scaleEffect(complete || reduced ? 1 : 0.95)
                    .offset(y: 84)
                    .animation(reduced ? .easeOut(duration: 0.15) : AdaptMotion.state, value: complete)
            }.frame(maxWidth: 420)
        }.accessibilityHidden(true)
    }
}

import SwiftUI

/// Native equivalents of the review-animations timing and strong ease-out tokens.
enum AdaptMotion {
    static func reduced(system: Bool) -> Bool {
        #if DEBUG
        return system || ProcessInfo.processInfo.arguments.contains("--reduce-motion")
        #else
        return system
        #endif
    }
    static func response(_ duration: Double) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: duration)
    }
    static let state = response(0.20)
    static let settle = response(0.20)
    static let lacingEstimate: TimeInterval = 2.8
}

struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AdaptMotion.reduced(system: systemReduceMotion) }
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .opacity(!enabled ? 0.35 : configuration.isPressed ? 0.7 : 1)
            .animation(AdaptMotion.response(configuration.isPressed ? 0.16 : 0.10), value: configuration.isPressed)
    }
}

struct ShoeIllustration: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.primary.opacity(0.035)).frame(width: 240, height: 240)
            SneakerMark().frame(width: 190, height: 190)
                .rotationEffect(.degrees(-12)).offset(x: -24, y: -23).opacity(0.16)
            SneakerMark().frame(width: 190, height: 190)
                .rotationEffect(.degrees(-12)).offset(x: 16, y: 25)
        }.frame(maxWidth: .infinity).frame(height: 250).accessibilityHidden(true)
    }
}

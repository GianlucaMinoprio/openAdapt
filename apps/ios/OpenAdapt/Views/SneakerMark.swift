import SwiftUI

/// The upper follows the surrounding UI ink; the two signature lamps stay blue.
struct SneakerMark: View {
    var body: some View {
        ZStack {
            Image("Sneaker").resizable().renderingMode(.template).scaledToFit()
            Image("ShoeLights").resizable().renderingMode(.original).scaledToFit()
        }.accessibilityHidden(true)
    }
}

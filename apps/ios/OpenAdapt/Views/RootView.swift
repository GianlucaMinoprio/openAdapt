import SwiftUI

private enum AppSheet: String, Identifiable {
    case shoes, lights, battery, modes, settings
    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { AdaptMotion.reduced(system: systemReduceMotion) }
    @State private var sheet: AppSheet?
    @State private var dockSelection: AppSheet?
    @GestureState private var dockDragX: CGFloat?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let dockOptions: [AppSheet] = [.lights, .battery, .modes]
    private let dockItemWidth: CGFloat = 74
    private let dockItemSpacing: CGFloat = 2
    private let dockInset: CGFloat = 6
    var body: some View {
        ZStack {
            AdaptBackground(lightColor: store.activeLightColor?.color)
            if store.pair != nil || store.demo {
                controller
            } else {
                WelcomeView { sheet = .shoes }
            }
        }
        .disabled(store.shortcutRunning)
        .overlay(alignment: .bottom) {
            if store.shortcutRunning {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Running shortcut").font(.subheadline)
                    Button("Cancel") { store.disconnect() }.font(.subheadline.weight(.semibold))
                }.padding().background(.regularMaterial, in: Capsule()).padding(.bottom, 12)
            }
        }
        .preferredColorScheme(store.canvasUsesDarkInk ? .light : .dark)
        .sheet(item: $sheet) { destination in
            Group { switch destination {
            case .shoes: ShoesView()
            case .lights: LightsView()
            case .battery: BatteryView()
            case .modes: ModesView()
            case .settings: SettingsView()
            } }.preferredColorScheme(store.canvasUsesDarkInk ? .light : .dark)
        }
        .alert("OpenAdapt", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .task { store.foreground() }
    }
    private var controller: some View {
        VStack(spacing: 0) {
            HStack {
                CircleButton(symbol: "", asset: "Sneaker", label: "My shoes", foreground: store.canvasInk) { sheet = .shoes }
                    .accessibilityHint("Choose a saved pair or add shoes")
                Spacer()
                Text("OpenAdapt").font(.system(size: 20, weight: .bold, design: .rounded)).tracking(-0.7)
                Spacer()
                CircleButton(symbol: "gearshape", label: "Settings", foreground: store.canvasInk) { sheet = .settings }
            }.padding(.horizontal, 24).padding(.top, 10)
            VStack(spacing: 7) {
                Text(store.name.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(3)
                HStack(spacing: 6) {
                    Circle().fill(store.canvasInk).frame(width: 5, height: 5)
                    Text(store.demo ? "DEMO · NO SHOES CONNECTED" : store.connected ? "CONNECTED" : store.hasReadyShoe ? "ONE SHOE CONNECTED" : "")
                        .font(.system(size: 9, weight: .semibold)).tracking(1.6)
                }.opacity(store.hasReadyShoe || store.demo ? 0.7 : 0)
            }.padding(.top, 25)
            FitControlView().padding(.horizontal, 12).padding(.top, 14)
            ZStack(alignment: .bottom) {
            if store.hasReadyShoe {
            VStack(spacing: 0) {
            HStack(spacing: 0) {
                fitReadout(.left)
                Spacer()
                Text("DRAG TO\nADJUST FIT")
                    .font(.system(size: 9, weight: .semibold)).tracking(1.6).multilineTextAlignment(.center)
                    .foregroundStyle(store.canvasInk.opacity(0.65))
                    .opacity(store.feet.values.contains(where: \.lacing) ? 0 : 1)
                    .accessibilityHidden(store.feet.values.contains(where: \.lacing))
                    .accessibilityLabel("Adjust left and right independently")
                Spacer()
                fitReadout(.right)
            }.padding(.horizontal, 32).padding(.bottom, 26)
            dock.padding(.bottom, 18)
            }.transition(.opacity)
            } else {
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        if store.connectionInProgress && !reduceMotion { ProgressView().tint(store.canvasInk) }
                        Text(store.connectionTitle)
                            .font(.title3.weight(.semibold)).accessibilityIdentifier("connection-status")
                    }
                    Text(store.connectionInProgress ? "Keep your shoes close to your iPhone." : store.connectionMessage)
                        .font(.subheadline).foregroundStyle(store.canvasInk.opacity(0.55)).multilineTextAlignment(.center)
                    if store.pairs.count > 1 && !store.connectionInProgress {
                        Text("Choose another pair in My shoes.")
                            .font(.footnote).foregroundStyle(store.canvasInk.opacity(0.65))
                    }
                    Button(store.connectionInProgress ? "Cancel" : "Connect shoes") {
                        if store.connectionInProgress { store.disconnect() }
                        else if store.canReconnect { store.reconnectSavedPair() }
                        else { sheet = .shoes }
                    }.font(.subheadline.weight(.medium)).frame(minWidth: 100, minHeight: 44)
                        .buttonStyle(TactileButtonStyle()).accessibilityIdentifier("connection-action")
                }.frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.bottom, 28)
                    .transition(.opacity).animation(AdaptMotion.state, value: store.connectionInProgress)
            }
            }.frame(height: 190).animation(AdaptMotion.state, value: store.hasReadyShoe)
        }.foregroundStyle(store.canvasInk)
    }
    @ViewBuilder private var dock: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            dockContent
                // One glass lens moves over a quiet tint, without stacking glass surfaces.
                .background(store.canvasInk.opacity(0.07), in: Capsule())
                .overlay(Capsule().stroke(store.canvasInk.opacity(0.10), lineWidth: 0.5))
        } else {
            dockContent
                .background {
                    if reduceTransparency {
                        Capsule().fill(Color(uiColor: .secondarySystemBackground))
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
                .overlay(Capsule().stroke(store.canvasInk.opacity(0.13), lineWidth: 0.5))
        }
    }
    private var dockContent: some View {
        dockButtons
        .background(alignment: .leading) {
            if dockSelection != nil || dockDragX != nil {
                dockLens
                    .frame(width: dockItemWidth, height: 62)
                    .offset(x: (dockDragX ?? dockCenter(for: dockSelection ?? .lights)) - dockItemWidth / 2)
                    .animation(dockDragX != nil || reduceMotion ? nil : .smooth(duration: 0.25, extraBounce: 0), value: dockDragX == nil)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Capsule())
        .highPriorityGesture(
            DragGesture(minimumDistance: 8)
                .updating($dockDragX) { value, position, transaction in
                    // Keep the original finger-to-lens offset; direct tracking has no easing.
                    transaction.animation = nil
                    position = dockPosition(for: value)
                }
                .onEnded { value in
                    // Releasing outside the dock cancels without opening any panel.
                    let bounds = CGRect(x: -20, y: -20, width: 278, height: 114)
                    guard bounds.contains(value.location) else { return }
                    let destination = dockOption(at: dockPosition(for: value))
                    selectDock(destination)
                    sheet = destination
                }
        )
    }
    @ViewBuilder private var dockLens: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            Color.clear.glassEffect(.regular, in: Capsule())
        } else {
            Capsule().fill(store.canvasInk.opacity(0.12))
        }
    }
    private func dockCenter(for destination: AppSheet) -> CGFloat {
        dockInset + dockItemWidth / 2 + CGFloat(dockOptions.firstIndex(of: destination) ?? 0) * (dockItemWidth + dockItemSpacing)
    }
    private func dockOption(at x: CGFloat) -> AppSheet {
        let index = Int(((x - dockCenter(for: .lights)) / (dockItemWidth + dockItemSpacing)).rounded())
        return dockOptions[min(2, max(0, index))]
    }
    private func dockPosition(for value: DragGesture.Value) -> CGFloat {
        let start = dockCenter(for: dockOption(at: value.startLocation.x))
        return min(dockCenter(for: .modes), max(dockCenter(for: .lights), start + value.translation.width))
    }
    private var dockButtons: some View {
        HStack(spacing: dockItemSpacing) {
            dockButton(.lights, symbol: store.activeLightColor == nil ? "circle" : "circle.inset.filled", label: "Lights")
                .accessibilityValue(store.activeLightColor?.name ?? "Off")
            dockButton(.battery, symbol: "battery.75percent", label: "Battery")
            dockButton(.modes, symbol: "slider.horizontal.3", label: "Modes")
        }.padding(dockInset)
    }
    private func dockButton(_ destination: AppSheet, symbol: String, label: String) -> some View {
        Button {
            selectDock(destination)
            sheet = destination
        } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 23, weight: .regular))
                    .frame(height: 29)
                Text(label).font(.system(size: 10, weight: .medium))
            }.frame(width: dockItemWidth, height: 62)
                .foregroundStyle(store.canvasInk)
                .contentShape(Capsule())
        }
        .buttonStyle(DockPressStyle(onPress: { selectDock(destination) }))
        .accessibilityLabel(label)
        .accessibilityHint("Opens \(label.lowercased()). You can also slide across the bottom controls.")
    }
    private func selectDock(_ destination: AppSheet) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25, extraBounce: 0)) {
            dockSelection = destination
        }
    }
    private func fitReadout(_ side: ShoeSide) -> some View {
        let foot = store.feet[side]!
        return VStack(alignment: side == .left ? .leading : .trailing, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(foot.connected && foot.hasFitCalibration ? "\(foot.target)" : "—").font(.system(size: 32, weight: .medium, design: .rounded)).monospacedDigit()
                Text("%").font(.system(size: 13)).opacity(0.6)
            }
            Text(foot.connected && !foot.hasFitCalibration ? "FIT SETUP NEEDED" : "\(side.title.uppercased()) FIT").font(.system(size: 9, weight: .semibold)).tracking(1.7).opacity(0.65)
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(side.title) requested fit").accessibilityValue("\(foot.target) percent")
    }
}

struct AdaptBackground: View {
    var lightColor: Color?
    var body: some View {
        ZStack {
            lightColor ?? .white
            if lightColor != nil {
                // Neutral overlays retain the actual selected hue.
                RadialGradient(colors: [.white.opacity(0.12), .clear], center: .bottomLeading,
                               startRadius: 0, endRadius: 650)
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct CircleButton: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let symbol: String
    var asset: String?
    let label: String
    var foreground: Color = .white
    let action: () -> Void
    @ViewBuilder var body: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            button.buttonStyle(.glass).buttonBorderShape(.circle)
        } else {
            button.background(reduceTransparency ? Color(uiColor: .secondarySystemBackground) : foreground.opacity(0.08), in: Circle())
                .buttonStyle(TactileButtonStyle())
        }
    }
    private var button: some View {
        Button(action: action) {
            Group {
                if asset == "Sneaker" { SneakerMark().frame(width: 27, height: 27) }
                else if let asset { Image(asset).resizable().scaledToFit().frame(width: 27, height: 27) }
                else { Image(systemName: symbol).font(.system(size: 18, weight: .medium)) }
            }.frame(width: 44, height: 44)
        }.foregroundStyle(foreground).accessibilityLabel(label)
    }
}

private struct DockPressStyle: ButtonStyle {
    let onPress: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.35)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && isEnabled { onPress() }
            }
    }
}

struct WelcomeView: View {
    let openShoes: () -> Void
    var body: some View {
        GeometryReader { geometry in
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            Text("OpenAdapt").font(.system(size: 23, weight: .bold, design: .rounded)).tracking(-1).padding(.top, 22)
            Spacer(minLength: 24)
            ZStack {
                Circle().stroke(.black.opacity(0.14), lineWidth: 1).frame(width: 200, height: 200)
                Circle().stroke(.black.opacity(0.08), lineWidth: 1).frame(width: 260, height: 260)
                SneakerMark()
                    .frame(width: 200, height: 200).foregroundStyle(.black)
            }.frame(maxWidth: .infinity).frame(height: 260).accessibilityHidden(true)
            Spacer(minLength: 24)
            Text("Your shoes.\nYour control.").font(.system(size: 43, weight: .bold)).tracking(-1.8).lineSpacing(-1)
                .minimumScaleFactor(0.8)
            Text("A new connection to your Adapt shoes.\nIndependent. Open source. On your iPhone.")
                .font(.system(size: 15)).foregroundStyle(.black.opacity(0.7)).lineSpacing(5).padding(.top, 18)
            Button(action: openShoes) {
                HStack { Text("Connect your shoes"); Spacer(); Image(systemName: "arrow.up.right") }
                    .font(.system(size: 17, weight: .semibold)).padding(21)
                    .foregroundStyle(.white).background(.black, in: RoundedRectangle(cornerRadius: 20))
            }.padding(.top, 34).accessibilityIdentifier("connect-shoes")
            Text("INDEPENDENT BY DESIGN").font(.system(size: 9, weight: .medium)).tracking(1.7)
                .foregroundStyle(.black.opacity(0.55)).frame(maxWidth: .infinity).padding(.top, 17).padding(.bottom, 20)
        }.frame(minHeight: geometry.size.height).padding(.horizontal, 30).foregroundStyle(.black)
        }.scrollIndicators(.hidden)
        }
    }
}

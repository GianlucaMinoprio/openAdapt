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
                Text(store.linked ? "ADJUST\nTOGETHER" : "DRAG TO\nADJUST FIT")
                    .font(.system(size: 9, weight: .semibold)).tracking(1.6).multilineTextAlignment(.center)
                    .foregroundStyle(store.canvasInk.opacity(0.65))
                    .opacity(store.feet.values.contains(where: \.lacing) ? 0 : 1)
                    .accessibilityHidden(store.feet.values.contains(where: \.lacing))
                    .accessibilityLabel(store.linked ? "Shoes linked" : "Adjust left and right independently")
                Spacer()
                fitReadout(.right)
            }.padding(.horizontal, 32).padding(.bottom, 26)
            HStack(spacing: 22) {
                DockButton(symbol: "link", label: "Link", selected: store.linked, foreground: store.canvasInk) { store.toggleLink() }
                    .accessibilityValue(store.linked ? "On" : "Off").disabled(!store.connected || store.anyBusy || store.feet.values.contains(where: \.dragging))
                DockButton(symbol: store.activeLightColor == nil ? "circle" : "circle.inset.filled", label: "Lights", dot: store.activeLightColor == nil ? nil : store.canvasInk, foreground: store.canvasInk) { sheet = .lights }
                    .accessibilityValue(store.activeLightColor?.name ?? "Off")
                DockButton(symbol: "battery.75percent", label: "Battery", foreground: store.canvasInk) { sheet = .battery }
                DockButton(symbol: "slider.horizontal.3", label: "Modes", foreground: store.canvasInk) { sheet = .modes }
            }.padding(.horizontal, 26).padding(.vertical, 16)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(store.canvasInk.opacity(0.13), lineWidth: 0.5))
                .padding(.bottom, 18)
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
    private func fitReadout(_ side: ShoeSide) -> some View {
        let foot = store.feet[side]!
        return VStack(alignment: side == .left ? .leading : .trailing, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(foot.connected ? "\(foot.target)" : "—").font(.system(size: 32, weight: .medium, design: .rounded)).monospacedDigit()
                Text("%").font(.system(size: 13)).opacity(0.6)
            }
            Text("\(side.title.uppercased()) FIT").font(.system(size: 9, weight: .semibold)).tracking(1.7).opacity(0.65)
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
    let symbol: String
    var asset: String?
    let label: String
    var foreground: Color = .white
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if asset == "Sneaker" { SneakerMark().frame(width: 27, height: 27) }
                else if let asset { Image(asset).resizable().scaledToFit().frame(width: 27, height: 27) }
                else { Image(systemName: symbol).font(.system(size: 18, weight: .medium)) }
            }.frame(width: 44, height: 44)
        }.foregroundStyle(foreground).background(foreground.opacity(0.05), in: Circle()).accessibilityLabel(label)
            .buttonStyle(TactileButtonStyle())
    }
}

struct DockButton: View {
    let symbol: String
    let label: String
    var selected = false
    var dot: Color?
    var foreground: Color = .white
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 23, weight: .regular))
                    .foregroundStyle(dot ?? foreground).frame(width: 42, height: 29)
                Text(label).font(.system(size: 10, weight: .medium)).opacity(selected ? 1 : 0.65)
            }.frame(minWidth: 44, minHeight: 46)
                .foregroundStyle(foreground)
                .background(selected ? foreground.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(TactileButtonStyle()).accessibilityLabel(label)
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

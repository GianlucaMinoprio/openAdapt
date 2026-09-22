import SwiftUI

extension ShoeColorway {
    var upper: Color {
        switch self {
        case .whiteBlack, .whiteRed: return Color(white: 0.86)
        case .greyRed: return Color(white: 0.50)
        case .navyBlue: return Color(red: 0.09, green: 0.15, blue: 0.25)
        default: return Color(white: 0.12)
        }
    }
    var sole: Color {
        switch self {
        case .blackTeal: return Color(red: 0.06, green: 0.34, blue: 0.35)
        case .whiteBlack: return Color(white: 0.18)
        default: return Color(white: 0.35)
        }
    }
    var accent: Color { self == .greyRed || self == .whiteRed ? .red : self == .blackTeal ? .cyan : .blue }
}

/// Reuses our original silhouette. Appearance is local and never changes LEDs.
struct ShoePortrait: View {
    var colorway: ShoeColorway = .blackBlue
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, 440.0)
            ZStack {
                Image("Sneaker").resizable().renderingMode(.template).foregroundStyle(colorway.upper.gradient)
                Image("Sneaker").resizable().renderingMode(.template).foregroundStyle(colorway.sole)
                    .mask(alignment: .bottom) { Rectangle().frame(height: size * 0.41) }
                Image("ShoeLights").resizable().renderingMode(.template).foregroundStyle(colorway.accent)
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.08), radius: 10, y: 8)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }.frame(height: 180).accessibilityHidden(true)
    }
}

struct ShoesView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        SheetPage(title: "My shoes") {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if store.pairs.isEmpty {
                        ContentUnavailableView("Your shoes belong here", systemImage: "shoeprints.fill",
                            description: Text("Add a pair to get started."))
                    }
                    ForEach(store.pairs) { pair in
                        NavigationLink { ShoeDetailView(pairID: pair.id) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ConnectionBadge(pairID: pair.id)
                                Text(pair.displayName).font(.title3.bold()).foregroundStyle(.primary)
                                if let subtitle = pair.modelSubtitle {
                                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                                }
                                ShoePortrait(colorway: store.colorway(for: pair.id))
                            }.padding(20).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
                        }.buttonStyle(.plain).accessibilityIdentifier("shoe-card-\(pair.id)")
                    }
                    NavigationLink { PairingGuideView() } label: {
                        Image(systemName: "plus").font(.title2.weight(.medium))
                            .frame(maxWidth: .infinity).frame(height: 62)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                    }.accessibilityLabel("Add shoes").accessibilityIdentifier("add-shoes")
                    NavigationLink("Connection help") { ConnectionHelpView() }
                        .font(.subheadline).frame(minHeight: 44)
                }.padding(20)
            }.background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

private struct ConnectionBadge: View {
    @EnvironmentObject private var store: AppStore
    let pairID: String
    private var selected: Bool { store.selectedID == pairID }
    private var title: String {
        guard selected else { return "Not connected" }
        if store.connectionInProgress { return "Connecting" }
        return store.connected ? "Connected" : store.hasReadyShoe ? "One shoe connected" : "Not connected"
    }
    var body: some View {
        Label(title, systemImage: selected && store.connected ? "checkmark.circle.fill" : "circle")
            .font(.caption.weight(.medium)).foregroundStyle(selected && store.connected ? Color.green : .secondary)
    }
}

struct ShoeDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let pairID: String
    @State private var removing = false
    private var pair: ShoePair? { store.pairs.first { $0.id == pairID } }
    private var selected: Bool { store.selectedID == pairID }
    private var ready: Bool { selected && store.hasReadyShoe }
    var body: some View {
        Group {
            if let pair {
                if ready { connectedDetails(pair) }
                else { disconnectedDetails(pair) }
            } else { ContentUnavailableView("Pair removed", systemImage: "shoeprints.fill") }
        }
        .navigationTitle(pair?.displayName ?? "Shoes").navigationBarTitleDisplayMode(.inline)
        .alert("Remove \(pair?.displayName ?? "these shoes")?", isPresented: $removing) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                store.removePair(pairID)
                if !store.pairs.contains(where: { $0.id == pairID }) { dismiss() }
            }.accessibilityIdentifier("confirm-remove-shoes")
        } message: {
            Text("This removes the saved pairing from OpenAdapt on this iPhone. Shoe settings and iPhone Bluetooth pairing stay unchanged. Adding this pair again currently requires its saved pairing credentials.")
        }
    }
    private func connectedDetails(_ pair: ShoePair) -> some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    ConnectionBadge(pairID: pairID)
                    ShoePortrait(colorway: store.colorway(for: pairID))
                }.listRowBackground(Color.clear)
            }
            Section {
                NavigationLink { ShoeNicknameView(pairID: pairID, name: pair.displayName) } label: {
                    LabeledContent("Nickname", value: pair.displayName)
                }.accessibilityIdentifier("shoe-nickname")
                NavigationLink { ShoeColorView(pairID: pairID) } label: {
                    LabeledContent("Shoe color", value: store.colorway(for: pairID).name)
                }.accessibilityIdentifier("shoe-color")
            }
            Section {
                NavigationLink("Auto-Lace") { ShoeFeatureView(feature: .autoLace, pairID: pairID) }
                    .accessibilityIdentifier("shoe-auto-lace")
                NavigationLink("Firmware") { ShoeFirmwareView(pairID: pairID) }
                    .accessibilityIdentifier("shoe-firmware")
                NavigationLink("Quick Unlace") { ShoeFeatureView(feature: .doubleTapUntie, pairID: pairID) }
                    .accessibilityIdentifier("shoe-gestures")
                NavigationLink("Model information") { ShoeModelInfoView(pair: pair) }
            }
            Section {
                Button("Disconnect shoes") { store.disconnect() }.disabled(store.anyBusy)
                removeButton
            }
        }
    }
    private func disconnectedDetails(_ pair: ShoePair) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                ConnectionBadge(pairID: pairID).frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 24)
                ShoePortrait(colorway: store.colorway(for: pairID)).frame(height: 230)
                Spacer(minLength: 24)
                if selected && store.connectionFailed {
                    Text(store.connectionMessage).font(.subheadline).foregroundStyle(.secondary)
                }
                Button {
                    store.select(pair); store.reconnectSavedPair()
                } label: {
                    HStack {
                        if selected && store.connectionInProgress { ProgressView() }
                        Text(selected && store.connectionInProgress ? "Connecting" : "Connect")
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    .disabled(store.anyBusy || (selected && store.connectionInProgress))
                    .accessibilityIdentifier("guided-connect")
                if selected && store.connectionInProgress {
                    Button("Cancel connection") { store.disconnect() }.frame(minHeight: 44)
                }
                removeButton
            }.padding(24)
        }
    }
    private var removeButton: some View {
        Button("Remove shoes", role: .destructive) { removing = true }
            .frame(maxWidth: .infinity).frame(minHeight: 44).disabled(store.anyBusy)
            .accessibilityIdentifier("remove-shoes")
    }
}

private struct ShoeNicknameView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let pairID: String
    @State var name: String
    var body: some View {
        Form {
            Section {
                TextField("Nickname", text: $name).textInputAutocapitalization(.words)
                    .accessibilityIdentifier("nickname-field")
            } footer: { Text("A name for this pair in OpenAdapt.") }
        }.navigationTitle("Nickname").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if store.renamePair(pairID, nickname: name) { dismiss() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 60)
                }
            }
    }
}

private struct ShoeColorView: View {
    @EnvironmentObject private var store: AppStore
    let pairID: String
    var body: some View {
        List {
            Section {
                ShoePortrait(colorway: store.colorway(for: pairID)).listRowBackground(Color.clear)
            }
            Section {
                ForEach(ShoeColorway.allCases) { colorway in
                    Button { store.setColorway(colorway, for: pairID) } label: {
                        HStack {
                            Circle().fill(colorway.upper).frame(width: 24, height: 24)
                                .overlay(Circle().stroke(.secondary.opacity(0.2)))
                            Text(colorway.name); Spacer()
                            if store.colorway(for: pairID) == colorway { Image(systemName: "checkmark") }
                        }.padding(.vertical, 4)
                    }.accessibilityIdentifier("colorway-\(colorway.id)")
                        .accessibilityAddTraits(store.colorway(for: pairID) == colorway ? .isSelected : [])
                }
            } footer: { Text("Match the illustration to your pair. This changes its appearance in OpenAdapt; use Lights to change the shoe LEDs.") }
        }.navigationTitle("Shoe color").navigationBarTitleDisplayMode(.inline)
    }
}

struct ShoeFirmwareView: View {
    @EnvironmentObject private var store: AppStore
    let pairID: String
    var body: some View {
        Form {
            Section("Installed version") {
                ForEach(ShoeSide.allCases) { side in
                    LabeledContent(side.title, value: store.selectedID == pairID ? store.feet[side]?.firmware ?? "Not read" : "Connect to read")
                }
            }
            Section("Updates") {
                Label("Updates aren’t available yet", systemImage: "arrow.down.circle")
                Text("OpenAdapt can read the installed version. A verified update package and installation process are still needed before it can update your shoes.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("2.4.3M is the version tested with Auto Max. It is not a confirmed latest release.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Firmware").navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShoeModelInfoView: View {
    let pair: ShoePair
    var body: some View {
        Form {
            LabeledContent("Model", value: pair.model?.name ?? "Nike Adapt")
            Text("The model is identified from the shoe’s Bluetooth product family when that mapping is known. Shoe color is chosen by you.")
                .foregroundStyle(.secondary)
            Section {
                ForEach(ShoeModel.allCases) { model in Text(model.name) }
            } header: { Text("Adapt models") } footer: {
                Text("Names are available for all five models. Bluetooth control is currently verified for Auto Max 2.4.3M.")
            }
        }.navigationTitle("Model information").navigationBarTitleDisplayMode(.inline)
    }
}

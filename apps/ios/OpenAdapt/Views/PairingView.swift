import SwiftUI

struct ShoesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var removal: ShoePair?
    var body: some View {
        SheetPage(title: "My shoes") {
            List {
                if store.pairs.isEmpty && !store.demo {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("A new home for your shoes.").font(.title2.bold())
                            Text("Bring your Adapt shoes and we’ll help you get started.")
                                .foregroundStyle(.secondary)
                        }.padding(.vertical, 12).listRowBackground(Color.clear)
                    }
                }
                ForEach(store.pairs) { pair in
                    Section {
                        Button { store.select(pair) } label: {
                            HStack(spacing: 16) {
                                SneakerMark().frame(width: 56, height: 56)
                                    .foregroundStyle(.primary)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(pair.name).font(.headline).foregroundStyle(.primary)
                                    Text(store.selectedID == pair.id ? "Your pair" : "Saved pair")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.selectedID == pair.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.primary) }
                            }.padding(.vertical, 8)
                        }.disabled(store.anyBusy)
                            .swipeActions { Button("Remove", role: .destructive) { removal = pair } }
                        if store.selectedID == pair.id {
                            ForEach(ShoeSide.allCases) { side in
                                HStack {
                                    Text(side.letter).font(.title2.weight(.black)).frame(width: 28)
                                    Text("\(side.title) shoe")
                                    Spacer()
                                    Text(store.feet[side]!.connected ? "Connected" : store.feet[side]!.connecting ? "Connecting" : "Not connected")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }.accessibilityElement(children: .combine)
                            }
                            if !store.connected {
                                Button { store.reconnectSavedPair() } label: {
                                    Label("Connect shoes", systemImage: "antenna.radiowaves.left.and.right")
                                }.disabled(store.connectionInProgress).accessibilityIdentifier("guided-connect")
                                if store.connectionFailed {
                                    Text(store.connectionMessage).font(.caption).foregroundStyle(.secondary)
                                }
                                NavigationLink("Connect individually") { PairingGuideView(savedPair: true) }
                                    .disabled(store.connectionInProgress)
                            }
                            if store.anyConnected || store.reconnecting {
                                Button("Disconnect shoes", role: .destructive) { store.disconnect() }
                            }
                        }
                    }
                }
                Section {
                    NavigationLink { PairingGuideView(savedPair: false) } label: {
                        Label("Add shoes", systemImage: "plus")
                    }.accessibilityIdentifier("add-shoes")
                    NavigationLink("Connection help") { ConnectionHelpView() }
                }
            }
            .confirmationDialog("Remove this pair from your iPhone?", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
                Button("Remove pair", role: .destructive) { if let removal { store.removePair(removal.id) }; removal = nil }
            } message: { Text("Your shoes will keep their current settings.") }
        }
    }
}

struct PairingGuideView: View {
    let savedPair: Bool
    @EnvironmentObject private var store: AppStore
    var body: some View { PairingSteps(savedPair: savedPair, store: store, bluetooth: store.bluetooth) }
}

private struct PairingSteps: View {
    let savedPair: Bool
    @ObservedObject var store: AppStore
    @ObservedObject var bluetooth: BluetoothController
    @State private var side: ShoeSide = .left
    @State private var searching = false
    private var complete: Bool { savedPair && store.connected }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShoeIllustration()
                VStack(alignment: .leading, spacing: 10) {
                    Text(complete ? "You’re connected." : searching ? "Finding your \(savedPair ? side.title.lowercased() + " shoe" : "shoes")." : "Bring your shoes closer.")
                        .font(.largeTitle.bold()).tracking(-1)
                    Text(complete ? "Your fit, lights, and battery are ready when you are." : savedPair
                         ? "Close the old app. Keep just your \(side.title.lowercased()) shoe awake and near this iPhone for its first connection."
                         : "Wake your shoes and keep them beside your iPhone.")
                        .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if !complete {
                    Label("Hold either shoe button for 2 seconds to wake it.", systemImage: "hand.tap")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if !savedPair {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("New pairing is coming", systemImage: "sparkle").font(.headline)
                            Text("You can find your shoes now. Connecting a new or reset pair will be available in a future update. Keep your existing pairing for now.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.padding(20).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
                    }
                    if savedPair {
                        HStack(spacing: 12) {
                            ForEach(ShoeSide.allCases) { item in
                                Label(item.title, systemImage: store.feet[item]!.connected ? "checkmark.circle.fill" : "circle")
                                    .font(.subheadline.weight(.medium)).foregroundStyle(item == side || store.feet[item]!.connected ? .primary : .secondary)
                                    .frame(maxWidth: .infinity).padding(15)
                                    .background(.primary.opacity(item == side ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 16))
                            }
                        }.accessibilityElement(children: .combine)
                    }
                    if searching {
                        HStack(spacing: 10) {
                            if bluetooth.scanning || store.anyBusy { ProgressView() }
                            Text(bluetooth.availability).font(.subheadline).foregroundStyle(.secondary)
                        }.frame(minHeight: 30)
                        ForEach(bluetooth.nearby) { shoe in
                            if savedPair {
                                Button {
                                    store.connect(side, device: shoe)
                                } label: {
                                    HStack {
                                        SneakerMark().frame(width: 38, height: 38)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Connect \(side.title.lowercased()) shoe").font(.headline)
                                            Text(shoe.proximity).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer(); Image(systemName: "arrow.right.circle")
                                    }.padding(18).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                                }.buttonStyle(TactileButtonStyle()).disabled(store.anyBusy)
                            } else {
                                Label("Auto Max found · \(shoe.proximity)", systemImage: "checkmark.circle")
                                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                            }
                        }
                    }
                    Button {
                        searching = true; bluetooth.scan()
                    } label: {
                        HStack {
                            Text(searching ? "Search again" : savedPair ? "Find \(side.title.lowercased()) shoe" : "Find my shoes")
                            Spacer(); Image(systemName: "arrow.right")
                        }.font(.headline).padding(20).frame(maxWidth: .infinity)
                            .foregroundStyle(Color(uiColor: .systemBackground)).background(.primary, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(TactileButtonStyle()).disabled(bluetooth.scanning || store.anyBusy)
                        .accessibilityIdentifier("find-shoes")
                    NavigationLink("Connected to an old app?") { ConnectionHelpView() }
                        .font(.subheadline).frame(maxWidth: .infinity).frame(minHeight: 44)
                }
            }.padding(.horizontal, 24).padding(.bottom, 30)
        }.navigationTitle("\(savedPair ? "Connect" : "Add") shoes").navigationBarTitleDisplayMode(.inline)
            .onAppear { side = store.feet[.left]!.connected ? .right : .left }
            .onChange(of: store.feet[.left]!.connected) { _, connected in
                if connected { side = .right; searching = false; bluetooth.stopScan() }
            }
            .onDisappear { bluetooth.stopScan() }
    }
}

struct ConnectionHelpView: View {
    var body: some View {
        List {
            Section {
                Text("Start with a fresh connection.").font(.title2.bold()).padding(.vertical, 8)
                Label("Close Nike Adapt and any other shoe controller.", systemImage: "iphone")
                Label("Wake each shoe by holding either button for 2 seconds.", systemImage: "hand.tap")
                Label("Keep the shoes close to this iPhone, then try connecting again.", systemImage: "antenna.radiowaves.left.and.right")
            }
            Section {
                NavigationLink("About factory reset") { ResetGuideView() }
            } footer: { Text("Saved shoes can connect without a reset.") }
        }.navigationTitle("Connection help").navigationBarTitleDisplayMode(.inline)
    }
}

struct ResetGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Before you reset").font(.title2.bold())
                Text("A factory reset removes the old pairing and custom settings. OpenAdapt can’t yet set up a reset pair. Keep your current pairing until new-shoe setup is available.")
                    .foregroundStyle(.secondary)
            }
            Section("Nike’s system reset steps") {
                resetStep(1, "Turn one shoe off", "Hold both buttons for 5 seconds. Let go when its lights become red.")
                resetStep(2, "Reset its pairing", "Hold one button. Once the lights come on, keep holding it and press the other button 3 times. Look for green lights.")
                resetStep(3, "Repeat for the other shoe", "Follow the same sequence on your second shoe.")
            }
            Section {
                Link("Read Nike’s reset guide", destination: URL(string: "https://www.nike.com/my/help/a/adapt-troubleshooting")!)
            } footer: { Text("This guide explains a manual reset. OpenAdapt does not reset your shoes.") }
        }.navigationTitle("Factory reset").navigationBarTitleDisplayMode(.inline)
    }
    private func resetStep(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Text("\(number)").font(.headline).frame(width: 28, height: 28).background(.primary.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 7) { Text(title).font(.headline); Text(detail).foregroundStyle(.secondary) }
        }.padding(.vertical, 10).accessibilityElement(children: .combine)
    }
}

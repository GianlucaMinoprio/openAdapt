import SwiftUI
import AppIntents

struct SheetPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(.primary)
            .presentationDragIndicator(.visible).presentationCornerRadius(30)
    }
}

struct LightsView: View {
    @EnvironmentObject private var store: AppStore
    private var available: Bool { store.canControlBoth && !store.feet.values.contains(where: \.dragging) }
    var body: some View {
        SheetPage(title: "Lights") {
            ScrollView {
                VStack(spacing: 28) {
                    ZStack {
                        Circle().fill(store.accent.opacity(0.13)).frame(width: 190, height: 190).blur(radius: 24)
                        HStack(spacing: 8) {
                            ForEach(ShoeSide.allCases) { side in
                                let color = store.lightColor(side)?.color ?? .primary.opacity(0.10)
                                Capsule().fill(color.gradient).frame(width: 56, height: 88)
                                    .shadow(color: store.lightColor(side)?.color.opacity(0.35) ?? .clear, radius: 20)
                            }
                        }
                    }.frame(height: 165).accessibilityHidden(true)
                    VStack(spacing: 7) {
                        Text(store.activeLightColor?.name ?? "Lights off").font(.title2.weight(.semibold))
                        Text("Make them yours.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 4), spacing: 24) {
                        ForEach(ShoeColor.palette) { color in
                            let selected = ShoeSide.allCases.allSatisfy { store.feet[$0]?.lightColorID == color.id }
                            Button { store.setColor(color) } label: {
                                Circle().fill(color.color).frame(width: 46, height: 46)
                                    .padding(6).overlay(Circle().stroke(selected ? Color.primary : Color.primary.opacity(0.12), lineWidth: selected ? 2 : 1))
                                    .overlay { if selected { Image(systemName: "checkmark").font(.system(size: 17, weight: .bold)).foregroundStyle(color.usesDarkInk ? .black : .white) } }
                            }.buttonStyle(TactileButtonStyle()).disabled(!available).accessibilityLabel(color.name)
                                .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    Button { store.lightsOff() } label: { Label("Lights off", systemImage: "lightbulb.slash").frame(maxWidth: .infinity).padding(.vertical, 7) }
                        .buttonStyle(.bordered).disabled(!available)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "waveform.path"); Text("Effects").fontWeight(.medium); Spacer(); Text("Coming later").font(.caption).foregroundStyle(.secondary) }
                        Text("Pulsing, strobe, and gradient effects are still being verified for Auto Max. Base colors are available now.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(18).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
                }.padding(24)
            }
        }
    }
}

struct BatteryView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        SheetPage(title: "Battery") {
            VStack(spacing: 30) {
                Spacer()
                HStack(alignment: .center, spacing: 50) {
                    ForEach(ShoeSide.allCases) { side in
                        VStack(spacing: 20) {
                            let battery = store.feet[side]!.battery
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.14), lineWidth: 2)
                                if let battery {
                                    RoundedRectangle(cornerRadius: 14).fill(battery < 20 ? Color.orange.gradient : store.accent.gradient)
                                        .frame(height: 176 * CGFloat(battery) / 100).padding(6)
                                }
                            }.frame(width: 80, height: 190)
                                .overlay(alignment: .top) { Capsule().fill(.primary.opacity(0.3)).frame(width: 26, height: 6).offset(y: -9) }
                            Text(battery.map { "\($0)%" } ?? "—").font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
                            Text(side.title.uppercased()).font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(side.title) battery").accessibilityValue(store.feet[side]!.battery.map { "\($0) percent" } ?? "Unknown")
                    }
                }
                VStack(spacing: 10) {
                    Text(store.connected ? "Ready when you are." : "Connect to check battery.").font(.title2.weight(.semibold))
                    Text(store.demo ? "Sample battery levels in demo mode." : "Battery levels are read directly from your shoes.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                Spacer()
                Button { store.refreshBattery() } label: { Label("Refresh battery", systemImage: "arrow.clockwise").frame(maxWidth: .infinity).padding(.vertical, 8) }
                    .buttonStyle(.bordered).disabled(!store.canControlBoth)
            }.padding(30).onAppear { store.refreshBattery() }
        }
    }
}

struct ModesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var adding = false
    @State private var name = ""
    var body: some View {
        SheetPage(title: "Your modes") {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("A fit for every moment.").font(.title2.weight(.semibold))
                        Text("Save a comfortable fit, then come back to it with a tap.").foregroundStyle(.secondary).font(.subheadline)
                    }.padding(.vertical, 12).listRowBackground(Color.clear)
                }
                Section("Saved fits") {
                    ForEach(store.modes) { mode in
                        Button { store.applyMode(mode) } label: {
                            HStack(spacing: 16) {
                                Image(systemName: mode.name == "Move" ? "figure.walk" : mode.name == "Chill" ? "leaf" : "bookmark")
                                    .font(.title3).frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.name).font(.headline).foregroundStyle(.primary)
                                    if store.tieMode?.id == mode.id {
                                        Text("Used by Tie Shoes").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(mode.left) / \(mode.right)").font(.system(.body, design: .rounded).weight(.medium)).monospacedDigit().foregroundStyle(.primary)
                                    Text("LEFT / RIGHT").font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 12)
                        }.disabled(!store.canAdjustBoth)
                    }.onDelete(perform: store.deleteModes)
                    Button { adding = true } label: { Label("Save current fit", systemImage: "plus") }
                        .disabled(!store.canAdjustBoth || store.modes.count >= 20)
                }
                if store.connected && !store.canAdjustBoth && !store.anyBusy {
                    Section { Text("Use the shoe buttons to adjust fit. Fit calibration isn’t available yet for newly paired shoes.").font(.subheadline).foregroundStyle(.secondary) }
                }
                Section { Text("Tie Shoes uses the last mode you successfully applied to both shoes, or your first saved mode to start. Loosening or adjusting by hand keeps that mode remembered.").font(.caption).foregroundStyle(.secondary) }
            }
            .alert("Save current fit", isPresented: $adding) {
                TextField("Mode name", text: $name)
                Button("Cancel", role: .cancel) { name = "" }
                Button("Save") { store.saveMode(name: name); name = "" }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: { Text("Left \(store.feet[.left]!.target)% · Right \(store.feet[.right]!.target)%") }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        SheetPage(title: "Settings") {
            Form {
                Section {
                    NavigationLink { SiriSetupView() } label: {
                        Label("Siri & Shortcuts", systemImage: "waveform")
                    }.accessibilityIdentifier("siri-voice-setup")
                    NavigationLink { FitHelpView() } label: {
                        Label("Fit & progress", systemImage: "slider.vertical.3")
                    }
                    NavigationLink { ShoeFeaturesView() } label: {
                        Label("Auto-Lace & Quick Unlace", systemImage: "shoeprints.fill")
                    }.accessibilityIdentifier("shoe-features")
                }
                #if DEBUG
                Section("Developer mode") {
                    NavigationLink { DeveloperShoesView() } label: {
                        Label("Your shoes", systemImage: "wrench.and.screwdriver")
                    }.accessibilityIdentifier("developer-shoes")
                }
                #endif
                Section("Open by design") {
                    LabeledContent("OpenAdapt", value: "0.1.0")
                    LabeledContent("License", value: "MIT")
                    Link(destination: URL(string: "https://github.com/GianlucaMinoprio/openAdapt")!) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                    }.accessibilityIdentifier("repository-link")
                    Text("An independent, open-source companion for your shoes. No account, no analytics, and no cloud service.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Not affiliated with or endorsed by Nike. Nike and Adapt are trademarks of their respective owner.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct FitHelpView: View {
    var body: some View {
        Form {
            Section("Set your fit") {
                Text("Drag L or R to adjust that shoe, or use two fingers to adjust both at once.")
            }
            Section("Follow the movement") {
                Text("The letter and target mark follow your finger. When you let go, a second mark catches up as the shoe laces.")
                Text("The moving mark is an estimate. It reaches the target once the shoe confirms its position.")
                    .foregroundStyle(.secondary)
            }
        }.navigationTitle("Fit & progress").navigationBarTitleDisplayMode(.inline)
    }
}

struct ShoeFeaturesView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            if let pair = store.pair {
                Section(pair.displayName) {
                    NavigationLink("Auto-Lace") { ShoeFeatureView(feature: .autoLace, pairID: pair.id) }
                    NavigationLink("Quick Unlace") { ShoeFeatureView(feature: .doubleTapUntie, pairID: pair.id) }
                }
            } else {
                Text("Connect a saved pair to manage its auto-lace and gesture settings.")
            }
        }.navigationTitle("Auto-Lace & Quick Unlace").navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
struct DeveloperShoesView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            Section {
                LabeledContent("Model", value: store.pair?.model?.name ?? "No pair selected")
                LabeledContent("Tested firmware", value: ShoeFirmware.testedVersion)
                ForEach(ShoeSide.allCases) { side in
                    LabeledContent("\(side.title) firmware", value: store.feet[side]?.firmware ?? "Not read")
                }
                LabeledContent("Connection", value: "Bluetooth · local only")
            }
            PairingExportSection()
            Section {
                NavigationLink("Check a new shoe") { PairingGuideView() }
                    .accessibilityIdentifier("check-new-shoe")
                Text("New-shoe setup saves each key after the shoe confirms it. After both shoes are saved, you can export the pair here. Fresh enrollment still needs physical testing; fit controls require verified calibration.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Firmware") {
                Text("2.4.3M is the version tested with OpenAdapt, not a confirmed latest release. Other versions are inspected without enabling shoe commands.")
                Text("Firmware updates are not available. An update needs a verified image for the exact model, a validated transfer procedure, and a recovery path.")
            }
        }.navigationTitle("Your shoes").navigationBarTitleDisplayMode(.inline)
    }
}
#endif

struct SiriSetupView: View {
    @State private var importFailed = false
    var body: some View {
        Form {
            Section {
                shortcutRow("Tie my shoes", symbol: "shoe.fill", identifier: "add-tie-shortcut")
                shortcutRow("Untie my shoes", symbol: "arrow.down", identifier: "add-untie-shortcut")
            } header: {
                Text("Your everyday commands")
            } footer: {
                Text("Add each once. Then say “Siri, tie my shoes” or “Siri, untie my shoes.”")
            }
            Section {
                NavigationLink { SiriHelpView() } label: {
                    Label("Help with Siri", systemImage: "questionmark.circle")
                }.accessibilityIdentifier("siri-help")
            }
        }
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn’t open Shortcuts", isPresented: $importFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Open Help with Siri for the manual setup steps.")
        }
    }
    @ViewBuilder private func shortcutRow(_ name: String, symbol: String, identifier: String) -> some View {
        if let url = shortcutFile(name) {
            Button {
                UIApplication.shared.open(url) { if !$0 { importFailed = true } }
            } label: { Label("Add “\(name)”", systemImage: symbol).padding(.vertical, 6) }
                .accessibilityIdentifier(identifier)
        } else {
            NavigationLink { SiriHelpView() } label: {
                Label("Set up “\(name)”", systemImage: symbol).padding(.vertical, 6)
            }.accessibilityIdentifier("setup-\(identifier)")
        }
    }
    private func shortcutFile(_ name: String) -> URL? {
        guard let manifest = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "SiriShortcuts"),
              let data = try? Data(contentsOf: manifest),
              let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              info["bundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              (info["files"] as? [String])?.contains("\(name).shortcut") == true else { return nil }
        return Bundle.main.url(forResource: name, withExtension: "shortcut", subdirectory: "SiriShortcuts")
    }
}

struct SiriHelpView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            Section("The fit Siri uses") {
                if let mode = store.tieMode {
                    LabeledContent(mode.name, value: "L \(mode.left)% · R \(mode.right)%")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(mode.name)
                        .accessibilityValue("Left \(mode.left) percent, right \(mode.right) percent")
                        .accessibilityIdentifier("siri-remembered-fit")
                    Text("Your last applied mode, or your first saved fit to start. Untying keeps it remembered.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else { Text("Save a fit in Modes to use Tie Shoes.") }
            }
            Section("Getting started") {
                Text("Tap Add Shortcut on Apple’s confirmation screen. Adding a shortcut does not run it.")
                Text("Connect each shoe in OpenAdapt once. Keep them awake and nearby, and unlock your iPhone if Siri asks.")
                Text("Siri can then control your shoes without opening OpenAdapt.")
            }
            Section("Set up manually") {
                Text("In Shortcuts, tap +, search for OpenAdapt, and add Tie Shoes. Name it Tie my shoes.")
                Text("Repeat with Loosen Shoes, leave Both shoes selected, and name it Untie my shoes.")
                ShortcutsLink().accessibilityIdentifier("siri-shortcuts-link")
            }
            Section("If Siri gives a general answer") {
                Text("Use the exact name of the shortcut you added. Say “untie” or “loosen”; Siri may hear “loose” as “lose.”")
                Text("You can also try “Siri, lace my shoes with OpenAdapt” or “Siri, untie my shoes with OpenAdapt.”")
            }
        }.navigationTitle("Help with Siri").navigationBarTitleDisplayMode(.inline)
    }
}

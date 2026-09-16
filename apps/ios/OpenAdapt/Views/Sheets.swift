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
    @State private var side = "both"
    private var sides: [ShoeSide] { side == "both" ? ShoeSide.allCases : [side == "left" ? .left : .right] }
    private var available: Bool { sides.allSatisfy { store.feet[$0]!.connected && !store.feet[$0]!.busy } }
    var body: some View {
        SheetPage(title: "Lights") {
            ScrollView {
                VStack(spacing: 28) {
                    Picker("Shoes", selection: $side) {
                        Text("Left").tag("left"); Text("Both").tag("both"); Text("Right").tag("right")
                    }.pickerStyle(.segmented)
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
                            let selected = sides.allSatisfy { store.feet[$0]?.lightColorID == color.id }
                            Button { store.setColor(color, sides: sides) } label: {
                                Circle().fill(color.color).frame(width: 46, height: 46)
                                    .padding(6).overlay(Circle().stroke(selected ? Color.primary : Color.primary.opacity(0.12), lineWidth: selected ? 2 : 1))
                                    .overlay { if selected { Image(systemName: "checkmark").font(.system(size: 17, weight: .bold)).foregroundStyle(color.usesDarkInk ? .black : .white) } }
                            }.buttonStyle(TactileButtonStyle()).disabled(!available).accessibilityLabel(color.name)
                                .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    Button { store.lightsOff() } label: { Label("Lights off", systemImage: "lightbulb.slash").frame(maxWidth: .infinity).padding(.vertical, 7) }
                        .buttonStyle(.bordered).disabled(!store.canControlBoth)
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
                        }.disabled(!store.canControlBoth)
                    }.onDelete(perform: store.deleteModes)
                    Button { adding = true } label: { Label("Save current fit", systemImage: "plus") }
                        .disabled(!store.canControlBoth || store.modes.count >= 20)
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
    @EnvironmentObject private var store: AppStore
    var body: some View {
        SheetPage(title: "Settings") {
            Form {
                Section("Experience") {
                    Toggle("Haptic feedback", isOn: $store.hapticsEnabled)
                    LabeledContent("Control steps", value: "5%")
                    Text("Drag either letter to set its fit. Link the shoes to adjust them together, or use two fingers for independent control.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Your shoes") {
                    LabeledContent("Model", value: "Adapt Auto Max")
                    LabeledContent("Supported firmware", value: "2.4.3M")
                    LabeledContent("Connection", value: "Bluetooth · local only")
                    Text("Your shoes reconnect when you open the app after their first connection. You can cancel at any time.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Siri & Shortcuts") {
                    SiriTipView(intent: TieShoesIntent())
                    NavigationLink {
                        SiriSetupView()
                    } label: {
                        Label("Say “Tie my shoes”", systemImage: "waveform")
                    }.accessibilityIdentifier("siri-voice-setup")
                    ShortcutsLink().accessibilityIdentifier("siri-shortcuts-link")
                    Text("Tie Shoes uses your last saved fit mode. Loosen Shoes releases both shoes. You can also control lights and check battery.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Connect each shoe here once first. Siri can then control your shoes without opening OpenAdapt. Your iPhone must be unlocked, and your shoes awake and nearby.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Fit & progress") {
                    Text("Percentages use your saved fit calibration. The letters show the requested fit. The side marks show estimated progress during lacing, then the position confirmed by each shoe.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Auto-lace, gestures, calibration changes, and firmware updates are not available in this release.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Open by design") {
                    LabeledContent("OpenAdapt", value: "0.1.0")
                    LabeledContent("License", value: "MIT")
                    Text("An independent, open-source companion for your shoes. No account, no analytics, and no cloud service.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Not affiliated with or endorsed by Nike. Nike and Adapt are trademarks of their respective owner.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SiriSetupView: View {
    @EnvironmentObject private var store: AppStore
    @State private var importFailed = false
    var body: some View {
        Form {
            if let tie = shortcutFile("Tie my shoes"), let untie = shortcutFile("Untie my shoes") {
                Section {
                    Button { addShortcut(tie) } label: {
                        Label("Add “Tie my shoes”", systemImage: "plus.circle")
                    }.accessibilityIdentifier("add-tie-shortcut")
                    Button { addShortcut(untie) } label: {
                        Label("Add “Untie my shoes”", systemImage: "plus.circle")
                    }.accessibilityIdentifier("add-untie-shortcut")
                } header: { Text("Your everyday commands") } footer: {
                    Text("Tap Add Shortcut on Apple’s next screen. Then say “Siri, tie my shoes” or “Siri, untie my shoes.” Add each once; neither shortcut runs during setup.")
                }
            }
            Section {
                voiceCommand("Siri, tie my shoes with OpenAdapt", detail: "Uses your last applied mode, or your first saved fit to start.")
                voiceCommand("Siri, untie my shoes with OpenAdapt", detail: "Releases both shoes and remembers your fit for next time.")
            } header: { Text("Built-in phrases") } footer: {
                Text("You can also say “Lace my shoes with OpenAdapt” or “Make my lace with OpenAdapt.” For releasing, “loosen” works too. Neither action needs a percentage or opens the app.")
            }
            Section("Your tie fit") {
                if let mode = store.tieMode {
                    LabeledContent(mode.name, value: "L \(mode.left)% · R \(mode.right)%")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(mode.name)
                        .accessibilityValue("Left \(mode.left) percent, right \(mode.right) percent")
                        .accessibilityIdentifier("siri-remembered-fit")
                    Text(store.lastUsedMode == nil ? "Starts with your first saved fit. Apply another mode whenever you want to change it." : "Apply another saved mode whenever you want to change it.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Save a fit in Modes to use Tie Shoes.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Make the phrases shorter") {
                setupStep(1, title: "Open Shortcuts", detail: "Tap + to create a shortcut. Search for OpenAdapt and add Tie Shoes.")
                setupStep(2, title: "Name it “Tie my shoes”", detail: "Rename the shortcut, then tap Done. That’s the phrase you’ll say to Siri.")
                setupStep(3, title: "Add “Untie my shoes”", detail: "Create another shortcut with Loosen Shoes, leave Both shoes selected, and name it Untie my shoes. Loosen my shoes works as a name too.")
                ShortcutsLink()
            }
            Section("If Siri gives a general answer") {
                Text("Say “untie” or “loosen.” Siri may hear “loose” as “lose,” meaning to misplace your shoes.")
                Text("Use the full phrase with OpenAdapt, or say the exact name of a personal shortcut you’ve saved. For example, “Siri, untie my shoes” needs a shortcut named Untie my shoes.")
                Text("Keep your shoes awake and nearby. Connect each shoe in OpenAdapt once first, and unlock your iPhone if Siri asks.")
            }.font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Control with Siri")
        .navigationBarTitleDisplayMode(.large)
        .alert("Open Shortcuts to finish setup", isPresented: $importFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Use the steps below to create a shortcut with the Tie Shoes or Loosen Shoes action from OpenAdapt.")
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

    private func addShortcut(_ url: URL) {
        UIApplication.shared.open(url) { opened in
            if !opened { importFailed = true }
        }
    }

    private func voiceCommand(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 8)
    }

    private func setupStep(_ number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.body.weight(.semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 6)
    }
}

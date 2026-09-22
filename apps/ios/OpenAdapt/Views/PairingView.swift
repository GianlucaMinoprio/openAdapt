import SwiftUI

struct PairingGuideView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View { PairingSteps(store: store) }
}

private struct PairingSteps: View {
    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var instructionFocused: Bool
    @ObservedObject var store: AppStore
    @StateObject private var setup = NewShoeSetup()
    private var second: String? { setup.nextSide?.title.lowercased() }
    private var heading: String {
        if setup.complete { return "Your shoes are paired." }
        if setup.phase == .failed { return "Let’s try that again." }
        if let second { return "Now your \(second) shoe." }
        return setup.phase == .confirm ? "Press a light on your shoe." : "Start with either shoe."
    }
    private var instruction: String {
        switch setup.phase {
        case .idle: return "Wake your shoes, then hold your iPhone beside the shoe you want to pair first."
        case .searching, .connecting:
            return second.map { "Hold your iPhone beside your \($0) shoe. We’ll let you know when to press its button." }
                ?? "Keep your iPhone beside that shoe. We’ll let you know when to press its button."
        case .confirm:
            return second.map { "Press either illuminated button on your \($0) shoe to finish pairing." }
                ?? "Press either illuminated button on the shoe beside your iPhone to confirm."
        case .saving: return "Saving your pair securely on this iPhone."
        case .complete: return "OpenAdapt will reconnect to this pair when you open the app."
        case .failed: return setup.error ?? "Keep your shoes nearby and try again."
        }
    }
    private var status: String {
        switch setup.phase {
        case .idle: return "One shoe at a time"
        case .searching: return "Finding your shoe…"
        case .connecting: return "Connecting…"
        case .confirm: return "Waiting for your button press"
        case .saving: return "Saving your pair…"
        case .complete: return "Ready to connect"
        case .failed: return setup.firstPairedSide == nil ? "Your saved shoes are kept" : "Your first shoe’s pairing is saved"
        }
    }
    var body: some View {
        GeometryReader { geometry in
          ScrollViewReader { scroll in
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Text(setup.complete ? "PAIR COMPLETE" : setup.firstPairedSide == nil ? "SHOE 1 OF 2" : "SHOE 2 OF 2")
                            .font(.caption.weight(.semibold)).tracking(1.8).foregroundStyle(.secondary)
                            .accessibilityIdentifier("pairing-step")
                        Text(heading).font(.largeTitle.bold()).tracking(-1)
                            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("pairing-heading")
                        Text(instruction).font(.body).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("pairing-instruction")
                            .accessibilityFocused($instructionFocused)
                    }.multilineTextAlignment(.center).id("pairing-instruction-top")
                    Spacer(minLength: 0)
                    PairingIllustration(confirming: setup.phase == .confirm, complete: setup.complete)
                        .frame(height: min(270, geometry.size.height * 0.34))
                    VStack(spacing: 12) {
                        if let side = setup.firstPairedSide, !setup.complete {
                            Label("\(side.title) shoe paired", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                                .accessibilityIdentifier("first-shoe-paired")
                        }
                        HStack(spacing: 10) {
                            if setup.running && setup.phase != .confirm { ProgressView().controlSize(.small) }
                            else if setup.phase == .confirm { Image(systemName: "hand.tap").font(.title3) }
                            Text(status).font(.subheadline)
                        }.foregroundStyle(.secondary).accessibilityElement(children: .combine)
                            .accessibilityIdentifier("pairing-status")
                    }
                    Spacer(minLength: 0)
                    footer
                }.padding(.horizontal, 28).padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
            }
            .onChange(of: setup.phase) { _, phase in
                if phase == .confirm || phase == .complete || phase == .failed {
                    // At larger text sizes Start can require scrolling. Bring
                    // the next physical instruction into view without motion.
                    scroll.scrollTo("pairing-instruction-top", anchor: .top)
                }
            }
          }
        }.navigationTitle("Add shoes").navigationBarTitleDisplayMode(.inline)
            .onChange(of: setup.phase) { _, phase in
                if phase == .confirm { store.haptics.commit() }
                if phase == .confirm || phase == .complete || phase == .failed { instructionFocused = true }
            }
            .onChange(of: setup.firstPairedSide) { _, side in
                if side != nil { store.haptics.success() }
            }
            .onDisappear {
                setup.cancel(); store.bluetooth.stopScan(); store.endNewShoeSetup()
            }
    }
    @ViewBuilder private var footer: some View {
        VStack(spacing: 12) {
            if !setup.running {
                if setup.phase == .idle || setup.complete {
                    Text(setup.complete ? "Use the shoe buttons for fit. App fit calibration is coming later." : "New pairings support battery and lights. Use the shoe buttons for fit until app calibration is available.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                Button {
                    if setup.complete { dismiss() }
                    else { setup.start(bluetooth: store.bluetooth, store: store) }
                } label: {
                    Text(setup.complete ? "Done" : setup.phase == .idle ? "Start" : "Try again")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 19)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .background(.primary, in: Capsule())
                }.buttonStyle(TactileButtonStyle()).accessibilityIdentifier("find-shoes")
                if setup.phase == .failed {
                    Button("I’ve reset both shoes") {
                        setup.start(bluetooth: store.bluetooth, store: store, afterReset: true)
                    }.font(.subheadline).frame(minHeight: 44)
                }
                if !setup.complete {
                    NavigationLink("Connected to an old app?") { ConnectionHelpView() }
                        .font(.subheadline).frame(minHeight: 44)
                }
            } else {
                Button("Cancel setup") { dismiss() }
                    .font(.subheadline).frame(minHeight: 44)
                    .accessibilityIdentifier("cancel-pairing")
            }
        }
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
                Text("A factory reset removes the old pairing and custom settings. During setup, you’ll confirm the new connection by pressing either light on each shoe. Fit calibration isn’t available yet, so newly paired shoes use their physical buttons for fit adjustments.")
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

import SwiftUI

struct ShoeFeatureView: View {
    @EnvironmentObject private var store: AppStore
    let feature: ShoeFeature
    let pairID: String
    @State private var requestedValue: Bool?

    private var state: ShoePairFeatureState {
        ShoePairFeatureState(ShoeSide.allCases.map {
            store.selectedID == pairID ? store.feet[$0]!.features[feature] ?? .unknown : .unknown
        })
    }
    private var available: Bool {
        store.selectedID == pairID && store.canControlBoth && !store.feet.values.contains(where: \.dragging)
    }
    private var connectionKey: String {
        (store.selectedID ?? "") + pairID + ShoeSide.allCases.map { store.feet[$0]!.connected ? "1" : "0" }.joined()
    }
    private var explanation: String {
        feature == .autoLace
            ? "Automatically lace up when you step into your shoes."
            : "Double-tap a shoe to release its laces."
    }
    private var displayValue: Bool? {
        if let requestedValue { return requestedValue }
        if let value = state.value { return value }
        if state == .mixed { return true }
        if feature == .autoLace { return store.autoLacePreference(for: pairID) }
        return nil
    }
    private var status: String? {
        if state == .unconfirmed { return "The change wasn’t confirmed on both shoes. Reconnect and try again." }
        if store.selectedID != pairID || !store.connected { return "Connect both shoes to change this setting." }
        switch state {
        case .unknown: return feature == .autoLace ? nil : "Checking your shoes…"
        case .reading: return "Checking your shoes…"
        case .applying: return "Updating both shoes…"
        case .mixed: return "The shoes have different settings. This switch changes both."
        case .unsupported: return "This setting isn’t available for these shoes."
        case .unconfirmed: return "The change wasn’t confirmed on both shoes. Reconnect and try again."
        case .confirmed: return nil
        }
    }

    var body: some View {
        Form {
            Section {
                if let value = displayValue {
                    Toggle(feature.title, isOn: Binding(get: { displayValue ?? value }, set: apply))
                        .tint(.green)
                        .disabled(!available)
                        .accessibilityHint("Changes both shoes")
                        .accessibilityIdentifier("feature-\(feature.id)-toggle")
                } else {
                    HStack {
                        Text(feature.title)
                        Spacer()
                        if state == .reading || state == .applying {
                            ProgressView().accessibilityLabel("Checking setting")
                        } else if state == .unknown || state == .unconfirmed {
                            Button("Try again") { store.refreshGestureSettings() }
                                .disabled(!available)
                        }
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(explanation + " Applies to both shoes.")
                    if let status {
                        Text(status).accessibilityIdentifier("feature-status")
                    }
                }
            }
        }
        .navigationTitle(feature.title).navigationBarTitleDisplayMode(.inline)
        .task(id: connectionKey) {
            requestedValue = nil
            if feature == .doubleTapUntie && store.selectedID == pairID { store.refreshGestureSettings() }
        }
        .onChange(of: state) { _, newState in
            if newState != .applying { requestedValue = nil }
        }
    }

    private func apply(_ enabled: Bool) {
        guard available else { return }
        requestedValue = enabled
        store.setFeature(feature, enabled: enabled)
    }
}

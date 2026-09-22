import Foundation

/// The last preference successfully applied by OpenAdapt, not device readback.
/// Loading a preference never sends a setting to the shoes.
public struct SavedAutoLacePreference {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func isEnabled(forPair pairID: String) -> Bool { defaults.bool(forKey: key(pairID)) }
    @discardableResult
    public func record(_ enabled: Bool, forPair pairID: String,
                       confirmations: [ShoeFeatureConfirmation]) -> Bool {
        guard ShoePairFeatureState(confirmations) == .confirmed(enabled) else { return false }
        defaults.set(enabled, forKey: key(pairID))
        return true
    }
    public func clear(forPair pairID: String) { defaults.removeObject(forKey: key(pairID)) }
    private func key(_ pairID: String) -> String { "autoLacePreference.\(pairID)" }
}

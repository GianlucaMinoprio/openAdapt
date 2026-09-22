import Foundation

/// Connection history is separate from the pair currently being viewed or tried.
public struct SavedPairHistory {
    private let defaults: UserDefaults
    private let historyKey = "connectedPairHistory"
    private let legacySelectionKey = "selectedPair"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func preferredPairID(among availableIDs: [String]) -> String? {
        let available = Set(availableIDs)
        if let recent = history.first(where: { available.contains($0) }) { return recent }
        // Preserve the previous app's default until a complete connection is recorded.
        if let legacy = defaults.string(forKey: legacySelectionKey), available.contains(legacy) { return legacy }
        return availableIDs.first
    }

    @discardableResult
    public func recordConnectedPair(_ pairID: String, confirmedSides: Set<ShoeSide>) -> Bool {
        guard !pairID.isEmpty, confirmedSides == Set(ShoeSide.allCases) else { return false }
        defaults.set([pairID] + history.filter { $0 != pairID }, forKey: historyKey)
        defaults.set(pairID, forKey: legacySelectionKey)
        return true
    }

    public func removePair(_ pairID: String) {
        defaults.set(history.filter { $0 != pairID }, forKey: historyKey)
        if defaults.string(forKey: legacySelectionKey) == pairID {
            defaults.removeObject(forKey: legacySelectionKey)
        }
    }

    private var history: [String] { defaults.stringArray(forKey: historyKey) ?? [] }
}

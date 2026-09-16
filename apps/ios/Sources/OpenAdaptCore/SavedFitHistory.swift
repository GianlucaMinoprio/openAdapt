import Foundation

/// Remembers a confirmed mode, never a pending motor command or raw fit target.
/// Each pair has its own history, even when default mode IDs are shared.
public struct SavedFitHistory {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func lastUsedMode(forPair pairID: String, availableModes: [UUID]) -> UUID? {
        guard let value = defaults.string(forKey: key(pairID)),
              let id = UUID(uuidString: value), availableModes.contains(id) else { return nil }
        return id
    }

    @discardableResult
    public func recordConfirmedMode(_ modeID: UUID, forPair pairID: String,
                                    confirmedSides: Set<ShoeSide>) -> Bool {
        // A partial or failed application must not replace a comfortable fit.
        guard confirmedSides == Set(ShoeSide.allCases) else { return false }
        defaults.set(modeID.uuidString, forKey: key(pairID))
        return true
    }

    public func clear(forPair pairID: String) { defaults.removeObject(forKey: key(pairID)) }

    private func key(_ pairID: String) -> String { "lastUsedFitMode.\(pairID)" }
}

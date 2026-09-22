import Foundation

public enum ShoeConnectionError: LocalizedError, Equatable {
    case rediscoveryRequired
    case notFound
    case ambiguousShoes
    case bluetooth(String)

    public var errorDescription: String? {
        switch self {
        case .rediscoveryRequired: return "This iPhone needs to find the shoe again. Open OpenAdapt and tap Connect shoes."
        case .notFound: return "Your saved shoe was not found. Wake it, bring it closer, and close other shoe apps."
        case .ambiguousShoes: return "OpenAdapt couldn’t identify the left and right shoes automatically. Your saved pair is unchanged."
        case .bluetooth(let message): return message
        }
    }
}

/// Foreground connection only. A saved UUID is a useful cache, not a permanent
/// radio identity. Rediscovery still uses the selected shoe's exact name, and
/// the caller must authenticate its existing key before saving a new UUID.
@MainActor
public enum SavedShoeConnection {
    public static func discoveryCandidate(in nearby: [UUID: String], expectedName: String,
        rememberedID: UUID?, allowsNameMatch: Bool) throws -> UUID? {
        if let rememberedID, nearby[rememberedID] == expectedName { return rememberedID }
        if !allowsNameMatch {
            guard rememberedID != nil else { throw ShoeConnectionError.ambiguousShoes }
            return nil
        }
        let matches = nearby.filter { $0.value == expectedName }
        guard matches.count <= 1 else { throw ShoeConnectionError.ambiguousShoes }
        return matches.first?.key
    }

    public static func connect<Link>(rememberedID: UUID?, expectedName: String,
        retrieve: (UUID) async throws -> Link,
        discover: (String) async throws -> UUID,
        connectDiscovered: (UUID) async throws -> Link,
        discard: (Link) -> Void = { _ in }) async throws -> Link {
        try Task.checkCancellation()
        if let rememberedID {
            do {
                let link = try await retrieve(rememberedID)
                do { try Task.checkCancellation() }
                catch { discard(link); throw error }
                return link
            }
            catch {
                try Task.checkCancellation()
                guard error as? ShoeConnectionError == .rediscoveryRequired ||
                        error as? AdaptError == .timeout || error as? AdaptError == .disconnected else { throw error }
            }
        }
        try Task.checkCancellation()
        let id = try await discover(expectedName)
        try Task.checkCancellation()
        let link = try await connectDiscovered(id)
        do { try Task.checkCancellation() }
        catch { discard(link); throw error }
        return link
    }
}

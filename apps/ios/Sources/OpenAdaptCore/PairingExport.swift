import Foundation

/// Shares only a completed, saved pair. Enrollment journals are never part of this format.
public enum PairingExport {
    private struct File: Encodable {
        let version = 2
        let pairs: [ShoePair]
    }

    public static func encode(_ pair: ShoePair) throws -> Data {
        try pair.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(File(pairs: [pair]))
    }
}

import Foundation

public enum ShoeEnrollmentError: Error, LocalizedError, Equatable {
    case notReady, interrupted, identity, storage
    public var errorDescription: String? {
        switch self {
        case .notReady: return "This shoe isn’t ready for a new pairing. Check the reset guide if it’s connected to another app."
        case .interrupted: return "Setup was interrupted before a new key could be saved. Reset this shoe before starting a new setup."
        case .identity: return "We couldn’t confirm which shoe this is. Keep only the pair you want to add nearby and try again."
        case .storage: return "The new pairing couldn’t be saved. Keep your shoes on, unlock your iPhone, and try again."
        }
    }
}

/// Never log or export this record. It contains recovery secrets and belongs in Keychain.
public struct ShoeEnrollmentRecord: Codable, Equatable {
    public enum Phase: String, Codable { case checking, exchangeStarted, candidate, verified }
    public let id: UUID
    public var peripheralID: UUID
    public let advertisedName: String
    public let side: ShoeSide
    public let identity: Data
    public var phase: Phase = .checking
    public var group: Int?
    public var privateKey: Data?
    public var publicKey: Data?
    public var peerPublicKey: Data?
    public var candidateKey: Data?
    public var supersededAfterReset: Bool?

    public init(peripheralID: UUID, advertisedName: String, advertisement: ShoeAdvertisement) {
        id = UUID(); self.peripheralID = peripheralID; self.advertisedName = advertisedName
        side = advertisement.side; identity = advertisement.identity
    }
    public func validate() throws {
        guard ShoeModel.detected(advertisedName: advertisedName) == .adaptAutoMax,
              identity.count == 6, identity.last == (side == .left ? 0 : 1) else { throw ShoeEnrollmentError.identity }
        if phase == .checking, group != nil || privateKey != nil || publicKey != nil { throw ShoeEnrollmentError.storage }
        if let group {
            guard (0...3).contains(group), let privateKey, let publicKey,
                  (1...256).contains(privateKey.count), (1...256).contains(publicKey.count) else {
                throw ShoeEnrollmentError.storage
            }
        } else if privateKey != nil || publicKey != nil { throw ShoeEnrollmentError.storage }
        if phase == .candidate || phase == .verified {
            guard let candidateKey, let peerPublicKey, (1...256).contains(peerPublicKey.count), group != nil else {
                throw ShoeEnrollmentError.storage
            }
            try ShoeCrypto.validate(key: candidateKey)
        } else if candidateKey != nil || peerPublicKey != nil { throw ShoeEnrollmentError.storage }
    }
}

@MainActor
public enum ShoeEnrollment {
    /// The caller verifies family, firmware and advertisement identity first.
    /// No reset or motor command is issued. No interrupted exchange is replayed.
    public static func run(session: ShoeSession, record initial: ShoeEnrollmentRecord,
                           save: @escaping (ShoeEnrollmentRecord) throws -> Void,
                           onReady: @escaping () -> Void,
                           exchangeTimeout: TimeInterval = 33) async throws -> ShoeEnrollmentRecord {
        try initial.validate()
        var record = initial
        let channel = session.channel
        do {
            if let candidate = record.candidateKey {
                // Recovery uses only the candidate. It never falls back to setup credentials.
                try await session.authenticate(key: candidate)
                record.phase = .verified
                try save(record)
                return record
            }
            guard record.phase == .checking else { throw ShoeEnrollmentError.interrupted }
            try save(record)
            do { try await verifySetup(channel) }
            catch is CancellationError { throw CancellationError() }
            catch let error as AdaptError where error == .authentication { throw ShoeEnrollmentError.notReady }
            // Mark intent durably before the first enrollment command. If this is
            // interrupted, no automatic retry may start another exchange.
            record.phase = .exchangeStarted
            try save(record)
            let group = try await channel.enrollmentGroup()
            let exchange = try ShoeEnrollmentExchange(group: group)
            record.group = group
            record.privateKey = try exchange.recoveryKey()
            record.publicKey = try exchange.publicKey()
            try save(record)
            try Task.checkCancellation()
            try await channel.exchangeEnrollmentKey(record.publicKey!, timeout: exchangeTimeout, onReady: onReady) { peer in
                record.peerPublicKey = peer
                record.candidateKey = try exchange.derive(peerPublicKey: peer)
                record.phase = .candidate
                try save(record)
            }
            guard let candidate = record.candidateKey else { throw ShoeEnrollmentError.storage }
            try await session.authenticate(key: candidate)
            record.phase = .verified
            try save(record)
            return record
        } catch {
            channel.close(error)
            throw error
        }
    }

    private static func verifySetup(_ channel: ShoeChannel) async throws {
        let nonce = try ShoeCrypto.nonce()
        let fields = try await channel.request(112, value: nonce)
        guard let proof = fields[1]?.bytes, let challenge = fields[2]?.bytes else { throw AdaptError.authentication }
        let clear = try ShoeCrypto.setupBlock(proof, decrypt: true)
        var difference: UInt8 = 0
        for index in 4..<16 { difference |= clear[index] ^ nonce[index] }
        guard difference == 0 else { throw AdaptError.authentication }
        _ = try await channel.request(113, value: ShoeCrypto.setupBlock(challenge))
    }
}

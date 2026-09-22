import Foundation

public enum ShoeFeature: String, CaseIterable, Identifiable {
    case autoLace, doubleTapUntie
    public var id: String { rawValue }
    public var title: String { self == .autoLace ? "Auto-Lace" : "Quick Unlace" }
}

/// Session-only confirmation, not a cached claim about the shoe's current state.
/// Reconnection invalidates these values until a setting is read or acknowledged.
public enum ShoeFeatureConfirmation: Equatable {
    case unknown
    case reading
    case applying
    case confirmed(Bool)
    case unsupported
    case unconfirmed(String)
}

/// A pair-wide switch must never call a partial or unknown result “off”.
public enum ShoePairFeatureState: Equatable {
    case unknown, reading, applying, mixed, unsupported, unconfirmed
    case confirmed(Bool)

    public init(_ states: [ShoeFeatureConfirmation]) {
        if states.contains(.applying) { self = .applying }
        else if states.contains(.reading) { self = .reading }
        else if states.contains(where: { if case .unconfirmed = $0 { return true }; return false }) { self = .unconfirmed }
        else if states.contains(.unsupported) { self = .unsupported }
        else if states.count != 2 || states.contains(.unknown) { self = .unknown }
        else if states.allSatisfy({ $0 == .confirmed(true) }) { self = .confirmed(true) }
        else if states.allSatisfy({ $0 == .confirmed(false) }) { self = .confirmed(false) }
        else { self = .mixed }
    }

    public var value: Bool? {
        if case .confirmed(let value) = self { return value }
        return nil
    }
}

public enum ShoeGestureError: Error, LocalizedError, Equatable {
    case unsupportedConfiguration, criticalBattery, activeSession, notConfirmed
    public var errorDescription: String? {
        switch self {
        case .unsupportedConfiguration: return "This shoe has a gesture setting OpenAdapt can’t change yet. Its setting was left unchanged."
        case .criticalBattery: return "Charge this shoe before changing its gesture setting."
        case .activeSession: return "The shoe is busy. Wait before changing its gesture setting."
        case .notConfirmed: return "The shoe did not confirm the Quick Unlace change. Check its setting before trying again."
        }
    }
}

/// Opcode 179 returns a repeated group, not a boolean. Keep every entry and
/// unknown enum value so an unfamiliar/multiple mapping never becomes “off”.
public struct ShoeGestureConfiguration: Equatable {
    public struct Entry: Equatable {
        public let classification: UInt32
        public let action: UInt32
    }
    public let entries: [Entry]
    public var doubleTapEnabled: Bool? {
        if entries == [Entry(classification: 2, action: 2)] { return true }
        if entries == [Entry(classification: 1, action: 1)] { return false }
        return nil
    }
    public init(payload: Data) throws {
        guard payload.count <= 64 else { throw AdaptError.malformedMessage }
        let bytes = [UInt8](payload)
        var index = 0
        func integer(until end: Int) throws -> UInt32 {
            var result: UInt32 = 0
            for shift in stride(from: 0, through: 28, by: 7) {
                guard index < end else { throw AdaptError.malformedMessage }
                let byte = bytes[index]; index += 1
                guard shift != 28 || byte <= 15 else { throw AdaptError.malformedMessage }
                result |= UInt32(byte & 127) << shift
                if byte < 128 {
                    guard shift == 0 || byte != 0 else { throw AdaptError.malformedMessage }
                    return result
                }
            }
            throw AdaptError.malformedMessage
        }
        var entries: [Entry] = []
        while index < bytes.count {
            guard try integer(until: bytes.count) == 10 else { throw AdaptError.malformedMessage }
            let size = Int(try integer(until: bytes.count))
            guard size <= bytes.count - index else { throw AdaptError.malformedMessage }
            let end = index + size
            var classification: UInt32?, action: UInt32?
            while index < end {
                let tag = try integer(until: end)
                switch tag {
                case 8:
                    guard classification == nil else { throw AdaptError.malformedMessage }
                    classification = try integer(until: end)
                case 16:
                    guard action == nil else { throw AdaptError.malformedMessage }
                    action = try integer(until: end)
                default: throw AdaptError.malformedMessage
                }
            }
            entries.append(Entry(classification: classification ?? 0, action: action ?? 0))
        }
        self.entries = entries
    }
}

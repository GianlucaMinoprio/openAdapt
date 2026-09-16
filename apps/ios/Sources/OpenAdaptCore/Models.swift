import Foundation

public enum AdaptError: Error, LocalizedError, Equatable {
    case invalidProfile, unsupportedFirmware, malformedMessage, sequence, authentication
    case disconnected, timeout, busy, unavailable, lowBattery, charging, calibration, movement
    public var errorDescription: String? {
        switch self {
        case .invalidProfile: return "This file needs a verified Auto Max pair, its existing keys, and current fit calibration."
        case .unsupportedFirmware: return "This version supports Auto Max firmware 2.4.3M."
        case .malformedMessage, .sequence: return "The shoe returned an unexpected response. Disconnect and try connecting again."
        case .authentication: return "The saved key did not authenticate this shoe. Check the selected left or right shoe."
        case .disconnected: return "The shoe disconnected. Connect again to continue."
        case .timeout: return "The shoe did not respond in time. Wake it and connect again."
        case .busy: return "Wait for the current adjustment to finish."
        case .unavailable: return "Bluetooth is unavailable. Check Bluetooth access in Settings."
        case .lowBattery: return "Charge the shoe to at least 20% before adjusting its fit."
        case .charging: return "Take the shoe off the charger before adjusting its fit."
        case .calibration: return "The shoe's position does not match its saved fit calibration."
        case .movement: return "The shoe did not confirm the requested fit. Check the shoe before trying again."
        }
    }
}

public enum ShoeSide: String, Codable, CaseIterable, Identifiable {
    case left, right
    public var id: String { rawValue }
    public var letter: String { self == .left ? "L" : "R" }
    public var title: String { self == .left ? "Left" : "Right" }
}

public struct ShoeCredential: Codable, Equatable {
    public let profile: String
    public let credentialStatus: String
    public let advertisedName: String
    public let keyHex: String
    public let fitMaximum: Int
    // Linux MAC addresses cannot be used as CoreBluetooth identifiers.
    public let address: String
    enum CodingKeys: String, CodingKey {
        case profile, address
        case credentialStatus = "credential_status", advertisedName = "advertised_name"
        case keyHex = "key_hex", fitMaximum = "fit_maximum"
    }
    public var key: Data { Data(hex: keyHex) ?? Data() }
    public func validate() throws {
        guard profile == "auto-max-2.4.3M", credentialStatus == "hardware-verified",
              advertisedName.range(of: "^004-[A-Z0-9]+-[0-9]{3}$", options: .regularExpression) != nil,
              address.range(of: "^(?:[A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2}$", options: .regularExpression) != nil,
              (1...100).contains(fitMaximum), keyHex.count == 32 else { throw AdaptError.invalidProfile }
        try ShoeCrypto.validate(key: key)
    }
}

public struct ShoePair: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public let shoes: [String: ShoeCredential]
    public func credential(_ side: ShoeSide) -> ShoeCredential { shoes[side.rawValue]! }
    public func validate() throws {
        guard id.range(of: "^[a-z0-9][a-z0-9-]{0,63}$", options: .regularExpression) != nil,
              (1...60).contains(name.count), Set(shoes.keys) == Set(["left", "right"]),
              shoes["left"]?.address.uppercased() != shoes["right"]?.address.uppercased(),
              shoes["left"]?.key != shoes["right"]?.key else { throw AdaptError.invalidProfile }
        try shoes.values.forEach { try $0.validate() }
    }
}

public enum ProfileImport {
    private struct File: Decodable {
        let version: Int
        let shoes: [String: ShoeCredential]?
        let pairs: [ShoePair]?
    }
    public static func decode(_ data: Data) throws -> [ShoePair] {
        guard data.count <= 262_144 else { throw AdaptError.invalidProfile }
        do {
            let file = try JSONDecoder().decode(File.self, from: data)
            let pairs: [ShoePair]
            switch file.version {
            case 1:
                guard let shoes = file.shoes else { throw AdaptError.invalidProfile }
                pairs = [ShoePair(id: "auto-max", name: "Auto Max", shoes: shoes)]
            case 2:
                guard let entries = file.pairs else { throw AdaptError.invalidProfile }
                pairs = entries
            default: throw AdaptError.invalidProfile
            }
            guard !pairs.isEmpty, pairs.count <= 20, Set(pairs.map(\.id)).count == pairs.count else {
                throw AdaptError.invalidProfile
            }
            try pairs.forEach { try $0.validate() }
            return pairs
        } catch { throw AdaptError.invalidProfile }
    }
}

public enum FitScale {
    public static func rawTarget(percent: Int, maximum: Int) throws -> Int {
        guard (0...100).contains(percent), (1...100).contains(maximum) else { throw AdaptError.calibration }
        return (percent * maximum + 50) / 100
    }
    public static func percent(raw: Int, maximum: Int) -> Double {
        guard maximum > 0 else { return 0 }
        return min(100, max(0, Double(raw) / Double(maximum) * 100))
    }
    public static func snapped(_ value: Double) -> Int { min(100, max(0, Int((value / 5).rounded()) * 5)) }
}

public struct ShoeStatus: Equatable {
    public let battery: Int
    public let charger: Int
    public let rawPosition: Int
    public init(battery: Int, charger: Int, rawPosition: Int) {
        self.battery = battery; self.charger = charger; self.rawPosition = rawPosition
    }
}

extension Data {
    public init?(hex: String) {
        guard hex.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex {
            let end = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<end], radix: 16) else { return nil }
            bytes.append(byte); index = end
        }
        self.init(bytes)
    }
}

import Foundation

/// Retail names are independent of verified Bluetooth/control compatibility.
public enum ShoeModel: String, Codable, CaseIterable, Identifiable {
    case adaptBB, adaptBB2, adaptHuarache, adaptAutoMax, jordan11Adapt
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .adaptBB: return "Nike Adapt BB"
        case .adaptBB2: return "Nike Adapt BB 2.0"
        case .adaptHuarache: return "Nike Adapt Huarache"
        case .adaptAutoMax: return "Nike Adapt Auto Max"
        case .jordan11Adapt: return "Air Jordan 11 Adapt"
        }
    }
    public static func detected(advertisedName: String) -> Self? {
        guard advertisedName.range(of: "^[0-9]{3}-[A-Z0-9]+-[0-9]{3}$", options: .regularExpression) != nil else { return nil }
        // Product IDs from the archived app manifest, independently of firmware support.
        switch advertisedName.prefix(3) {
        case "001": return .adaptBB
        case "002": return .adaptHuarache
        case "004": return .adaptAutoMax
        case "005": return .adaptBB2
        case "006", "007": return .jordan11Adapt
        default: return nil
        }
    }
    public func isDefaultName(_ value: String) -> Bool {
        func normalized(_ text: String) -> String {
            text.lowercased().filter { $0.isLetter || $0.isNumber }
        }
        let value = normalized(value)
        let full = normalized(name)
        return value == full || value == normalized(name.replacingOccurrences(of: "Nike ", with: ""))
            || (self == .adaptAutoMax && value == "automax")
            || (self == .adaptBB2 && ["nikeadaptbb2", "adaptbb2"].contains(value))
            || (self == .jordan11Adapt && ["airjordanxiadapt", "jordanxiadapt", "jordan11adapt"].contains(value))
    }
}

public enum ShoeColorway: String, Codable, CaseIterable, Identifiable {
    case blackBlue, whiteBlack, blackTeal, greyRed, whiteRed, navyBlue
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .blackBlue: return "Black / Blue"
        case .whiteBlack: return "White / Black"
        case .blackTeal: return "Black / Teal"
        case .greyRed: return "Grey / Red"
        case .whiteRed: return "White / Red"
        case .navyBlue: return "Navy / Blue"
        }
    }
}

extension ShoePair {
    public var model: ShoeModel? {
        let models = shoes.values.compactMap { ShoeModel.detected(advertisedName: $0.advertisedName) }
        guard models.count == shoes.count, let first = models.first, models.allSatisfy({ $0 == first }) else { return nil }
        return first
    }
    public var displayName: String { model?.isDefaultName(name) == true ? model!.name : name }
    public var modelSubtitle: String? { model?.isDefaultName(name) == true ? nil : model?.name }
}

import Foundation
import Security

/// All imported credentials and identifiers stay in device-only Keychain storage.
struct PairVault {
    private let service = "org.openadapt.ios.pairs"
    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service, kSecAttrAccount as String: "catalog"] }
    func load() throws -> [ShoePair] {
        var read = query
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data else { throw VaultError.storage }
        let pairs = try JSONDecoder().decode([ShoePair].self, from: data)
        try pairs.forEach { try $0.validate() }
        return pairs
    }
    func save(_ pairs: [ShoePair]) throws {
        try pairs.forEach { try $0.validate() }
        let data = try JSONEncoder().encode(pairs)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw VaultError.storage }
        } else if status != errSecSuccess { throw VaultError.storage }
    }
    /// The optional owner resource is supplied locally and is never copied into Release.
    /// Existing Keychain data wins. A removed pair is never silently reimported.
    func loadWithLocalDefault() throws -> [ShoePair] {
        let saved = try load()
        #if DEBUG
        let receipt = "ownerPairingInstalled"
        if saved.isEmpty, !UserDefaults.standard.bool(forKey: receipt),
           let url = Bundle.main.url(forResource: "OwnerPairing.private", withExtension: "json") {
            let pairs = try ProfileImport.decode(Data(contentsOf: url))
            try save(pairs)
            UserDefaults.standard.set(true, forKey: receipt)
            return pairs
        }
        #endif
        return saved
    }
    enum VaultError: LocalizedError {
        case storage
        var errorDescription: String? { "Your shoe profiles could not be accessed in Keychain. Unlock your iPhone and try again." }
    }
}

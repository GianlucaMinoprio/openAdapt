import Foundation
import Security

/// Append/replace individual attempt records atomically, separate from saved pairs.
/// Interrupted attempts survive app termination and never overwrite a saved shoe.
@MainActor
struct EnrollmentVault {
    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "org.openadapt.ios.enrollment", kSecAttrAccount as String: "attempts"] }
    func load() throws -> [ShoeEnrollmentRecord] {
        var query = query
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data, data.count <= 262_144 else { throw ShoeEnrollmentError.storage }
        let records = try JSONDecoder().decode([ShoeEnrollmentRecord].self, from: data)
        try records.forEach { try $0.validate() }
        return records
    }
    func save(_ record: ShoeEnrollmentRecord) throws {
        try record.validate()
        var records = try load()
        if let index = records.firstIndex(where: { $0.id == record.id }) { records[index] = record }
        else {
            guard records.count < 100 else { throw ShoeEnrollmentError.storage }
            records.append(record)
        }
        try write(records)
    }
    func removeSaved(_ ids: Set<UUID>) throws {
        try write(load().filter { !ids.contains($0.id) })
    }
    private func write(_ records: [ShoeEnrollmentRecord]) throws {
        let data = try JSONEncoder().encode(records)
        guard data.count <= 262_144 else { throw ShoeEnrollmentError.storage }
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            // A manual screen lock during the button wait must not prevent
            // saving a peer response that has already changed the shoe's key.
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw ShoeEnrollmentError.storage }
        } else if status != errSecSuccess { throw ShoeEnrollmentError.storage }
    }
}

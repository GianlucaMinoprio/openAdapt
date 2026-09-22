import Foundation
import CommonCrypto
import Security

public enum ShoeCrypto {
    public static func validate(key: Data) throws {
        guard key.count == 16, key != Data(repeating: 1, count: 16) else { throw AdaptError.invalidProfile }
    }
    public static func nonce() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw AdaptError.authentication
        }
        return Data(bytes)
    }
    // AES-ECB is required only for the shoe's legacy single-block challenge protocol.
    public static func crypt(_ block: Data, key: Data, decrypt: Bool = false) throws -> Data {
        try validate(key: key)
        return try legacyBlock(block, key: key, decrypt: decrypt)
    }
    static func setupBlock(_ block: Data, decrypt: Bool = false) throws -> Data {
        try legacyBlock(block, key: Data(repeating: 1, count: 16), decrypt: decrypt)
    }
    private static func legacyBlock(_ block: Data, key: Data, decrypt: Bool) throws -> Data {
        guard block.count == 16 else { throw AdaptError.authentication }
        var output = [UInt8](repeating: 0, count: 16)
        var length = 0
        let status = key.withUnsafeBytes { keyBytes in
            block.withUnsafeBytes { input in
                CCCrypt(CCOperation(decrypt ? kCCDecrypt : kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode), keyBytes.baseAddress, 16, nil,
                        input.baseAddress, 16, &output, output.count, &length)
            }
        }
        guard status == kCCSuccess, length == 16 else { throw AdaptError.authentication }
        return Data(output)
    }
    public static func verify(proof: Data, nonce: Data, key: Data) throws {
        guard nonce.count == 16 else { throw AdaptError.authentication }
        let clear = try crypt(proof, key: key, decrypt: true)
        var difference: UInt8 = 0
        // Explicit Auto Max 2.4.3M format: only the final 96 challenge bits are echoed.
        for index in 4..<16 { difference |= clear[index] ^ nonce[index] }
        guard difference == 0 else { throw AdaptError.authentication }
    }
    public static func verifyFirmware(_ data: Data) throws {
        let revision = Data("2.4.3M".utf8)
        guard data == revision || data == revision + Data(repeating: 0, count: 14) else {
            throw AdaptError.unsupportedFirmware
        }
    }
}

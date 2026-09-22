import Foundation
import CryptoKit
import CCryptoBoringSSL

/// Legacy MODP/MD5 interoperability. Arithmetic and randomness come from
/// Swift Crypto's pinned BoringSSL implementation, not custom big integers.
public final class ShoeEnrollmentExchange {
    public let group: Int
    private let handle: OpaquePointer
    private static let primes: [String] = [
        "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A63A3620FFFFFFFFFFFFFFFF",
        "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE65381FFFFFFFFFFFFFFFF",
        "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA237327FFFFFFFFFFFFFFFF",
        "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AACAA68FFFFFFFFFFFFFFFF",
    ]
    public init(group: Int, restoring privateKey: Data? = nil) throws {
        guard Self.primes.indices.contains(group), let dh = CCryptoBoringSSL_DH_new() else {
            throw AdaptError.authentication
        }
        guard let p = Self.number(Data(hex: Self.primes[group])!) else {
            CCryptoBoringSSL_DH_free(dh); throw AdaptError.authentication
        }
        guard let g = Self.number(Data([2])) else {
            CCryptoBoringSSL_BN_free(p); CCryptoBoringSSL_DH_free(dh); throw AdaptError.authentication
        }
        guard CCryptoBoringSSL_DH_set0_pqg(dh, p, nil, g) == 1 else {
            CCryptoBoringSSL_BN_free(p); CCryptoBoringSSL_BN_free(g)
            CCryptoBoringSSL_DH_free(dh); throw AdaptError.authentication
        }
        if let privateKey {
            guard !privateKey.isEmpty, privateKey.count <= Self.primes[group].count / 2,
                  let key = Self.number(privateKey) else {
                CCryptoBoringSSL_DH_free(dh); throw AdaptError.authentication
            }
            guard CCryptoBoringSSL_BN_cmp(key, g) >= 0, CCryptoBoringSSL_BN_cmp(key, p) < 0,
                  CCryptoBoringSSL_DH_set0_key(dh, nil, key) == 1 else {
                CCryptoBoringSSL_BN_clear_free(key); CCryptoBoringSSL_DH_free(dh)
                throw AdaptError.authentication
            }
        }
        guard CCryptoBoringSSL_DH_generate_key(dh) == 1 else {
            CCryptoBoringSSL_DH_free(dh); throw AdaptError.authentication
        }
        var flags: Int32 = 0
        guard let publicKey = CCryptoBoringSSL_DH_get0_pub_key(dh),
              CCryptoBoringSSL_DH_check_pub_key(dh, publicKey, &flags) == 1, flags == 0 else {
            CCryptoBoringSSL_DH_free(dh); throw AdaptError.authentication
        }
        self.group = group; handle = dh
    }
    deinit { CCryptoBoringSSL_DH_free(handle) }

    public func publicKey() throws -> Data { try Self.bytes(CCryptoBoringSSL_DH_get0_pub_key(handle)) }
    /// Store only in device-only Keychain, before transmitting the public value.
    public func recoveryKey() throws -> Data { try Self.bytes(CCryptoBoringSSL_DH_get0_priv_key(handle)) }

    public func derive(peerPublicKey: Data) throws -> Data {
        let width = Int(CCryptoBoringSSL_DH_size(handle))
        guard (1...width).contains(peerPublicKey.count), let peer = Self.number(peerPublicKey) else {
            throw AdaptError.authentication
        }
        defer { CCryptoBoringSSL_BN_free(peer) }
        var flags: Int32 = 0
        guard CCryptoBoringSSL_DH_check_pub_key(handle, peer, &flags) == 1, flags == 0 else {
            throw AdaptError.authentication
        }
        var shared = Data(count: width)
        defer { shared.resetBytes(in: 0..<shared.count) }
        let count = shared.withUnsafeMutableBytes { raw in
            CCryptoBoringSSL_DH_compute_key_padded(raw.bindMemory(to: UInt8.self).baseAddress, peer, handle)
        }
        guard count == width else { throw AdaptError.authentication }
        let key = Data(Insecure.MD5.hash(data: shared))
        try ShoeCrypto.validate(key: key)
        return key
    }
    private static func number(_ bytes: Data) -> UnsafeMutablePointer<BIGNUM>? {
        bytes.withUnsafeBytes { CCryptoBoringSSL_BN_bin2bn($0.bindMemory(to: UInt8.self).baseAddress, bytes.count, nil) }
    }
    private static func bytes(_ number: UnsafePointer<BIGNUM>?) throws -> Data {
        guard let number else { throw AdaptError.authentication }
        var data = Data(count: Int(CCryptoBoringSSL_BN_num_bytes(number)))
        let count = data.withUnsafeMutableBytes {
            CCryptoBoringSSL_BN_bn2bin(number, $0.bindMemory(to: UInt8.self).baseAddress)
        }
        guard count == data.count, !data.isEmpty else { throw AdaptError.authentication }
        return data
    }
}

"""Original enrollment cryptography; legacy algorithms for interoperability only."""
import hashlib
import hmac
from enum import Enum
from cryptography.hazmat.primitives.asymmetric import dh

# RFC 2409 sections 6.1/6.2; RFC 3526 sections 2/3 (not Nike code).
PRIMES = tuple(int(value, 16) for value in ('FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A63A3620FFFFFFFFFFFFFFFF', 'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE65381FFFFFFFFFFFFFFFF', 'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA237327FFFFFFFFFFFFFFFF', 'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AACAA68FFFFFFFFFFFFFFFF'))

class Exchange:
    def __init__(self, group, *, private=None):
        if group not in range(4):
            raise ValueError("unsupported MODP group")
        self.group = group
        self.parameters = dh.DHParameterNumbers(PRIMES[group], 2)
        self._private = private or self.parameters.parameters().generate_private_key()
        y = self._private.public_key().public_numbers().y
        self.public = y.to_bytes((y.bit_length()+7)//8, "big")

    def derive(self, peer):
        y = int.from_bytes(peer, "big")
        p = self.parameters.p
        if not 1 <= len(peer) <= (p.bit_length()+7)//8 or not 2 <= y <= p-2:
            raise ValueError("invalid DH peer")
        public = dh.DHPublicNumbers(y, self.parameters).public_key()
        secret = self._private.exchange(public)
        return hashlib.md5(secret, usedforsecurity=False).digest()

def encrypt(key, nonce):
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    if len(key) != 16 or len(nonce) != 16:
        raise ValueError("invalid AES block or key length")
    ctx = Cipher(algorithms.AES(key), modes.ECB()).encryptor()
    return ctx.update(nonce) + ctx.finalize()


class ProofFormat(Enum):
    FULL_BLOCK = "full-block"
    AUTO_MAX_2_4_3M = "auto-max-2.4.3M-suffix96"


def verify_peer_proof(key, nonce, proof, *, proof_format=ProofFormat.FULL_BLOCK):
    """Verify a challenge without treating an unknown prefix as authenticated data.

    Captured Auto Max 2.4.3M responses decrypt to an opaque four-byte prefix and
    the last twelve bytes of the client's nonce. The explicit compatibility
    format verifies those 96 challenge bits; it does not interpret the prefix.
    This is not enabled by a failed full-block comparison or by a default key.
    Callers must generate a fresh, cryptographically random 16-byte nonce.
    """
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    if not isinstance(proof_format, ProofFormat):
        raise ValueError("unsupported peer proof format")
    if any(not isinstance(block, bytes) or len(block) != 16 for block in (key, nonce, proof)):
        raise ValueError("invalid AES block or key length")
    if proof_format is ProofFormat.FULL_BLOCK:
        matches = hmac.compare_digest(proof, encrypt(key, nonce))
    else:
        ctx = Cipher(algorithms.AES(key), modes.ECB()).decryptor()
        clear = ctx.update(proof) + ctx.finalize()
        matches = hmac.compare_digest(clear[4:], nonce[4:])
    if not matches:
        raise ValueError("peer nonce proof mismatch")

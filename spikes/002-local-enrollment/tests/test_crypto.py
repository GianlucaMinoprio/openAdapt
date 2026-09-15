import hashlib
import pytest
from cryptography.hazmat.primitives.asymmetric import dh

@pytest.mark.parametrize("group,width", [(0,96),(1,128),(2,192),(3,256)])
def test_dh_java_fixed_width_secret(feature, group, width):
    DH = feature("crypto", "Exchange")
    prime = feature("crypto", "PRIMES")[group]
    params = dh.DHParameterNumbers(prime, 2)
    # Deliberately tiny, SYNTHETIC exponent: 8**2 = 64. Never live entropy.
    private = dh.DHPrivateNumbers(2, dh.DHPublicNumbers(4, params)).private_key()
    exchange = DH(group, private=private)
    assert exchange.public == b"\x04"
    expected_secret = bytes(width-1)+b"\x40"
    assert exchange.derive(b"\x08") == hashlib.md5(expected_secret).digest()
    assert prime.bit_length() == width*8

@pytest.mark.parametrize("group", [-1,4,255])
def test_unsupported_dh_group(feature, group):
    DH = feature("crypto", "Exchange")
    with pytest.raises(ValueError):
        DH(group)

@pytest.mark.parametrize("peer", [b"",b"\x00",b"\x01",bytes(257)])
def test_invalid_dh_public(feature, peer):
    DH = feature("crypto", "Exchange")
    with pytest.raises(ValueError):
        DH(0).derive(peer)

def test_aes_fips197_golden(feature):
    aes = feature("crypto", "encrypt")
    # FIPS 197 Appendix C.1 AES-128 example, public standard test vector.
    assert aes(bytes.fromhex("000102030405060708090a0b0c0d0e0f"), bytes.fromhex("00112233445566778899aabbccddeeff")) == bytes.fromhex("69c4e0d86a7b0430d8cdb78070b4c55a")
    for key,nonce in [(bytes(15),bytes(16)), (bytes(16),b""), (bytes(16),bytes(32))]:
        with pytest.raises(ValueError):
            aes(key,nonce)

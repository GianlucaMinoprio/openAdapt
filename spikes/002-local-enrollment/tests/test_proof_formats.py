"""Synthetic negative checks for the explicitly selected Auto Max proof format."""
import pytest

from crypto import encrypt


KEY = bytes(range(16))
NONCE = bytes(range(16, 32))


def test_full_block_remains_default_and_rejects_changed_prefix(feature):
    verify = feature("crypto", "verify_peer_proof")
    verify(KEY, NONCE, encrypt(KEY, NONCE))
    with pytest.raises(ValueError, match="proof mismatch"):
        verify(KEY, NONCE, encrypt(KEY, b"HEAD" + NONCE[4:]))


@pytest.mark.parametrize("prefix", [b"HEAD", bytes(4), b"\xff" * 4])
def test_explicit_auto_max_format_checks_nonce_suffix(feature, prefix):
    verify = feature("crypto", "verify_peer_proof")
    mode = feature("crypto", "ProofFormat").AUTO_MAX_2_4_3M
    verify(KEY, NONCE, encrypt(KEY, prefix + NONCE[4:]), proof_format=mode)


@pytest.mark.parametrize("offset", range(4, 16))
def test_every_compared_nonce_byte_is_enforced(feature, offset):
    verify = feature("crypto", "verify_peer_proof")
    mode = feature("crypto", "ProofFormat").AUTO_MAX_2_4_3M
    changed = bytearray(b"HEAD" + NONCE[4:])
    changed[offset] ^= 1
    with pytest.raises(ValueError, match="proof mismatch"):
        verify(KEY, NONCE, encrypt(KEY, bytes(changed)), proof_format=mode)


def test_wrong_key_and_replayed_nonce_are_rejected(feature):
    verify = feature("crypto", "verify_peer_proof")
    mode = feature("crypto", "ProofFormat").AUTO_MAX_2_4_3M
    proof = encrypt(KEY, b"HEAD" + NONCE[4:])
    for key, nonce in [(KEY[::-1], NONCE), (KEY, NONCE[::-1])]:
        with pytest.raises(ValueError, match="proof mismatch"):
            verify(key, nonce, proof, proof_format=mode)


@pytest.mark.parametrize("key,nonce,proof", [
    (KEY[:-1], NONCE, bytes(16)),
    (KEY, NONCE[:-1], bytes(16)),
    (KEY, NONCE, bytes(15)),
    (KEY, NONCE, bytes(32)),
])
def test_proof_lengths_fail_before_comparison(feature, key, nonce, proof):
    with pytest.raises(ValueError):
        feature("crypto", "verify_peer_proof")(key, nonce, proof)


def test_unrecognized_proof_format_is_not_a_fallback(feature):
    with pytest.raises(ValueError):
        feature("crypto", "verify_peer_proof")(
            KEY, NONCE, encrypt(KEY, NONCE), proof_format="skip")

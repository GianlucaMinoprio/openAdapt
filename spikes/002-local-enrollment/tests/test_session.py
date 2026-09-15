"""Synthetic authentication, preservation, and interrupted-enrollment checks."""
import asyncio
import json

import pytest

from crypto import encrypt
from keyfile import Store, load


KEY = bytes(range(16))


class Peer:
    def __init__(self, failure=None):
        self.calls = []
        self.closed = False
        self.failure = failure

    async def request(self, opcode, value=b""):
        self.calls.append((opcode, value))
        if opcode == self.failure:
            raise TimeoutError()
        if opcode == 110:
            return {1: 0}
        if opcode == 111:
            return {1: b"\x08"}
        if opcode == 112:
            proof = encrypt(KEY, value) if self.failure != "proof" else bytes(16)
            return {1: proof, 2: b"D" * 16}
        if opcode == 113:
            assert value == encrypt(KEY, b"D" * 16)
            return {}
        raise AssertionError("unapproved opcode")

    def close(self):
        self.closed = True


class SyntheticExchange:
    public = b"\x04"

    def __init__(self, group):
        assert group == 0

    def derive(self, peer):
        assert peer == b"\x08"
        return KEY


async def test_existing_key_authentication_has_no_enrollment_or_followup(feature):
    Session = feature("session", "Session")
    peer = Peer()
    session = Session(peer)
    await session.authenticate_existing(KEY)
    assert [op for op, _ in peer.calls] == [112, 113]
    assert session.state == "authenticated"
    with pytest.raises(ValueError):
        await session.authenticate_existing(KEY)
    assert len(peer.calls) == 2


@pytest.mark.parametrize("key", [None, b"", b"short", b"\x01" * 16])
async def test_invalid_key_never_starts_exchange(feature, key):
    peer = Peer()
    session = feature("session", "Session")(peer)
    with pytest.raises(ValueError):
        await session.authenticate_existing(key)
    assert not peer.calls


async def test_mismatched_peer_proof_stops_before_challenge(feature):
    peer = Peer("proof")
    session = feature("session", "Session")(peer)
    with pytest.raises(ValueError, match="proof"):
        await session.authenticate_existing(KEY)
    assert [op for op, _ in peer.calls] == [112]
    assert peer.closed and session.state == "failed"


@pytest.mark.parametrize("failure", [None, 112, 113])
async def test_candidate_saved_before_authentication_and_preserved_on_failure(feature, tmp_path, failure):
    peer = Peer(failure)
    path = tmp_path / "vault" / "candidate.json"
    session = feature("session", "Session")(peer, exchange_factory=SyntheticExchange)
    with Store(path) as store:
        if failure:
            with pytest.raises(TimeoutError):
                await session.enroll(store, "synthetic", synthetic=True)
        else:
            await session.enroll(store, "synthetic", synthetic=True)
    assert load(path, "synthetic", allow_synthetic=True) == KEY
    assert json.loads(path.read_text())["status"] == "UNVERIFIED"
    assert [op for op, _ in peer.calls][:2] == [110, 111]


async def test_storage_failure_stops_before_authentication(feature):
    class BrokenStore:
        def save(self, *args, **kwargs):
            raise OSError("synthetic disk error")
    peer = Peer()
    session = feature("session", "Session")(peer, exchange_factory=SyntheticExchange)
    with pytest.raises(OSError):
        await session.enroll(BrokenStore(), "synthetic", synthetic=True)
    assert [op for op, _ in peer.calls] == [110, 111]
    assert peer.closed


async def test_cancellation_closes_session_without_retry(feature):
    entered = asyncio.Event()
    class HangingPeer(Peer):
        async def request(self, opcode, value=b""):
            self.calls.append((opcode, value))
            entered.set()
            await asyncio.Event().wait()
    peer = HangingPeer()
    session = feature("session", "Session")(peer)
    task = asyncio.create_task(session.authenticate_existing(KEY))
    await entered.wait()
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
    assert peer.closed and session.state == "failed"
    with pytest.raises(ValueError):
        await session.authenticate_existing(KEY)
    assert len(peer.calls) == 1

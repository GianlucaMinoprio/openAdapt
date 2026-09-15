"""Synthetic Auto Max setup and interrupted key-persistence boundaries."""
import json

import pytest

from crypto import ProofFormat, encrypt
from keyfile import Store, load
from session import Session
from simulation import SyntheticPeer


MODE = ProofFormat.AUTO_MAX_2_4_3M
KEY = bytes(range(16))


@pytest.mark.parametrize("group", [1, 2])
async def test_auto_max_sequence_event_and_new_key_reconnect(tmp_path, group):
    peer = SyntheticPeer(group, auto_max=True)
    session = Session(peer.channel, proof_format=MODE)
    path = tmp_path / "vault" / "candidate.json"
    events = []
    with Store(path) as store:
        await session.enroll_auto_max(store, "synthetic", synthetic=True,
                                     on_key_exchange_ready=lambda: events.append("ready"))
    assert session.state == "authenticated"
    assert events == ["ready"] and session.events == ["key-exchange-ready"]
    assert peer.commands == [112, 113, 110, 111, 112, 113]
    assert json.loads(path.read_text())["status"] == "UNVERIFIED"
    key = load(path, "synthetic", allow_synthetic=True)
    assert key == peer.key
    existing = SyntheticPeer(key=key, auto_max=True)
    await Session(existing.channel, proof_format=MODE).authenticate_existing(key)
    assert existing.commands == [112, 113]


class Exchange:
    public = b"\x04"
    def __init__(self, group):
        assert group == 1
    def derive(self, peer):
        assert peer == b"\x08"
        return KEY


class Peer:
    def __init__(self, failure=None, path=None):
        self.key = b"\x01" * 16
        self.failure = failure
        self.path = path
        self.calls = []
        self.closed = False

    async def request(self, opcode, value=b""):
        self.calls.append(opcode)
        if opcode == 112:
            if self.key == KEY:
                assert self.path.exists(), "candidate must be saved before new-key auth"
            if (self.failure == "setup-proof" and self.key != KEY
                    or self.failure == "new-proof" and self.key == KEY):
                return {1: bytes(16), 2: b"D" * 16}
            return {1: encrypt(self.key, b"TEST" + value[4:]), 2: b"D" * 16}
        if opcode == 113:
            assert value == encrypt(self.key, b"D" * 16)
            return {}
        if opcode == 110:
            return {1: 1}
        raise AssertionError("unexpected request")

    async def exchange_public_key(self, value, *, on_ready):
        self.calls.append(111)
        assert value == b"\x04"
        on_ready()
        if self.failure == "exchange":
            raise TimeoutError()
        self.key = KEY
        return {1: b"\x08"}

    def close(self):
        self.closed = True


@pytest.mark.parametrize("failure,expected,retained", [
    ("setup-proof", [112], False),
    ("exchange", [112, 113, 110, 111], False),
    ("new-proof", [112, 113, 110, 111, 112], True),
])
async def test_failed_setup_does_not_retry_or_discard_candidate(tmp_path, failure, expected, retained):
    path = tmp_path / "vault" / "candidate.json"
    peer = Peer(failure, path)
    session = Session(peer, proof_format=MODE, exchange_factory=Exchange)
    with Store(path) as store:
        with pytest.raises((ValueError, TimeoutError)):
            await session.enroll_auto_max(store, "synthetic", synthetic=True)
        with pytest.raises(ValueError):
            await session.enroll_auto_max(store, "synthetic", synthetic=True)
    assert peer.calls == expected
    assert peer.closed and session.state == "failed"
    assert path.exists() == retained
    if retained:
        assert load(path, "synthetic", allow_synthetic=True) == KEY


async def test_storage_failure_prevents_new_key_authentication():
    class BrokenStore:
        def save(self, *args, **kwargs):
            raise OSError("synthetic disk failure")
    peer = Peer()
    session = Session(peer, proof_format=MODE, exchange_factory=Exchange)
    with pytest.raises(OSError):
        await session.enroll_auto_max(BrokenStore(), "synthetic", synthetic=True)
    assert peer.calls == [112, 113, 110, 111]
    assert peer.closed


async def test_setup_key_still_rejected_by_existing_key_entrypoint():
    peer = Peer()
    with pytest.raises(ValueError):
        await Session(peer, proof_format=MODE).authenticate_existing(b"\x01" * 16)
    assert not peer.calls


async def test_auto_max_requires_explicit_proof_format_before_any_request():
    peer = Peer()
    with pytest.raises(ValueError, match="explicit"):
        await Session(peer).enroll_auto_max(None, "synthetic", synthetic=True)
    assert not peer.calls


async def test_async_observer_is_rejected_before_setup_authentication():
    peer = Peer()
    async def observer():
        pass
    with pytest.raises(ValueError, match="synchronous"):
        await Session(peer, proof_format=MODE).enroll_auto_max(None, "synthetic", on_key_exchange_ready=observer)
    assert not peer.calls

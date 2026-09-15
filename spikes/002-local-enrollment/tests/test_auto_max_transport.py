"""Synthetic regressions for transport behavior observed in owned iPhone traces."""
import pytest

from transport import Transport, segments
from wire import encode


async def test_flow_packet_does_not_cause_ack_of_first_data_fragment(feature):
    profile = feature("transport", "TransportProfile").AUTO_MAX_CAPTURE
    writes = []
    async def write(packet):
        writes.append(packet)
        if packet[0] == 0x81:
            channel.notify(b"\xc1\x00")
            for reply in segments(encode(112, 1, b"\x0a\x10" + b"A" * 16 + b"\x12\x10" + b"B" * 16), 0):
                channel.notify(reply)
    channel = Transport(write, timeout=0.1, profile=profile)
    assert await channel.request(112, bytes(16)) == {1: b"A" * 16, 2: b"B" * 16}
    assert [p for p in writes if p[0] & 64] == [b"\xc1\x00"]


async def test_four_unacknowledged_fragments_are_allowed_after_ack(feature):
    profile = feature("transport", "TransportProfile").AUTO_MAX_CAPTURE
    sent = []
    acknowledged_count = 0
    async def write(packet):
        nonlocal acknowledged_count
        if packet[0] & 64:
            return
        assert len(sent) - acknowledged_count < 4
        sent.append(packet)
        seq = packet[0] & 63
        if seq % 4 == 3:
            # ACKs arrive only after a full four-fragment window. Waiting after
            # three post-ACK fragments deadlocks even though the peer is ready.
            channel.notify(bytes([192 | (seq - 2), 0]))
            channel.notify(bytes([192 | seq, 0]))
            acknowledged_count = len(sent)
        if packet[0] & 128:
            if seq % 4 == 1:
                channel.notify(bytes([192 | seq, 0]))
            channel.notify(segments(encode(111, 1, b"\x0a\x01\x08"), 0)[0])
    channel = Transport(write, timeout=0.05, profile=profile)
    assert await channel.request(111, bytes(256)) == {1: b"\x08"}
    assert len(sent) == 14


async def test_captured_transport_profile_preserves_window_on_missing_ack(feature):
    profile = feature("transport", "TransportProfile").AUTO_MAX_CAPTURE
    writes = []
    async def write(packet):
        writes.append(packet)
    channel = Transport(write, timeout=0.005, profile=profile)
    with pytest.raises(TimeoutError):
        await channel.request(111, bytes(256))
    assert len(writes) == 4
    assert channel.closed


def test_transport_profile_must_be_explicitly_recognized():
    with pytest.raises(ValueError):
        Transport(None, profile="auto-detect")


async def test_auto_max_ack_sequences_wrap_across_repeated_handshakes():
    from crypto import ProofFormat
    from session import Session
    from simulation import SyntheticPeer
    key = bytes(range(16))
    peer = SyntheticPeer(key=key, auto_max=True)
    try:
        for _ in range(35):
            await Session(peer.channel, proof_format=ProofFormat.AUTO_MAX_2_4_3M).authenticate_existing(key)
        assert peer.channel.sent == 140 and peer.channel.tx_sequence == 12
        assert peer.commands == [112, 113] * 35
    finally:
        peer.channel.close()

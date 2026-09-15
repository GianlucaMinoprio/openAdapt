"""Synthetic failure paths and flow control; no BLE backend is constructed."""
import asyncio

import pytest

from transport import Transport, segments
from wire import encode


async def test_public_key_respects_window_and_consumes_flow_acks():
    writes = []
    last_ack = 0

    async def write(packet):
        nonlocal last_ack
        if packet[0] & 64:
            return
        seq = packet[0] & 63
        assert (seq - last_ack) % 64 < 4, "sender exceeded APK transmit window"
        writes.append(packet)
        if seq % 2:
            # Deliver asynchronously, so writing everything before receiving fails.
            async def acknowledge():
                nonlocal last_ack
                await asyncio.sleep(0)
                last_ack = seq
                channel.notify(bytes([192 | seq, 0]))
            asyncio.create_task(acknowledge())
        if packet[0] & 128:
            channel.notify(bytes.fromhex("806f03400a0108"))

    channel = Transport(write, timeout=0.2)
    assert await channel.request(111, bytes(256)) == {1: b"\x08"}
    assert len(writes) == 14


async def test_missing_window_ack_stops_before_fifth_fragment():
    writes = []
    async def write(packet):
        writes.append(packet)
    channel = Transport(write, timeout=0.01)
    with pytest.raises(TimeoutError):
        await channel.request(111, bytes(256))
    assert len(writes) == 4
    with pytest.raises(ValueError, match="closed"):
        await channel.request(110)
    assert len(writes) == 4


@pytest.mark.parametrize("failure", ["timeout", "cancel", "write", "overflow", "resend", "future-ack"])
async def test_failed_exchange_cannot_be_reused(failure):
    writes = []
    async def write(packet):
        writes.append(packet)
        if failure == "cancel":
            raise asyncio.CancelledError()
        if failure == "write":
            raise OSError("synthetic failure")
        if failure == "overflow":
            for _ in range(129):
                channel.notify(bytes.fromhex("806e0000"))
        if failure in ("resend", "future-ack"):
            channel.notify(bytes.fromhex("c001" if failure == "resend" else "c300"))
    channel = Transport(write, timeout=0.01)
    expected = {"timeout": TimeoutError, "cancel": asyncio.CancelledError, "write": OSError}.get(failure, ValueError)
    with pytest.raises(expected):
        await channel.request(110)
    previous = len(writes)
    with pytest.raises(ValueError, match="closed"):
        await channel.request(110)
    assert len(writes) == previous


async def test_stale_response_is_rejected_before_write():
    writes = []
    async def write(packet):
        writes.append(packet)
    channel = Transport(write)
    channel.notify(bytes.fromhex("806e02400803"))
    with pytest.raises(ValueError):
        await channel.request(110)
    assert not writes


async def test_concurrent_request_is_rejected_without_second_write():
    entered = asyncio.Event()
    writes = []
    async def write(packet):
        writes.append(packet)
        entered.set()
    channel = Transport(write, timeout=0.1)
    first = asyncio.create_task(channel.request(110))
    await entered.wait()
    try:
        with pytest.raises(ValueError, match="in progress"):
            await channel.request(110)
        channel.notify(bytes.fromhex("806e02400803"))
        assert await first == {1: 3}
        assert len(writes) == 1
    finally:
        if not first.done():
            first.cancel()
            with pytest.raises(asyncio.CancelledError):
                await first


@pytest.mark.parametrize("timeout", [0, -1, float("nan"), float("inf"), 121])
def test_transport_requires_bounded_timeout(timeout):
    with pytest.raises(ValueError):
        Transport(None, timeout=timeout)


async def test_malformed_response_does_not_send_flow_ack():
    writes = []
    async def write(packet):
        writes.append(packet)
        if not packet[0] & 64:
            # Correct envelope and segmentation, wrong nonce fields.
            for reply in segments(encode(112, 1, b"x" * 20), 0):
                channel.notify(reply)
    channel = Transport(write, timeout=0.1)
    with pytest.raises(ValueError):
        await channel.request(112, bytes(16))
    assert all(not packet[0] & 64 for packet in writes)

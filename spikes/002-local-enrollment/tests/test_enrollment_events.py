"""Observed enrollment event shape, with synthetic bytes and bounded waits."""
import asyncio

import pytest

from transport import Transport, segments
from wire import encode


def event_peer(replies, *, delay=0, timeout=0.2, exchange_timeout=0.2):
    writes = []
    tasks = []

    async def deliver():
        await asyncio.sleep(delay)
        sequence = 0
        for opcode, action, payload in replies:
            for part in segments(encode(opcode, action, payload), sequence):
                channel.notify(part)
                sequence = (sequence + 1) % 64

    async def write(packet):
        writes.append(packet)
        if packet[0] & 128 and not packet[0] & 64:
            tasks.append(asyncio.create_task(deliver()))

    channel = Transport(write, timeout=timeout, exchange_timeout=exchange_timeout)
    return channel, writes, tasks


async def test_one_empty_ready_event_does_not_complete_key_exchange():
    channel, writes, tasks = event_peer([(111, 3, b""), (111, 1, b"\x0a\x01\x08")])
    events = []
    assert await channel.exchange_public_key(b"\x04", on_ready=lambda: events.append("ready")) == {1: b"\x08"}
    assert events == ["ready"]
    assert len([p for p in writes if not p[0] & 64]) == 1
    await asyncio.gather(*tasks)


@pytest.mark.parametrize("replies", [
    [(111, 3, b"unexpected")],
    [(110, 3, b"")],
    [(111, 2, b"")],
    [(111, 3, b""), (111, 3, b"")],
])
async def test_wrong_event_nak_and_duplicate_are_terminal(replies):
    channel, _, tasks = event_peer(replies)
    with pytest.raises(ValueError):
        await channel.exchange_public_key(b"\x04", on_ready=lambda: None)
    assert channel.closed
    await asyncio.gather(*tasks)


async def test_ready_event_without_final_ack_times_out_without_replay():
    channel, writes, tasks = event_peer([(111, 3, b"")], exchange_timeout=0.01)
    with pytest.raises(TimeoutError):
        await channel.exchange_public_key(b"\x04", on_ready=lambda: None)
    assert channel.closed
    assert len([p for p in writes if not p[0] & 64]) == 1
    await asyncio.gather(*tasks)


async def test_enrollment_has_its_own_deadline_without_extending_ordinary_requests():
    replies = [(111, 3, b""), (111, 1, b"\x0a\x01\x08")]
    channel, _, tasks = event_peer(replies, delay=0.02, timeout=0.005, exchange_timeout=0.2)
    assert await channel.exchange_public_key(b"\x04", on_ready=lambda: None) == {1: b"\x08"}
    await asyncio.gather(*tasks)


async def test_ordinary_request_still_rejects_enrollment_event():
    channel, _, tasks = event_peer([(111, 3, b"")])
    with pytest.raises(ValueError):
        await channel.request(111, b"\x04")
    assert channel.closed
    await asyncio.gather(*tasks)


async def test_ready_callback_failure_stops_before_accepting_public_key():
    channel, _, tasks = event_peer([(111, 3, b""), (111, 1, b"\x0a\x01\x08")])
    def failed():
        raise RuntimeError("synthetic observer failure")
    with pytest.raises(RuntimeError):
        await channel.exchange_public_key(b"\x04", on_ready=failed)
    assert channel.closed
    await asyncio.gather(*tasks)


async def test_stale_ready_event_is_rejected_before_write():
    channel, writes, _ = event_peer([])
    channel.notify(segments(encode(111, 3), 0)[0])
    with pytest.raises(ValueError):
        await channel.exchange_public_key(b"\x04", on_ready=lambda: None)
    assert not writes

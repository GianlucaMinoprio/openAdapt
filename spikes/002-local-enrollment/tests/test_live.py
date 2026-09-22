import asyncio

import pytest

from live import AutoMaxLiveLink
import live_wire
from test_ble_link import Harness, KEY, TARGET
from test_control import ControlPeer


class LivePeer(ControlPeer):
    async def write(self, packet):
        is_command = not (packet[0] & 64 or self.buffer or packet[1] in (112, 113))
        if is_command and packet[1] in (20, 222, 237):
            seq = packet[0] & 63
            assert packet[0] & 128 and seq == self.rx_sequence
            self.rx_sequence = (seq+1) % 64
            if seq % 2:
                self.channel.notify(bytes([192 | seq, 0]))
            opcode = packet[1]
            assert int.from_bytes(packet[2:4], "little") >> 14 == (3 if opcode == 20 else 0)
            self.commands.append(opcode)
            self.control_reply(opcode, 1)
            return
        if is_command and packet[1] == 3:
            self.moved.clear()
        await super().write(packet)


def live_harness(*, fault=None, hang=None, trace=None):
    h = Harness(auto_max=True, hang=hang)
    h.peer = LivePeer(fault=fault)
    changes = []
    link = AutoMaxLiveLink(TARGET, scanner_factory=h.scanner, client_factory=h.client_factory,
                          scan_seconds=0.001, timeout=0.2, cleanup_timeout=0.03,
                          on_change=lambda *args:changes.append(args), trace=trace)
    return h, link, changes


async def test_connect_reads_only_and_stays_connected_past_handshake_deadline():
    h, link, _ = live_harness()
    try:
        result = await link.start(KEY)
        assert result["battery_percent"] == 87
        await asyncio.sleep(0.24)
        assert link.connected and h.client.is_connected
        assert h.peer.commands == [112,113,81,4]
    finally:
        await link.stop()
    assert not h.client.is_connected and link.cleanup_errors == []


async def test_repeated_reads_reuse_one_connection_across_sequence_wrap():
    h, link, _ = live_harness()
    try:
        await link.start(KEY)
        for _ in range(40):
            assert (await link.execute("battery"))["before"]["battery_percent"] == 87
        assert h.events.count("scan-start") == h.events.count("connect") == 1
        assert h.peer.commands.count(112) == h.peer.commands.count(113) == 1
        assert link.connected
    finally:
        await link.stop()


async def test_two_explicit_moves_and_lights_reuse_authenticated_channel():
    h, link, _ = live_harness()
    try:
        await link.start(KEY)
        assert (await link.execute("lace",percent=0,maximum=60))["after_raw_position"] == 0
        assert (await link.execute("lace",percent=75,maximum=60))["after_raw_position"] == 45
        await link.execute("color",color=(0,255,255))
        await link.execute("lights-off")
        assert h.peer.commands.count(3) == 2
        assert h.peer.commands[-5:] == [237,222,20,237,222]
        assert h.peer.commands.count(112) == h.events.count("connect") == 1
        assert link.connected
    finally:
        await link.stop()


async def test_idle_physical_movement_is_observed_without_a_motor_request():
    h, link, changes = live_harness()
    try:
        await link.start(KEY)
        h.peer.control_reply(5,3,b"\x10\x2a")
        await asyncio.sleep(0.15)
        assert changes[0][0] == "position" and changes[0][1]["raw_position"] == 42
        assert h.peer.commands == [112,113,81,4]
    finally:
        await link.stop()


async def test_remote_disconnect_updates_state_and_never_reconnects():
    h, link, changes = live_harness()
    await link.start(KEY)
    h.client.is_connected = False
    link._disconnected(h.client)
    await asyncio.wait_for(link.task, 0.5)
    assert not link.connected and changes[-1][0] == "disconnected"
    assert h.events.count("connect") == 1


@pytest.mark.parametrize("fault", ["nak", "timeout", "readback", "position"])
async def test_uncertain_live_move_disconnects_and_is_never_replayed(fault):
    h, link, _ = live_harness(fault=fault)
    await link.start(KEY)
    with pytest.raises((ValueError, TimeoutError)):
        await link.execute("lace",percent=80,maximum=60)
    await asyncio.wait_for(link.task, 0.5)
    assert not link.connected and h.peer.commands.count(3) == 1
    with pytest.raises(ConnectionError):
        await link.execute("lace",percent=80,maximum=60)
    assert h.peer.commands.count(3) == 1


async def test_cancel_connect_cleans_up_partial_link():
    h, link, _ = live_harness(hang="connect")
    task = asyncio.create_task(link.start(KEY))
    await h.entered.wait()
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
    assert not h.client.is_connected and not link.connected


async def test_trace_failure_cannot_change_ble_write_outcome():
    def broken_trace(*_):
        raise OSError("synthetic disk failure")
    h, link, _ = live_harness(trace=broken_trace)
    await link.start(KEY)
    assert link.connected and h.peer.commands == [112,113,81,4]
    await link.stop()


@pytest.mark.parametrize("opcode", [2,14,50,110,111,236])
def test_persistent_codec_rejects_enrollment_reset_and_uploads(opcode):
    with pytest.raises(ValueError):
        live_wire.request(opcode)


async def test_moving_event_occurs_after_preflight_before_motor_write():
    h, link, changes = live_harness()
    seen = []
    original = link.on_change
    def changed(event, value):
        if event == "moving":
            seen.append((value["raw_position"], h.peer.commands.count(3)))
        original(event, value)
    link.on_change = changed
    try:
        await link.start(KEY)
        await link.execute("lace", percent=75, maximum=60)
        assert len(seen) == 1 and seen[0][1] == 0
        assert h.peer.commands.count(3) == 1 and changes[0][0] == "moving"
    finally:
        await link.stop()


async def test_parallel_live_channels_keep_frames_and_completion_independent():
    peers = [live_harness(), live_harness()]
    entered = [asyncio.Event(), asyncio.Event()]
    release = [asyncio.Event(), asyncio.Event()]
    tasks = []
    try:
        await asyncio.gather(*(link.start(KEY) for _,link,_ in peers))
        for index, (h, link, _) in enumerate(peers):
            original = h.peer.write
            async def delayed(packet, i=index, write=original):
                if not packet[0] & 64 and packet[0] & 128 and packet[1] == 3:
                    entered[i].set()
                    await release[i].wait()
                await write(packet)
            h.peer.write = delayed
            tasks.append(asyncio.create_task(link.execute("lace", percent=75 if index == 0 else 50, maximum=60)))
        await asyncio.wait_for(asyncio.gather(*(e.wait() for e in entered)), 1)
        release[1].set()
        assert (await tasks[1])["after_raw_position"] == 30
        assert not tasks[0].done()
        release[0].set()
        assert (await tasks[0])["after_raw_position"] == 45
        assert all(h.peer.commands.count(3) == 1 for h,_,_ in peers)
        assert all(link.connected for _,link,_ in peers)
    finally:
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        await asyncio.gather(*(link.stop() for _,link,_ in peers))

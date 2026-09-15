"""Synthetic control failures and independent small wire known answers."""
import asyncio
import struct

import pytest

from control import AutoMaxControlLink, ControlTransport
import control_wire
from simulation import SyntheticPeer
from test_ble_link import Harness, KEY, TARGET
from transport import Transport


class ControlPeer(SyntheticPeer):
    def __init__(self, *, battery=87, charger=1, position=30, fault=None):
        super().__init__(key=KEY, auto_max=True)
        self.battery, self.charger, self.position = battery, charger, position
        self.fault = fault
        self.moved = asyncio.Event()

    def control_reply(self, opcode, action, payload=b""):
        # Independent frame construction: no production control codec used.
        raw = bytes([opcode]) + (len(payload) | action << 14).to_bytes(2, "little") + payload
        for offset in range(0, len(raw), 19):
            final = offset + 19 >= len(raw)
            self.channel.notify(bytes([self.tx_sequence | (128 if final else 0)]) + raw[offset:offset+19])
            self.tx_sequence = (self.tx_sequence + 1) % 64

    async def write(self, packet):
        if packet[0] & 64 or self.buffer or packet[1] in (112, 113):
            return await super().write(packet)
        seq = packet[0] & 63
        assert packet[0] & 128 and seq == self.rx_sequence
        self.rx_sequence = (seq + 1) % 64
        if seq % 2:
            self.channel.notify(bytes([192 | seq, 0]))
        opcode = packet[1]
        payload = packet[4:]
        assert int.from_bytes(packet[2:4], "little") == len(payload)
        self.commands.append(opcode)
        if opcode == 81:
            assert not payload
            self.control_reply(81, 1, bytes([8, self.charger, 32, self.battery, 40, 4]))
        elif opcode == 4:
            assert not payload
            position = self.position + (5 if self.moved.is_set() and self.fault == "readback" else 0)
            self.control_reply(4, 1, bytes([8, position]) if position else b"")
        elif opcode == 0:
            assert payload == b"\x08\x08"
            self.control_reply(0, 1)
        elif opcode == 3:
            assert not self.moved.is_set()  # Never replay an uncertain command.
            self.moved.set()
            target = payload[1] if payload else 0
            if self.fault == "nak":
                self.control_reply(3, 2)
                return
            if self.fault != "before-ack":
                self.control_reply(3, 1)
            if self.fault == "timeout":
                return
            self.position = target + (4 if self.fault == "position" else 0)
            fields = (b"\x08\x04" if self.fault == "status" else b"")
            fields += bytes([16, self.position]) if self.position else b""
            self.control_reply(5, 3, fields)
        else:
            raise AssertionError("unexpected synthetic command")


def control_harness(**peer_options):
    h = Harness(auto_max=True)
    h.peer = ControlPeer(**peer_options)
    link = AutoMaxControlLink(TARGET, scanner_factory=h.scanner,
                             client_factory=h.client_factory, scan_seconds=0.001,
                             timeout=0.2, cleanup_timeout=0.03)
    return h, link


@pytest.mark.parametrize("opcode,value,expected", [
    (0, b"", "0002000808"), (3, 0, "030000"), (3, 42, "030200082a"),
    (4, b"", "040000"), (81, b"", "510000"),
])
def test_control_request_known_answers(opcode, value, expected):
    assert control_wire.request(opcode, value) == bytes.fromhex(expected)


def test_proto_defaults_and_position_are_separate_from_percent():
    assert control_wire.response(4, b"") == {1: 0}
    assert control_wire.response(5, b"\x10\x2b") == {1: 0, 2: 43}
    assert control_wire.response(5, b"\x08\x04\x10\x3c") == {1: 4, 2: 60}
    assert control_wire.relative_target(80, 65) == 52
    assert control_wire.relative_target(80, 61) == 49
    assert control_wire.relative_target(59, 61) == 36


@pytest.mark.parametrize("percent,maximum", [(True, 60), (-1, 60), (101, 60),
                                          (50.0, 60), (80, 0), (80, 101), (80, True)])
def test_invalid_calibration_or_percent_is_rejected(percent, maximum):
    with pytest.raises(ValueError):
        control_wire.relative_target(percent, maximum)


@pytest.mark.parametrize("opcode,payload", [
    (3, b"\x08\x01"), (4, b"\x08\x65"), (4, b"\x08\x01\x08\x02"),
    (4, b"\x08\x80\x00"), (4, b"\x10\x01"), (4, b"\x08\x80"),
    (81, b"\x19\x00"), (81, b"\x08\x04"), (81, b"\x20\x65"),
    (81, b"\x19" + struct.pack("<d", float("nan"))),
])
def test_malformed_status_stops_decoding(opcode, payload):
    with pytest.raises(ValueError):
        control_wire.response(opcode, payload)


@pytest.mark.parametrize("opcode", [1, 2, 6, 7, 8, 14, 50, 110, 111, 222, 237])
def test_control_codec_cannot_send_unrelated_or_enrollment_commands(opcode):
    with pytest.raises(ValueError):
        control_wire.request(opcode)


async def test_default_transport_still_rejects_control_before_write():
    writes = []
    async def write(packet):
        writes.append(packet)
    with pytest.raises(ValueError):
        await Transport(write).request(4)
    channel = ControlTransport(write)
    with pytest.raises(ValueError, match="authentication required"):
        await channel.read_status()
    with pytest.raises(ValueError, match="explicit authenticated"):
        await channel.request(3, 40)
    assert not writes


async def test_status_has_no_motor_enrollment_or_other_writes():
    h, link = control_harness()
    result = await link.read_status(KEY)
    assert result["before"] == {"raw_position": 30, "battery_percent": 87,
                                "charger_status": 1, "battery_state": 4}
    assert h.peer.commands == [112, 113, 81, 4]
    assert link.events[-2:] == ["notifications-stopped", "disconnected"]
    assert not h.client.is_connected


async def test_inherited_authentication_does_not_query_or_move():
    h, link = control_harness()
    assert await link.authenticate(KEY)
    assert h.peer.commands == [112, 113]


async def test_move_requires_ack_completion_and_fresh_readback_then_disconnects():
    h, link = control_harness()
    result = await link.set_position(KEY, percent=80, fit_maximum=60, empty_shoe_confirmed=True)
    assert result["before"]["raw_position"] == 30
    assert result["raw_target"] == result["completion"]["raw_position"] == result["after_raw_position"] == 48
    assert result["completion"]["status"] == 0
    assert h.peer.commands == [112, 113, 81, 4, 0, 3, 4]
    assert link.events[-4:] == ["movement-completed", "position-verified", "notifications-stopped", "disconnected"]
    assert not h.client.is_connected and link.channel.closed


async def test_no_empty_confirmation_means_no_scan_or_connection():
    h, link = control_harness()
    with pytest.raises(ValueError, match="empty-shoe"):
        await link.set_position(KEY, percent=80, fit_maximum=60)
    assert not h.events


async def test_wrong_key_never_reaches_control():
    h, link = control_harness()
    with pytest.raises(ValueError, match="proof mismatch"):
        await link.set_position(bytes(range(32, 48)), percent=80, fit_maximum=60,
                                empty_shoe_confirmed=True)
    assert h.peer.commands == [112]
    assert h.events[-2:] == ["unsubscribe", "disconnect"]


@pytest.mark.parametrize("options", [{"battery": 19}, {"charger": 0}, {"position": 80}])
async def test_motor_preflight_failure_sends_no_actuator_command(options):
    h, link = control_harness(**options)
    with pytest.raises(ValueError):
        await link.set_position(KEY, percent=80, fit_maximum=60, empty_shoe_confirmed=True)
    assert h.peer.commands == [112, 113, 81, 4]
    assert not h.client.is_connected


@pytest.mark.parametrize("fault", ["nak", "before-ack", "timeout", "status", "position"])
async def test_uncertain_move_is_stopped_best_effort_never_replayed(fault):
    h, link = control_harness(fault=fault)
    with pytest.raises((ValueError, TimeoutError)):
        await link.set_position(KEY, percent=80, fit_maximum=60, empty_shoe_confirmed=True)
    assert h.peer.commands == [112, 113, 81, 4, 0, 3, 0]
    assert link.channel.failure_stop == "written-without-confirmed-ack"
    assert not h.client.is_connected and link.channel.closed
    with pytest.raises(ValueError, match="already used"):
        await link.set_position(KEY, percent=80, fit_maximum=60, empty_shoe_confirmed=True)


async def test_completion_without_matching_readback_does_not_report_success():
    h, link = control_harness(fault="readback")
    with pytest.raises(ValueError, match="does not corroborate"):
        await link.set_position(KEY, percent=80, fit_maximum=60, empty_shoe_confirmed=True)
    assert "position-verified" not in link.events
    assert h.peer.commands.count(3) == 1 and not h.client.is_connected


async def test_cancelled_motor_wait_stops_and_disconnects():
    h, link = control_harness(fault="timeout")
    task = asyncio.create_task(link.set_position(KEY, percent=80, fit_maximum=60,
                                               empty_shoe_confirmed=True))
    await h.peer.moved.wait()
    await asyncio.sleep(0)
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
    assert h.peer.commands == [112, 113, 81, 4, 0, 3, 0]
    assert not h.client.is_connected


async def test_concurrent_call_cannot_change_active_operation():
    h, link = control_harness()
    h.hang = "scan-start"
    task = asyncio.create_task(link.read_status(KEY))
    await h.entered.wait()
    with pytest.raises(ValueError, match="already used"):
        await link.set_position(KEY, percent=80, fit_maximum=60, empty_shoe_confirmed=True)
    assert link.operation == ("status",)
    h.release.set()
    await task
    assert h.peer.commands == [112, 113, 81, 4]

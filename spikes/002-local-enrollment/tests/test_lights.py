import pytest

from lights import AutoMaxLightLink
import light_wire
from simulation import SyntheticPeer
from test_ble_link import Harness, KEY, TARGET


class LightPeer(SyntheticPeer):
    def __init__(self, fail=None):
        super().__init__(key=KEY, auto_max=True)
        self.fail = fail
        self.payloads = []

    async def write(self, packet):
        if packet[0] & 64 or self.buffer or packet[1] in (112, 113):
            return await super().write(packet)
        seq = packet[0] & 63
        assert packet[0] & 128 and seq == self.rx_sequence
        self.rx_sequence = (seq + 1) % 64
        if seq % 2:
            self.channel.notify(bytes([192 | seq, 0]))
        opcode = packet[1]
        word = int.from_bytes(packet[2:4], "little")
        assert word & 0x3fff == len(packet) - 4
        assert word >> 14 == (3 if opcode == 20 else 0)
        self.commands.append(opcode)
        self.payloads.append(packet[4:])
        action = 2 if self.fail == opcode else 1
        self.channel.notify(bytes([128 | self.tx_sequence, opcode, 0, action << 6]))
        self.tx_sequence = (self.tx_sequence + 1) % 64


def light_harness(fail=None):
    h=Harness(auto_max=True)
    h.peer=LightPeer(fail)
    link=AutoMaxLightLink(TARGET, scanner_factory=h.scanner, client_factory=h.client_factory,
                         scan_seconds=0.001, timeout=0.2, cleanup_timeout=0.03)
    return h,link


def test_independent_light_wire_known_answers():
    assert light_wire.request(222,(0,255,255)).hex() == "de0a0008041880fe032080fe03"
    assert light_wire.request(222,(0,0,0)).hex() == "de02000804"
    assert light_wire.request(237).hex() == "ed0000"
    assert light_wire.request(20).hex() == "1400c0"


@pytest.mark.parametrize("color", [(),[1,2],[-1,0,0],[256,0,0],[True,0,0],[0.5,0,0],"red"])
async def test_invalid_color_never_scans(color):
    h,link=light_harness()
    with pytest.raises(ValueError):
        await link.set_color(KEY,color)
    assert h.events == []


async def test_color_stops_effect_sets_base_and_previews_then_disconnects():
    h,link=light_harness()
    result=await link.set_color(KEY,(0,255,255))
    assert h.peer.commands == [112,113,237,222,20]
    assert result == {"action":"color","rgb":[0,255,255],"acknowledged":True}
    assert not h.client.is_connected and link.cleanup_errors == []


async def test_lights_off_stops_effect_and_sets_zero_without_preview():
    h,link=light_harness()
    await link.lights_off(KEY)
    assert h.peer.commands == [112,113,237,222]
    assert h.peer.payloads[-1] == b"\x08\x04"
    assert not h.client.is_connected


@pytest.mark.parametrize("opcode,expected", [(237,[112,113,237]),(222,[112,113,237,222]),(20,[112,113,237,222,20])])
async def test_rejected_light_command_is_not_retried(opcode,expected):
    h,link=light_harness(fail=opcode)
    with pytest.raises(ValueError):
        await link.set_color(KEY,(255,0,0))
    assert h.peer.commands == expected
    assert not h.client.is_connected


async def test_authentication_only_still_does_not_change_lights():
    h,link=light_harness()
    await link.authenticate(KEY)
    assert h.peer.commands == [112,113]


@pytest.mark.parametrize("opcode", [0,3,14,50,110,111,236])
def test_light_codec_rejects_motors_enrollment_reset_and_upload(opcode):
    with pytest.raises(ValueError):
        light_wire.request(opcode)

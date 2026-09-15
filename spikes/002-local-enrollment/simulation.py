"""In-memory synthetic peer. Never imports Bleak or opens a radio/socket."""
import hmac
import tempfile
from pathlib import Path

from crypto import Exchange, ProofFormat, encrypt
from keyfile import Store, load
from session import Session
from transport import Transport, TransportProfile, segments
from wire import decode, encode


def _bytes_field(number, value):
    size = len(value)
    length = bytes([size]) if size < 128 else bytes([128 | (size & 127), size >> 7])
    return bytes([number << 3 | 2]) + length + value


def _request_value(payload):
    if not payload:
        return b""
    if len(payload) < 2 or payload[0] != 10:
        raise ValueError("synthetic peer: unexpected field")
    length = payload[1] & 127
    start = 2
    if payload[1] & 128:
        length |= payload[2] << 7
        start = 3
    if len(payload[start:]) != length:
        raise ValueError("synthetic peer: incorrect field size")
    return payload[start:]


class SyntheticPeer:
    """A test model, never evidence of firmware behavior or enrollment support."""

    def __init__(self, group=0, key=None, *, auto_max=False):
        self.group = group
        self.auto_max = auto_max
        self.needs_enrollment = key is None
        self.setup_authenticated = False
        self.key = b"\x01" * 16 if auto_max and key is None else key
        self.exchange = None
        self.nonce = b"D" * 16
        self.buffer = bytearray()
        self.rx_sequence = 0
        self.tx_sequence = 0
        self.commands = []
        self.packets = 0
        self.flow_acks = 0
        profile = TransportProfile.AUTO_MAX_CAPTURE if auto_max else TransportProfile.APK_MODEL
        self.channel = Transport(self.write, timeout=1, profile=profile)

    def reply(self, opcode, action, payload):
        for part in segments(encode(opcode, action, payload), self.tx_sequence):
            self.channel.notify(part)
            self.tx_sequence = (self.tx_sequence + 1) % 64

    async def write(self, packet):
        self.packets += 1
        if packet[0] & 64:
            if len(packet) != 2 or packet[1] != 0:
                raise ValueError("synthetic peer: invalid flow ACK")
            self.flow_acks += 1
            return
        seq = packet[0] & 63
        if seq != self.rx_sequence:
            raise ValueError("synthetic peer: sequence mismatch")
        self.rx_sequence = (seq + 1) % 64
        self.buffer.extend(packet[1:])
        if seq % 2:
            self.channel.notify(bytes([192 | seq, 0]))
        if not packet[0] & 128:
            return
        opcode, action, payload = decode(bytes(self.buffer))
        self.buffer.clear()
        if action != 0:
            raise ValueError("synthetic peer: expected request")
        self.commands.append(opcode)
        value = _request_value(payload)
        if opcode == 110:
            ready = self.needs_enrollment and (not self.auto_max or self.setup_authenticated)
            if not ready or value:
                raise ValueError("synthetic peer: already has a key")
            self.exchange = Exchange(self.group)
            reply = b"\x08" + bytes([self.group])
        elif opcode == 111:
            if self.exchange is None:
                raise ValueError("synthetic peer: exchange not started")
            self.key = self.exchange.derive(value)
            self.needs_enrollment = False
            reply = _bytes_field(1, self.exchange.public)
            if self.auto_max:
                self.reply(111, 3, b"")
        elif opcode == 112:
            challenge = b"TEST" + value[4:] if self.auto_max else value
            reply = _bytes_field(1, encrypt(self.key, challenge)) + _bytes_field(2, self.nonce)
        elif opcode == 113:
            if not hmac.compare_digest(value, encrypt(self.key, self.nonce)):
                raise ValueError("synthetic peer: challenge mismatch")
            if self.needs_enrollment and self.auto_max:
                self.setup_authenticated = True
            reply = b""
        else:
            raise ValueError("synthetic peer: unsupported command")
        self.reply(opcode, 1, reply)


async def self_test():
    groups = []
    auto_max_groups = []
    with tempfile.TemporaryDirectory(prefix="openadapt-synthetic-") as temporary:
        for group in range(4):
            path = Path(temporary) / "vault" / f"synthetic-{group}.json"
            peer = SyntheticPeer(group)
            try:
                session = Session(peer.channel)
                with Store(path) as store:
                    await session.enroll(store, "synthetic", synthetic=True)
                key = load(path, "synthetic", allow_synthetic=True)
                if session.state != "authenticated" or not hmac.compare_digest(key, peer.key):
                    raise ValueError("synthetic enrollment did not agree")
                existing = SyntheticPeer(key=key)
                try:
                    await Session(existing.channel).authenticate_existing(key)
                    if existing.commands != [112, 113]:
                        raise ValueError("unexpected existing-key command")
                finally:
                    existing.channel.close()
                groups.append({"group": group, "enrollment_commands": peer.commands,
                               "existing_key_commands": existing.commands,
                               "candidate_storage": "synthetic / UNVERIFIED"})
            finally:
                peer.channel.close()
        for group in (1, 2):
            path = Path(temporary) / "vault" / f"auto-max-synthetic-{group}.json"
            peer = SyntheticPeer(group, auto_max=True)
            try:
                session = Session(peer.channel, proof_format=ProofFormat.AUTO_MAX_2_4_3M)
                with Store(path) as store:
                    await session.enroll_auto_max(store, "synthetic", synthetic=True)
                key = load(path, "synthetic", allow_synthetic=True)
                existing = SyntheticPeer(key=key, auto_max=True)
                try:
                    await Session(existing.channel, proof_format=ProofFormat.AUTO_MAX_2_4_3M).authenticate_existing(key)
                finally:
                    existing.channel.close()
                auto_max_groups.append({"group": group, "enrollment_commands": peer.commands,
                                        "events": session.events, "existing_key_commands": existing.commands,
                                        "candidate_storage": "synthetic / UNVERIFIED"})
            finally:
                peer.channel.close()
    return {"mode": "OFFLINE SYNTHETIC SELF-TEST", "passed": True,
            "hardware_accessed": False, "shoe_authentication_proven": False, "groups": groups,
            "auto_max_groups": auto_max_groups}

"""Original bounded CoreRF transport; strict receiver, no command replay."""
import asyncio
import inspect
import math
from enum import Enum
import wire


class TransportProfile(Enum):
    APK_MODEL = "apk-model"
    AUTO_MAX_CAPTURE = "auto-max-capture"


def segments(raw, sequence, *, codec=wire):
    codec.decode(raw)
    if sequence not in range(64):
        raise ValueError("invalid sequence")
    packets = [bytes([(sequence+i//19)%64])+raw[i:i+19] for i in range(0,len(raw),19)]
    packets[-1] = bytes([packets[-1][0] | 128]) + packets[-1][1:]
    return packets

class Receiver:
    def __init__(self, *, profile=TransportProfile.APK_MODEL, codec=wire):
        if not isinstance(profile, TransportProfile):
            raise ValueError("unsupported transport profile")
        self.profile = profile
        self.codec = codec
        self.sequence = 0
        self.buffer = bytearray()
        self.count = 0
        self.ack_base = 0

    def feed(self, packet):
        if not 2 <= len(packet) <= 20 or packet[0] & 64:
            raise ValueError("invalid data segment")
        sequence = packet[0] & 63
        if sequence != self.sequence:
            raise ValueError("duplicate or out-of-order segment")
        if len(self.buffer) + len(packet)-1 > 516:
            raise ValueError("reassembly overflow")
        final = bool(packet[0] & 128)
        self.count += 1
        self.buffer.extend(packet[1:])
        ack = None
        acknowledge = (sequence % 2 == 1 if self.profile is TransportProfile.AUTO_MAX_CAPTURE
                       else self.count > 1 and (not final or (sequence-self.ack_base)%64 == 1))
        if acknowledge:
            ack = bytes([sequence | 192, 0])
            self.ack_base = (sequence+1)%64
        self.sequence = (sequence+1)%64
        if final:
            raw = bytes(self.buffer)
            self.buffer.clear()
            self.codec.decode(raw)
            return raw, ack
        return None, ack

class Transport:
    codec = wire

    def __init__(self, write, *, timeout=8, exchange_timeout=33,
                 profile=TransportProfile.APK_MODEL):
        if not isinstance(profile, TransportProfile):
            raise ValueError("unsupported transport profile")
        for value in (timeout, exchange_timeout):
            if not math.isfinite(value) or not 0 < value <= 120:
                raise ValueError("timeout must be finite, > 0 and <= 120")
        self.write = write
        self.timeout = timeout
        self.exchange_timeout = exchange_timeout
        self.profile = profile
        self.queue = asyncio.Queue(maxsize=128)
        self.receiver = Receiver(profile=profile, codec=self.codec)
        self.tx_sequence = 0
        self.sent = 0
        self.acknowledged = 0
        self.has_acknowledgement = False
        self.expected_ack = 1
        self.active = False
        self.closed = False
        self.failure = None

    def notify(self, packet):
        """Call on the owning event loop; never throw from a BLE callback."""
        if self.closed or self.failure:
            return
        if not isinstance(packet, (bytes, bytearray)) or not 2 <= len(packet) <= 20:
            self._fail("invalid notification")
        elif self.queue.full():
            self._fail("notification queue overflow")
        else:
            self.queue.put_nowait(bytes(packet))

    def _fail(self, message):
        self.failure = message
        while not self.queue.empty():
            self.queue.get_nowait()
        self.queue.put_nowait(None)  # Wake a pending request without another task.

    def close(self):
        self.closed = True
        self._fail("transport closed")

    def _check(self):
        if self.failure:
            raise ValueError(self.failure)

    def _flow(self, packet):
        if len(packet) != 2 or packet[0] & 192 != 192 or packet[1] != 0:
            raise ValueError("unsupported flow control; no replay")
        seq = packet[0] & 63
        advance = (seq - self.acknowledged) % 64
        if seq != self.expected_ack or not 0 < advance or self.acknowledged + advance >= self.sent:
            raise ValueError("unexpected flow acknowledgement")
        self.acknowledged += advance
        self.has_acknowledgement = True
        self.expected_ack = (seq + 2) % 64
        self.receiver.count += 1  # APK receive count includes flow packets.

    def _window_full(self):
        # A received ACK names the last accepted fragment, not the number of
        # accepted fragments. The iPhone permits four still-unacknowledged data
        # fragments; retain the prior conservative model unless selected.
        base = self.acknowledged
        if self.profile is TransportProfile.AUTO_MAX_CAPTURE and self.has_acknowledgement:
            base += 1
        return self.sent - base >= 4

    async def _receive(self, packet, opcode, *, response_allowed, enrollment_event=None):
        self._check()
        if packet[0] & 64:
            self._flow(packet)
            return None
        if not response_allowed:
            raise ValueError("unsolicited or premature response")
        raw, ack = self.receiver.feed(packet)
        fields = None
        if raw is not None:
            op, action, payload = self.codec.decode(raw)
            if op == opcode == 111 and action == 3 and enrollment_event is not None:
                if payload:
                    raise ValueError("unexpected enrollment event payload")
                enrollment_event()
            elif op != opcode or action != 1:
                raise ValueError("NAK or unexpected response")
            else:
                fields = self.codec.response(op, payload)
        if ack:
            await self.write(ack)
            self._check()
        return fields

    async def request(self, opcode, value=b""):
        return await self._request(opcode, value, timeout=self.timeout)

    async def exchange_public_key(self, value, *, on_ready):
        """Accept one empty 111 event, then await its separate public-value ACK.

        on_ready must be an immediate synchronous observer, not a blocking prompt.
        Neither the event nor callback completion establishes key commitment.
        """
        if not callable(on_ready) or inspect.iscoroutinefunction(on_ready):
            raise ValueError("synchronous key-exchange observer required")
        seen = False

        def observed():
            nonlocal seen
            if seen:
                raise ValueError("duplicate enrollment event")
            seen = True
            result = on_ready()
            if inspect.isawaitable(result):
                if inspect.iscoroutine(result):
                    result.close()
                raise ValueError("key-exchange observer must be synchronous")

        return await self._request(111, value, timeout=self.exchange_timeout,
                                   enrollment_event=observed)

    async def _request(self, opcode, value, *, timeout, enrollment_event=None):
        if self.closed:
            raise ValueError("transport closed; create a new session")
        if self.active:
            raise ValueError("request already in progress")
        packets = segments(self.codec.request(opcode, value), self.tx_sequence, codec=self.codec)
        self.active = True
        try:
            async with asyncio.timeout(timeout):
                self._check()
                # A late flow ACK is valid; a queued application reply is not
                # evidence for a command that has not yet been issued.
                while not self.queue.empty():
                    await self._receive(self.queue.get_nowait(), opcode, response_allowed=False)
                for packet in packets:
                    while not self.queue.empty() or self._window_full():
                        await self._receive(await self.queue.get(), opcode, response_allowed=False)
                    await self.write(packet)
                    self.sent += 1
                    self.tx_sequence = self.sent % 64
                    self._check()
                while True:
                    fields = await self._receive(await self.queue.get(), opcode, response_allowed=True,
                                                 enrollment_event=enrollment_event)
                    if fields is not None:
                        return fields
        except BaseException:
            self.close()
            raise
        finally:
            self.active = False

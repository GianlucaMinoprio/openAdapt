"""Persistent existing-key Auto Max connection with serialized explicit actions.

Connect reads battery and position only. Nothing is queued for a lost connection.
There is no new bonding, enrollment, reset, calibration or firmware operation.
"""
import asyncio
import contextlib

from ble_link import ExistingKeyLink, LinkProfile
from control import ControlTransport
import control_wire
import light_wire
import live_wire
from transport import Transport


class LiveTransport(ControlTransport):
    codec = live_wire

    async def idle_packet(self, packet):
        self._ready()
        if packet[0] & 64:
            self._flow(packet)
            return None
        raw, ack = self.receiver.feed(packet)
        result = None
        if raw is not None:
            opcode, action, payload = self.codec.decode(raw)
            # A physical shoe-button movement can finish while the app is idle.
            # Observe its position without commanding another movement.
            if opcode != 5 or action != 3:
                raise ValueError("unexpected idle shoe message")
            result = self.codec.response(opcode, payload)
        if ack:
            await self.write(ack)
            self._check()
        return result

    async def set_color(self, color, *, preview=True):
        self._ready()
        color = light_wire.rgb(color)
        await Transport.request(self, 237)
        await Transport.request(self, 222, color)
        if preview:
            await Transport.request(self, 20)

    async def position(self, percent, maximum):
        target = control_wire.relative_target(percent, maximum)
        before = await self.read_status()
        if before["charger_status"] != 1:
            raise ValueError("shoe must be off the charger")
        if before["battery_percent"] < 20:
            raise ValueError("shoe battery is too low for lacing")
        if before["raw_position"] > maximum + 1:
            raise ValueError("position exceeds saved fit calibration")
        completion = await self.move_raw(target)
        after = await self.read_position()
        if abs(after-target) > 1 or abs(after-completion["raw_position"]) > 1:
            raise ValueError("position readback did not corroborate completion")
        # A further explicit drag is permitted only after the previous command,
        # completion and readback succeeded. Sequence/flow state is preserved.
        self.move_sent = False
        self.move_acknowledged = False
        self.completion = None
        return {"before": before, "after_raw_position": after}


class AutoMaxLiveLink(ExistingKeyLink):
    def __init__(self, target, *, on_change=None, trace=None, **kwargs):
        kwargs["profile"] = LinkProfile.AUTO_MAX_2_4_3M
        super().__init__(target, **kwargs)
        self.on_change = on_change or (lambda *_: None)
        self.trace = trace or (lambda *_: None)
        self.operation_lock = asyncio.Lock()
        self.release = asyncio.Event()
        self.ready = None
        self.task = None
        self.status = None
        self.ending = False

    @property
    def connected(self):
        return bool(self.peer_proof_accepted and self.client and self.client.is_connected
                    and not self.lost and not self.closing and self.channel and not self.channel.closed)

    def _lost(self):
        super()._lost()
        self.release.set()

    def _notification(self, characteristic, data):
        if isinstance(data, (bytes, bytearray)):
            self._record("rx", bytes(data))
        super()._notification(characteristic, data)

    def _record(self, direction, packet):
        try:
            self.trace(direction, packet)
        except Exception:
            # Logging must never turn a completed BLE write into a failed write
            # or escape the notification callback.
            self.events.append("trace-write-failed")

    def _make_channel(self, write):
        async def traced(packet):
            await write(packet)
            self._record("tx", packet)
        return LiveTransport(traced, timeout=min(8, self.timeout))

    async def start(self, key):
        if self.task is not None:
            raise ValueError("connection already attempted; choose Connect to try again")
        self.ready = asyncio.get_running_loop().create_future()
        self.task = asyncio.create_task(self._run(key))
        try:
            return await asyncio.shield(self.ready)
        except BaseException:
            await self.stop()
            if self.ready.done() and not self.ready.cancelled():
                self.ready.exception()
            raise

    async def _run(self, key):
        error = None
        try:
            async with self.authenticated_session(key):
                self.channel.authenticated = True
                self.status = await self.channel.read_status()
                self.ready.set_result(self.status)
                while not self.release.is_set():
                    try:
                        await asyncio.wait_for(self.release.wait(), timeout=0.1)
                    except TimeoutError:
                        pass
                    if self.release.is_set():
                        break
                    async with self.operation_lock:
                        self._check_connected()
                        self.channel._check()
                        while not self.channel.queue.empty():
                            event = await self.channel.idle_packet(self.channel.queue.get_nowait())
                            if event is not None:
                                self.status["raw_position"] = event[2]
                                self.on_change("position", dict(self.status))
        except (Exception, asyncio.CancelledError) as exc:
            error = exc
        finally:
            if not self.ready.done():
                self.ready.set_exception(error or ConnectionError("connection ended before ready"))
            self.on_change("disconnected", error)

    async def stop(self):
        self.ending = True
        self.release.set()
        if self.task and not self.task.done():
            self.task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self.task

    async def execute(self, action, *, percent=None, maximum=None, color=None):
        async with self.operation_lock:
            if not self.connected:
                raise ConnectionError("shoe is disconnected")
            try:
                if action == "battery":
                    return {"before": await self.channel.read_status()}
                if action == "lace":
                    return await self.channel.position(percent, maximum)
                if action == "color":
                    await self.channel.set_color(color)
                    return {}
                if action == "lights-off":
                    await self.channel.set_color((0, 0, 0), preview=False)
                    return {}
                raise ValueError("unsupported live action")
            except BaseException:
                self.channel.close()
                self.release.set()
                raise

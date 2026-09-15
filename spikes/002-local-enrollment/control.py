"""Bounded existing-key Auto Max status and one-position control operation.

No CLI, new bonding, enrollment or calibration writes. A hardware motor attempt
requires a current fit maximum and an explicit current empty-shoe confirmation.
"""
import asyncio

from ble_link import ExistingKeyLink, LinkProfile
import control_wire
from transport import Transport, TransportProfile, segments


class ControlTransport(Transport):
    codec = control_wire

    def __init__(self, write, **kwargs):
        kwargs.setdefault("profile", TransportProfile.AUTO_MAX_CAPTURE)
        super().__init__(write, **kwargs)
        self.authenticated = False
        self.move_sent = False
        self.move_acknowledged = False
        self.completion = None
        self.failure_stop = "not-needed"

    async def request(self, opcode, value=b""):
        # Session may perform only the existing-key handshake. Motor operations
        # are available through the bounded methods below after authentication.
        if opcode not in (112, 113):
            raise ValueError("use the explicit authenticated control operation")
        return await super().request(opcode, value)

    def _ready(self):
        if not self.authenticated:
            raise ValueError("application authentication required before control")
        if self.closed or self.active:
            raise ValueError("control transport unavailable")
        self._check()

    async def read_position(self):
        self._ready()
        return (await super().request(4))[1]

    async def read_status(self):
        self._ready()
        battery = await super().request(81)
        position = await self.read_position()
        return {"raw_position": position, "battery_percent": battery[4],
                "charger_status": battery[1], "battery_state": battery[5]}

    async def _failure_stop(self):
        # Best effort only: an absent link or a damaged flow state can prevent
        # delivery. Never restart the channel or replay the position request.
        if not self.move_sent:
            return
        self.failure_stop = "unconfirmed"
        try:
            if self._window_full():
                self.failure_stop = "unavailable-flow-window"
                return
            packet, = segments(self.codec.request(0), self.tx_sequence, codec=self.codec)
            async with asyncio.timeout(min(2, self.timeout)):
                await self.write(packet)
            self.sent += 1
            self.tx_sequence = self.sent % 64
            self.failure_stop = "written-without-confirmed-ack"
        except (Exception, asyncio.CancelledError):
            self.failure_stop = "write-failed"

    async def move_raw(self, target):
        self._ready()
        control_wire.position(target)
        if self.move_sent:
            raise ValueError("one position request per control session")
        # The observed original-app sequence first gets an ACK for Stop.
        await super().request(0)
        packet, = segments(self.codec.request(3, target), self.tx_sequence, codec=self.codec)
        self.active = True
        try:
            async with asyncio.timeout(self.timeout):
                self._check()
                while not self.queue.empty() or self._window_full():
                    await self._receive(await self.queue.get(), 3, response_allowed=False)
                await self.write(packet)
                self.sent += 1
                self.tx_sequence = self.sent % 64
                self.move_sent = True
                self._check()
                while True:
                    packet = await self.queue.get()
                    self._check()
                    if packet[0] & 64:
                        self._flow(packet)
                        continue
                    raw, ack = self.receiver.feed(packet)
                    done = False
                    if raw is not None:
                        opcode, action, payload = self.codec.decode(raw)
                        if opcode == 3 and action == 1 and not self.move_acknowledged:
                            self.codec.response(3, payload)
                            self.move_acknowledged = True
                        elif opcode == 5 and action == 3 and self.move_acknowledged:
                            fields = self.codec.response(5, payload)
                            self.completion = {"status": fields[1], "raw_position": fields[2]}
                            if fields[1] != 0:
                                raise ValueError("shoe reported a nonzero movement status")
                            if abs(fields[2] - target) > 1:
                                raise ValueError("movement completion outside observed one-unit tolerance")
                            done = True
                        else:
                            raise ValueError("unexpected movement response or completion before ACK")
                    if ack:
                        await self.write(ack)
                        self._check()
                    if done:
                        return dict(self.completion)
        except BaseException:
            # Shield the short Stop attempt from cancellation, then preserve the
            # original failure and close. Delivery/physical stopping is unproven.
            task = asyncio.create_task(self._failure_stop())
            while not task.done():
                try:
                    await asyncio.shield(task)
                except asyncio.CancelledError:
                    pass
            task.result()
            self.close()
            raise
        finally:
            self.active = False


class AutoMaxControlLink(ExistingKeyLink):
    """Explicit control sibling of the unchanged authentication-only API."""

    def __init__(self, target, **kwargs):
        if kwargs.get("profile", LinkProfile.AUTO_MAX_2_4_3M) is not LinkProfile.AUTO_MAX_2_4_3M:
            raise ValueError("control requires the verified Auto Max firmware profile")
        kwargs["profile"] = LinkProfile.AUTO_MAX_2_4_3M
        super().__init__(target, **kwargs)
        self.operation = None
        self.result = None

    def _make_channel(self, write):
        return ControlTransport(write, timeout=min(8, self.timeout))

    async def read_status(self, key):
        if self.used:
            raise ValueError("link already used; no automatic retry")
        self.operation = ("status",)
        await super().authenticate(key)
        return self.result

    async def set_position(self, key, *, percent, fit_maximum, empty_shoe_confirmed=False):
        if self.used:
            raise ValueError("link already used; no automatic retry")
        target = control_wire.relative_target(percent, fit_maximum)
        if empty_shoe_confirmed is not True:
            raise ValueError("current empty-shoe confirmation required before motor testing")
        self.operation = ("position", target, percent, fit_maximum)
        await super().authenticate(key)
        return self.result

    async def _after_authentication(self):
        if self.operation is None:
            return  # Inherited authenticate remains authentication-only.
        self.channel.authenticated = True
        before = await self.channel.read_status()
        self.result = {"before": before}
        self.events.append("status-read")
        if self.operation[0] == "status":
            return
        _, target, percent, maximum = self.operation
        self.result.update({"requested_percent": percent, "fit_maximum": maximum,
                            "raw_target": target})
        if before["charger_status"] != 1:
            raise ValueError("motor test requires the shoe off its charger")
        if before["battery_percent"] < 20:
            raise ValueError("motor test battery preflight did not pass")
        if before["raw_position"] > maximum + 1:
            raise ValueError("current position exceeds saved fit calibration")
        self.result["completion"] = await self.channel.move_raw(target)
        self.events.append("movement-completed")
        after = await self.channel.read_position()
        self.result["after_raw_position"] = after
        if abs(after - target) > 1 or abs(after - self.result["completion"]["raw_position"]) > 1:
            raise ValueError("post-movement position does not corroborate completion")
        self.events.append("position-verified")

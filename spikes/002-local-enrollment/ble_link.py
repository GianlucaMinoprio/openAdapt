"""One existing-key attempt over BlueZ; no enrollment, pairing or control API.

The factory-injected lifecycle is tested offline. A valid owner application key
is required before any radio access. BLE bonding is never requested or retried;
pair=False does not itself establish the remote device's security behavior.
"""
import asyncio
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from enum import Enum
import math
import re
import sys
import threading

from bleak import BleakClient, BleakScanner

from keyfile import validate_key
from crypto import ProofFormat
from session import Session
from transport import Transport, TransportProfile


SERVICE = "1a2328af-3d0b-4b04-a2aa-973c239d3904"
WRITE = "226baea6-1543-40c2-8eae-a69b02171b08"
NOTIFY = "30c4142f-b083-42cf-865a-d5b91801bcd7"
DEVICE_INFORMATION = "0000180a-0000-1000-8000-00805f9b34fb"
FIRMWARE_REVISION = "00002a26-0000-1000-8000-00805f9b34fb"


class LinkProfile(Enum):
    STRICT = "strict"
    AUTO_MAX_2_4_3M = "auto-max-2.4.3M"


@dataclass(frozen=True)
class OwnedTarget:
    address: str = field(repr=False)
    advertised_name: str
    confirmed_owned: bool = False
    shoe_identity: bytes | None = field(default=None, repr=False)

    def __post_init__(self):
        if self.shoe_identity is not None:
            if (self.address != "" or not isinstance(self.shoe_identity, bytes)
                    or len(self.shoe_identity) != 6 or self.shoe_identity[-1] not in (0, 1)):
                raise ValueError("a complete saved shoe identity is required")
        elif not isinstance(self.address, str) or not re.fullmatch(
            r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", self.address
        ):
            raise ValueError("an exact Bluetooth address is required")
        if not isinstance(self.advertised_name, str) or not re.fullmatch(
            r"[0-9]{3}-[A-Z0-9]+-[0-9]{3}", self.advertised_name
        ):
            raise ValueError("an exact Nike advertised product name is required")
        if self.confirmed_owned is not True:
            raise ValueError("explicit owned-target confirmation is required")


class CleanupError(RuntimeError):
    """Authentication outcome must be inspected when cleanup did not complete."""


def matches_target(target, device, advertisement):
    payload = advertisement.manufacturer_data.get(0x78)
    if target.shoe_identity is not None:
        match = (isinstance(payload, (bytes, bytearray)) and len(payload) >= 8
                 and payload[:2] == b"\xaf\x28"
                 and bytes(payload[2:7]) + bytes([payload[7] & 1]) == target.shoe_identity)
    else:
        match = device.address.upper() == target.address.upper() and payload is not None
    return match and advertisement.local_name == target.advertised_name


class SharedShoeDiscovery:
    """One fresh scan for a single pair-connect attempt; never caches across attempts.

    Readers wait for scanner cleanup before opening their independent links.
    The controller owns close(), so cancelling one reader cannot orphan the scan.
    """
    def __init__(self, targets, *, scanner_factory=BleakScanner, scan_seconds=5, cleanup_timeout=5):
        self.targets = tuple(targets)
        if not 1 <= len(self.targets) <= 2 or any(not isinstance(t, OwnedTarget) for t in self.targets):
            raise ValueError("one or two owned targets required")
        if any(not isinstance(v, (int, float)) or not math.isfinite(v) or not 0 < v <= 15
               for v in (scan_seconds, cleanup_timeout)):
            raise ValueError("bounded discovery deadlines required")
        self.scanner_factory = scanner_factory
        self.scan_seconds, self.cleanup_timeout = scan_seconds, cleanup_timeout
        self.task = None
        self.closed = False

    async def matches_for(self, target):
        if self.closed or target not in self.targets:
            raise ValueError("discovery belongs to a different connection attempt")
        if self.task is None:
            self.task = asyncio.create_task(self._scan())
        return (await asyncio.shield(self.task))[target]

    async def _scan(self):
        matches = {target:{} for target in self.targets}
        def observed(device, advertisement):
            for target in self.targets:
                if matches_target(target, device, advertisement):
                    found = matches[target]
                    # Two different devices already establish ambiguity.
                    if len(found) < 2 or device.address.upper() in found:
                        found[device.address.upper()] = device
        scanner = self.scanner_factory(detection_callback=observed)
        try:
            async with asyncio.timeout(self.scan_seconds + self.cleanup_timeout):
                await scanner.start()
                await asyncio.sleep(self.scan_seconds)
        finally:
            async def stop():
                async with asyncio.timeout(self.cleanup_timeout):
                    await scanner.stop()
            cleanup = asyncio.create_task(stop())
            cancellation = None
            while not cleanup.done():
                try:
                    await asyncio.shield(cleanup)
                except asyncio.CancelledError as error:
                    cancellation = error
                except Exception:
                    break  # Report scanner cleanup failure below to both readers.
            try:
                cleanup.result()
            except Exception as error:
                raise CleanupError("shared scanner cleanup failed; no connection attempted") from error
            if cancellation is not None:
                raise cancellation
        return matches

    async def close(self):
        self.closed = True
        if self.task is not None:
            if not self.task.done():
                self.task.cancel()
            # Consume failures even when all readers were cancelled.
            await asyncio.gather(self.task, return_exceptions=True)


class ExistingKeyLink:
    """Single-use, Linux-shaped lifecycle with injectable scanner/client factories.

    Only application opcodes 112/113 and their transport ACKs can be sent by
    authenticate(). There is no fallback to enrollment or post-authentication
    query. Exceptions fail the attempt; no operation is replayed.
    """

    def __init__(self, target, *, scanner_factory=BleakScanner,
                 client_factory=BleakClient, scan_seconds=5, timeout=40,
                 cleanup_timeout=5, profile=LinkProfile.STRICT, discovery=None):
        if not isinstance(target, OwnedTarget):
            raise ValueError("OwnedTarget required")
        if not isinstance(profile, LinkProfile):
            raise ValueError("unsupported link profile")
        if profile is LinkProfile.AUTO_MAX_2_4_3M and not target.advertised_name.startswith("004-"):
            raise ValueError("Auto Max profile requires an owned family-004 target")
        if sys.platform != "linux" and (scanner_factory is BleakScanner or client_factory is BleakClient):
            raise ValueError("default live factories are restricted to Linux/BlueZ")
        for value, limit in ((scan_seconds, 15), (timeout, 120), (cleanup_timeout, 10)):
            if not isinstance(value, (int, float)) or not math.isfinite(value) or not 0 < value <= limit:
                raise ValueError("lifecycle deadlines must be positive, finite and bounded")
        self.target = target
        self.profile = profile
        self.scanner_factory = scanner_factory
        self.client_factory = client_factory
        self.scan_seconds = scan_seconds
        self.timeout = timeout
        self.cleanup_timeout = cleanup_timeout
        self.discovery = discovery
        self.used = False
        self.events = []
        self.cleanup_errors = []
        self.peer_proof_accepted = False
        self.client = None
        self.channel = None
        self.notify_char = None
        self.subscribe_attempted = False
        self.closing = False
        self.lost = False
        self.loop = None
        self.thread = None
        self.callback_fault_scheduled = False
        self.callback_lock = threading.Lock()

    def _callback_fault(self):
        # BlueZ callbacks run on the owning asyncio loop. An unexpected callback
        # thread fails closed with at most one scheduled callback, rather than
        # adding an unbounded cross-thread stream to the loop's ready queue.
        with self.callback_lock:
            if self.callback_fault_scheduled:
                return
            self.callback_fault_scheduled = True
        try:
            self.loop.call_soon_threadsafe(self._lost)
        except RuntimeError:
            pass  # Loop already ended; cleanup has closed the channel.

    def _lost(self):
        self.lost = True
        if self.channel is not None:
            self.channel.close()

    def _disconnected(self, _client):
        if threading.get_ident() != self.thread:
            self._callback_fault()
        else:
            self._lost()

    def _notification(self, _characteristic, data):
        if self.closing:
            return
        if threading.get_ident() != self.thread:
            self._callback_fault()
        elif self.channel is not None:
            self.channel.notify(data)

    def _check_connected(self):
        if self.lost or self.closing or not self.client.is_connected:
            raise ConnectionError("shoe disconnected during the attempt")

    async def _finish(self, actions):
        async def finish_all():
            for phase, action in actions:
                try:
                    async with asyncio.timeout(self.cleanup_timeout):
                        await action()
                    self.events.append(phase)
                except (Exception, asyncio.CancelledError) as exc:
                    # Preserve a sanitized failure and still try later cleanup.
                    self.cleanup_errors.append((phase, type(exc).__name__))

        task = asyncio.create_task(finish_all())
        cancellation = None
        while not task.done():
            try:
                await asyncio.shield(task)
            except asyncio.CancelledError as exc:
                cancellation = exc
        task.result()
        if cancellation is not None:
            raise cancellation

    async def _scan(self):
        matches = {}

        def observed(device, advertisement):
            if matches_target(self.target, device, advertisement):
                matches[device.address.upper()] = device

        if self.discovery is not None:
            matches = await self.discovery.matches_for(self.target)
        else:
            scanner = self.scanner_factory(detection_callback=observed)
            try:
                await scanner.start()
                await asyncio.sleep(self.scan_seconds)
            finally:
                await self._finish([("scan-stopped", scanner.stop)])
        if self.cleanup_errors:
            raise CleanupError("scanner cleanup failed; connection was not attempted")
        if not matches:
            raise LookupError("owned target absent from fresh matching advertisements")
        if len(matches) != 1:
            raise PermissionError("ambiguous shoe identity; no connection attempted")
        found = next(iter(matches.values()))
        # The BlueZ scanner supplies its current Device1 properties in details.
        # Require a pre-existing local bond before any protected subscription;
        # pair=False alone is not a security-policy boundary on every backend.
        details = getattr(found, "details", None)
        props = details.get("props", {}) if isinstance(details, dict) else {}
        if props.get("Paired") is not True or props.get("Bonded") is not True:
            raise PermissionError("existing local Bluetooth bond required; no pairing initiated")
        # Bleak/BlueZ can reuse another local client's connection. Our cleanup
        # would then disconnect that session, so never adopt a connection that
        # is already present or whose state cannot be established here.
        if props.get("Connected") is not False:
            raise PermissionError("shoe already connected or connection state unknown; left untouched")
        return found

    def _characteristics(self):
        services = [s for s in self.client.services if s.uuid.lower() == SERVICE]
        if len(services) != 1:
            raise ValueError("expected one Nike command service")
        chars = services[0].characteristics
        writers = [c for c in chars if c.uuid.lower() == WRITE]
        readers = [c for c in chars if c.uuid.lower() == NOTIFY]
        write_property = ("write-without-response" if self.profile is LinkProfile.AUTO_MAX_2_4_3M
                          else "write")
        if (len(writers) != 1 or len(readers) != 1
                or write_property not in writers[0].properties
                or "notify" not in readers[0].properties):
            raise ValueError("missing, ambiguous or incompatible command characteristics")
        return writers[0], readers[0]

    async def _verify_auto_max_firmware(self):
        """Read standard firmware metadata before any Nike subscription/write."""
        services = [s for s in self.client.services if s.uuid.lower() == DEVICE_INFORMATION]
        if len(services) != 1:
            raise ValueError("one Device Information service required for Auto Max profile")
        chars = [c for c in services[0].characteristics if c.uuid.lower() == FIRMWARE_REVISION]
        if len(chars) != 1 or "read" not in chars[0].properties:
            raise ValueError("one readable firmware revision required for Auto Max profile")
        revision = await self.client.read_gatt_char(chars[0])
        self._check_connected()
        # The owned shoe's standard characteristic uses a 20-byte, zero-padded
        # field. Accept that observed encoding as well as the unpadded version;
        # arbitrary suffixes, widths and other firmware versions still fail.
        supported = (b"2.4.3M", b"2.4.3M".ljust(20, b"\x00"))
        if not isinstance(revision, (bytes, bytearray)) or revision not in supported:
            raise ValueError("Auto Max compatibility requires verified firmware 2.4.3M")
        self.events.append("firmware-verified")

    async def _disconnect(self):
        await self.client.disconnect()
        if self.client.is_connected:
            raise ConnectionError("backend still reports a connected shoe after disconnect")

    def _make_channel(self, write):
        profile = (TransportProfile.AUTO_MAX_CAPTURE
                   if self.profile is LinkProfile.AUTO_MAX_2_4_3M
                   else TransportProfile.APK_MODEL)
        return Transport(write, timeout=min(8, self.timeout), profile=profile)

    async def _after_authentication(self):
        """The authentication-only link has no post-authentication operation."""

    @asynccontextmanager
    async def authenticated_session(self, key):
        """Hold one verified existing-key link until its owner exits the context.

        The bounded handshake and shielded cleanup are shared with authenticate.
        This context issues no post-authentication command by itself.
        """
        key = validate_key(key)  # Never scan, subscribe, or enroll for a missing key.
        if self.used:
            raise ValueError("link already used; no automatic retry")
        self.used = True
        self.loop = asyncio.get_running_loop()
        self.thread = threading.get_ident()
        try:
            async with asyncio.timeout(self.timeout):
                device = await self._scan()
                self.client = self.client_factory(
                    device, pair=False, timeout=self.timeout,
                    disconnected_callback=self._disconnected,
                )
                await self.client.connect()
                self._check_connected()
                self.events.append("connected")
                writer, self.notify_char = self._characteristics()
                auto_max = self.profile is LinkProfile.AUTO_MAX_2_4_3M
                if auto_max:
                    await self._verify_auto_max_firmware()

                async def write(packet):
                    self._check_connected()
                    if not isinstance(packet, bytes) or not 2 <= len(packet) <= 20:
                        raise ValueError("invalid transport fragment")
                    await self.client.write_gatt_char(writer, packet, response=not auto_max)
                    self._check_connected()

                proof_format = ProofFormat.AUTO_MAX_2_4_3M if auto_max else ProofFormat.FULL_BLOCK
                self.channel = self._make_channel(write)
                self.subscribe_attempted = True
                await self.client.start_notify(self.notify_char, self._notification)
                self._check_connected()
                self.events.append("notifications-started")
                await Session(self.channel, timeout=self.timeout, proof_format=proof_format).authenticate_existing(key)
                self._check_connected()
                self.peer_proof_accepted = True
                self.events.append("authenticated")
            yield self.channel
        finally:
            self.closing = True
            if self.channel is not None:
                self.channel.close()
            actions = []
            if self.client is not None:
                if self.subscribe_attempted and self.client.is_connected:
                    actions.append(("notifications-stopped", lambda: self.client.stop_notify(self.notify_char)))
                actions.append(("disconnected", self._disconnect))
            await self._finish(actions)
        if self.cleanup_errors:
            raise CleanupError("attempt finished with incomplete BLE cleanup")

    async def authenticate(self, key):
        async with asyncio.timeout(self.timeout):
            async with self.authenticated_session(key):
                await self._after_authentication()
        return self.peer_proof_accepted

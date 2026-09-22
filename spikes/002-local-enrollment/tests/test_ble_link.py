"""Factory-injected lifecycle failures; only synthetic peers and keys are used."""
import asyncio
import threading
from types import SimpleNamespace as NS

import pytest

from ble_link import (CleanupError, DEVICE_INFORMATION, ExistingKeyLink, FIRMWARE_REVISION,
                      LinkProfile, NOTIFY, OwnedTarget, SERVICE, WRITE)
from simulation import SyntheticPeer


KEY = bytes(range(16))
TARGET = OwnedTarget("02:00:00:00:00:01", "004-TEST-000", True)


def identity_scanner(observations):
    def factory(*, detection_callback):
        class Scanner:
            async def start(self):
                for device, advertisement in observations:
                    detection_callback(device, advertisement)
            async def stop(self):
                pass
        return Scanner()
    return factory


def identity_observation(address, payload, *, paired=True, connected=False):
    return (NS(address=address, details={"props":{"Paired":paired, "Bonded":paired, "Connected":connected}}),
            NS(local_name=TARGET.advertised_name, manufacturer_data={0x78:payload}))


async def test_iphone_identity_resolves_current_linux_address_not_shared_product_name():
    identity = bytes([2,3,4,5,6,0])
    observations = [
        identity_observation("02:00:00:00:00:01", b"\xaf\x28" + identity),
        identity_observation("02:00:00:00:00:02", b"\xaf\x28" + identity[:-1] + b"\x01"),
        identity_observation("02:00:00:00:00:03", b"\x00\x00" + identity),
    ]
    link = ExistingKeyLink(OwnedTarget("", TARGET.advertised_name, True, identity),
        scanner_factory=identity_scanner(observations), client_factory=lambda *_:None, scan_seconds=0.001)
    assert await link._scan() is observations[0][0]


@pytest.mark.parametrize("paired,connected", [(False,False), (True,True), (True,None)])
async def test_imported_identity_never_bonds_or_adopts_another_connection(paired, connected):
    identity = bytes([2,3,4,5,6,0])
    observation = identity_observation(TARGET.address, b"\xaf\x28"+identity, paired=paired, connected=connected)
    link = ExistingKeyLink(OwnedTarget("", TARGET.advertised_name, True, identity),
        scanner_factory=identity_scanner([observation]), client_factory=lambda *_:pytest.fail("Must not connect"), scan_seconds=0.001)
    with pytest.raises(PermissionError):
        await link.authenticate(KEY)


async def test_duplicate_advertised_identity_fails_closed_before_connecting():
    identity = bytes([2,3,4,5,6,0])
    observations = [identity_observation("02:00:00:00:00:01", b"\xaf\x28"+identity),
                    identity_observation("02:00:00:00:00:02", b"\xaf\x28"+identity)]
    link = ExistingKeyLink(OwnedTarget("", TARGET.advertised_name, True, identity),
        scanner_factory=identity_scanner(observations), client_factory=lambda *_:pytest.fail("Must not connect"), scan_seconds=0.001)
    with pytest.raises(PermissionError, match="ambiguous"):
        await link.authenticate(KEY)


class Harness:
    def __init__(self, *, failure=None, hang=None, absent=False, profile=None,
                 auto_max=False, firmware=b"2.4.3M"):
        self.failure, self.hang = failure, hang
        self.absent, self.profile = absent, profile
        self.auto_max, self.firmware = auto_max, firmware
        self.events = []
        self.entered = asyncio.Event()
        self.release = asyncio.Event()
        self.device = NS(address=TARGET.address, details={"props": {
            "Paired": True, "Bonded": True, "Connected": False,
        }})
        self.client = None
        self.peer = SyntheticPeer(key=KEY, auto_max=auto_max)

    async def step(self, name):
        self.events.append(name)
        if self.hang == name:
            self.entered.set()
            await self.release.wait()
        if self.failure == name:
            raise OSError("synthetic backend failure")

    def scanner(self, *, detection_callback):
        outer = self
        class Scanner:
            async def start(self):
                await outer.step("scan-start")
                detection_callback(NS(address="02:00:00:00:00:02"), NS(
                    local_name=TARGET.advertised_name, manufacturer_data={0x78: b""}))
                # Cached device name or wrong company alone must not be accepted.
                detection_callback(outer.device, NS(local_name=None, manufacturer_data={0x78: b""}))
                detection_callback(outer.device, NS(local_name=TARGET.advertised_name, manufacturer_data={}))
                if not outer.absent:
                    detection_callback(outer.device, NS(
                        local_name=TARGET.advertised_name, manufacturer_data={0x78: b""}))
            async def stop(self):
                await outer.step("scan-stop")
        return Scanner()

    def client_factory(self, device, **kwargs):
        assert device is self.device  # Fresh BLEDevice, never an address lookup.
        assert self.events[-1] == "scan-stop"
        assert kwargs["pair"] is False
        outer = self
        class Client:
            def __init__(self):
                self.is_connected = False
                self.writer = NS(uuid=WRITE, properties=["write"])
                self.reader = NS(uuid=NOTIFY, properties=["notify"])
                self.services = [NS(uuid=SERVICE, characteristics=[self.writer, self.reader])]
                if outer.auto_max:
                    self.writer.properties.append("write-without-response")
                    self.firmware_char = NS(uuid=FIRMWARE_REVISION, properties=["read"])
                    self.services.append(NS(uuid=DEVICE_INFORMATION, characteristics=[self.firmware_char]))
                if outer.profile == "duplicate-service":
                    self.services *= 2
                elif outer.profile == "duplicate-writer":
                    self.services[0].characteristics.append(self.writer)
                elif outer.profile == "no-write-response":
                    self.writer.properties = ["write-without-response"]
                elif outer.profile == "no-notify":
                    self.reader.properties = ["read"]
                elif outer.profile == "missing-firmware":
                    self.services.pop()
                elif outer.profile == "duplicate-firmware":
                    self.services[-1].characteristics.append(self.firmware_char)
                elif outer.profile == "no-write-without-response":
                    self.writer.properties = ["write"]

            async def connect(self):
                self.is_connected = True  # Partial success before a possible error.
                await outer.step("connect")

            async def disconnect(self):
                await outer.step("disconnect")
                if outer.profile != "false-disconnect-success":
                    self.is_connected = False
                    kwargs["disconnected_callback"](self)

            async def start_notify(self, characteristic, callback):
                assert characteristic is self.reader
                self.callback = callback
                outer.peer.channel = NS(notify=lambda data: callback(self.reader, data))
                await outer.step("subscribe")

            async def stop_notify(self, characteristic):
                assert characteristic is self.reader
                await outer.step("unsubscribe")

            async def write_gatt_char(self, characteristic, data, *, response):
                assert characteristic is self.writer and response is (not outer.auto_max)
                await outer.step("write")
                if outer.profile == "remote-disconnect":
                    self.is_connected = False
                    kwargs["disconnected_callback"](self)
                elif outer.profile == "foreign-callback-thread":
                    thread = threading.Thread(target=lambda: self.callback(self.reader, b"\x80\x00"))
                    thread.start()
                    thread.join()
                    await asyncio.sleep(0)
                else:
                    await outer.peer.write(data)

            async def read_gatt_char(self, characteristic):
                assert characteristic is self.firmware_char
                await outer.step("firmware-read")
                return outer.firmware
        self.client = Client()
        return self.client

    def link(self, **kwargs):
        if self.auto_max:
            kwargs.setdefault("profile", LinkProfile.AUTO_MAX_2_4_3M)
        return ExistingKeyLink(TARGET, scanner_factory=self.scanner,
                               client_factory=self.client_factory,
                               scan_seconds=0.001, timeout=0.2,
                               cleanup_timeout=0.03, **kwargs)


async def test_existing_key_lifecycle_sends_only_auth_and_cleans_up():
    h = Harness()
    link = h.link()
    assert await link.authenticate(KEY) is True
    assert h.peer.commands == [112, 113]
    assert h.events[:4] == ["scan-start", "scan-stop", "connect", "subscribe"]
    assert h.events[-2:] == ["unsubscribe", "disconnect"]
    assert not h.client.is_connected and link.channel.closed
    count = len(h.events)
    with pytest.raises(ValueError, match="already used"):
        await link.authenticate(KEY)
    assert len(h.events) == count


@pytest.mark.parametrize("firmware", [b"2.4.3M", b"2.4.3M".ljust(20, b"\x00")])
async def test_auto_max_profile_verifies_firmware_then_only_authenticates(firmware):
    h = Harness(auto_max=True, firmware=firmware)
    link = h.link()
    assert await link.authenticate(KEY)
    assert h.events[:5] == ["scan-start", "scan-stop", "connect", "firmware-read", "subscribe"]
    assert h.peer.commands == [112, 113]
    assert link.events == ["scan-stopped", "connected", "firmware-verified", "notifications-started",
                           "authenticated", "notifications-stopped", "disconnected"]
    assert not h.client.is_connected


@pytest.mark.parametrize("firmware", [b"", b"2.4.3", b"2.4.4M", b"2.4.3M\x00", None,
                                      b"2.4.4M".ljust(20, b"\x00"),
                                      b"2.4.3M".ljust(19, b"\x00"),
                                      b"2.4.3M".ljust(19, b"\x00") + b"X"])
async def test_auto_max_firmware_mismatch_stops_before_subscription(firmware):
    h = Harness(auto_max=True, firmware=firmware)
    with pytest.raises(ValueError, match="firmware"):
        await h.link().authenticate(KEY)
    assert h.events == ["scan-start", "scan-stop", "connect", "firmware-read", "disconnect"]
    assert h.peer.commands == []


@pytest.mark.parametrize("profile", ["missing-firmware", "duplicate-firmware", "no-write-without-response"])
async def test_auto_max_missing_characteristic_stops_before_subscription(profile):
    h = Harness(auto_max=True, profile=profile)
    with pytest.raises(ValueError):
        await h.link().authenticate(KEY)
    assert "subscribe" not in h.events and "write" not in h.events
    assert h.events[-1] == "disconnect"


async def test_auto_max_firmware_read_cancellation_cleans_up():
    h = Harness(auto_max=True, hang="firmware-read")
    link = h.link()
    task = asyncio.create_task(link.authenticate(KEY))
    await h.entered.wait()
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
    assert h.events[-1] == "disconnect"
    assert "subscribe" not in h.events and not link.peer_proof_accepted


def test_auto_max_profile_cannot_be_selected_for_huarache():
    huarache = OwnedTarget("02:00:00:00:00:01", "002-TEST-000", True)
    with pytest.raises(ValueError, match="family-004"):
        ExistingKeyLink(huarache, profile=LinkProfile.AUTO_MAX_2_4_3M)


async def test_auto_max_wrong_key_stops_after_start_without_any_enrollment():
    h = Harness(auto_max=True)
    link = h.link()
    with pytest.raises(ValueError, match="proof mismatch"):
        await link.authenticate(bytes(range(32, 48)))
    assert h.peer.commands == [112]
    assert h.events[-2:] == ["unsubscribe", "disconnect"]
    assert not link.peer_proof_accepted


@pytest.mark.parametrize("kind", ["error", "timeout"])
async def test_auto_max_firmware_read_failure_cleans_up_without_subscription(kind):
    h = Harness(auto_max=True, **({"failure": "firmware-read"} if kind == "error" else {"hang": "firmware-read"}))
    link = h.link()
    link.timeout = 0.015
    with pytest.raises(OSError if kind == "error" else TimeoutError):
        await link.authenticate(KEY)
    assert "subscribe" not in h.events and h.events[-1] == "disconnect"


@pytest.mark.parametrize("key", [None, b"", b"short", b"\x01" * 16, bytearray(16)])
async def test_missing_or_invalid_key_prevents_all_radio_access(key):
    h = Harness()
    with pytest.raises(ValueError):
        await h.link().authenticate(key)
    assert h.events == [] and h.client is None


async def test_missing_exact_target_does_not_construct_client():
    h = Harness(absent=True)
    with pytest.raises(LookupError):
        await h.link().authenticate(KEY)
    assert h.events == ["scan-start", "scan-stop"] and h.client is None


@pytest.mark.parametrize("props", [{}, {"Paired": True}, {"Paired": False, "Bonded": False},
                                   {"Paired": True, "Bonded": False}])
async def test_missing_local_bond_stops_before_connect_or_subscription(props):
    h = Harness()
    h.device.details = {"props": props}
    with pytest.raises(PermissionError, match="existing local Bluetooth bond"):
        await h.link().authenticate(KEY)
    assert h.events == ["scan-start", "scan-stop"] and h.client is None


@pytest.mark.parametrize("connected", [True, None, 0])
async def test_existing_or_unknown_connection_is_preserved(connected):
    h = Harness()
    h.device.details["props"]["Connected"] = connected
    if connected is None:
        del h.device.details["props"]["Connected"]
    with pytest.raises(PermissionError, match="already connected or connection state unknown"):
        await h.link().authenticate(KEY)
    assert h.events == ["scan-start", "scan-stop"]
    assert h.client is None and h.peer.commands == []


@pytest.mark.parametrize("phase", ["scan-start", "scan-stop", "connect", "subscribe", "write", "unsubscribe", "disconnect"])
async def test_backend_errors_always_attempt_appropriate_cleanup(phase):
    h = Harness(failure=phase)
    link = h.link()
    with pytest.raises((OSError, CleanupError)):
        await link.authenticate(KEY)
    if phase.startswith("scan"):
        assert h.events == ["scan-start", "scan-stop"] and h.client is None
    else:
        assert h.events[-1] == "disconnect"
        if phase != "connect":
            assert "unsubscribe" in h.events and link.channel.closed
    count = len(h.events)
    with pytest.raises(ValueError, match="already used"):
        await link.authenticate(KEY)
    assert len(h.events) == count


@pytest.mark.parametrize("profile", ["duplicate-service", "duplicate-writer", "no-write-response", "no-notify"])
async def test_profile_is_validated_before_subscription_or_write(profile):
    h = Harness(profile=profile)
    with pytest.raises(ValueError):
        await h.link().authenticate(KEY)
    assert h.events == ["scan-start", "scan-stop", "connect", "disconnect"]


@pytest.mark.parametrize("phase", ["scan-start", "connect", "subscribe", "write"])
async def test_cancellation_cleans_up_partial_operation(phase):
    h = Harness(hang=phase)
    link = h.link()
    task = asyncio.create_task(link.authenticate(KEY))
    await h.entered.wait()
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
    assert h.events[-1] == ("scan-stop" if phase == "scan-start" else "disconnect")
    assert not link.peer_proof_accepted


@pytest.mark.parametrize("phase", ["scan-start", "connect", "subscribe", "write"])
async def test_deadline_cleans_up_hanging_backend(phase):
    h = Harness(hang=phase)
    link = h.link()
    link.timeout = 0.015
    with pytest.raises(TimeoutError):
        await link.authenticate(KEY)
    assert h.events[-1] == ("scan-stop" if phase == "scan-start" else "disconnect")


async def test_repeated_cancellation_does_not_interrupt_same_disconnect():
    h = Harness(hang="disconnect")
    link = h.link()
    task = asyncio.create_task(link.authenticate(KEY))
    await h.entered.wait()
    task.cancel()
    await asyncio.sleep(0)
    task.cancel()
    await asyncio.sleep(0)
    assert not task.done()
    h.release.set()
    with pytest.raises(asyncio.CancelledError):
        await task
    assert h.events.count("disconnect") == 1 and not h.client.is_connected


async def test_cleanup_timeout_is_reported_even_after_authentication():
    h = Harness(hang="disconnect")
    link = h.link()
    with pytest.raises(CleanupError):
        await link.authenticate(KEY)
    assert link.peer_proof_accepted
    assert link.cleanup_errors == [("disconnected", "TimeoutError")]
    assert h.client.is_connected


async def test_false_disconnect_success_is_not_reported_as_clean():
    h = Harness(profile="false-disconnect-success")
    link = h.link()
    with pytest.raises(CleanupError):
        await link.authenticate(KEY)
    assert link.cleanup_errors == [("disconnected", "ConnectionError")]


@pytest.mark.parametrize("profile", ["remote-disconnect", "foreign-callback-thread"])
async def test_disconnect_or_wrong_callback_thread_stops_without_replay(profile):
    h = Harness(profile=profile)
    link = h.link()
    with pytest.raises((ConnectionError, ValueError)):
        await link.authenticate(KEY)
    assert h.events.count("write") == 1
    assert h.events[-1] == "disconnect" and link.channel.closed


@pytest.mark.parametrize("address,name,owned", [
    ("", "004-TEST-000", True), ("02:00:00:00:00:01", "", True),
    ("02:00:00:00:00:01", "004-TEST-000", False),
])
def test_invalid_target_is_rejected(address, name, owned):
    with pytest.raises(ValueError):
        OwnedTarget(address, name, owned)

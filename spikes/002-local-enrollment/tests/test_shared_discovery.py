"""Shared scanning is exercised with synthetic advertisements only."""
import asyncio
import pytest
from ble_link import SharedShoeDiscovery, ExistingKeyLink, OwnedTarget, CleanupError
from test_ble_link import TARGET, identity_observation

OTHER = OwnedTarget("02:00:00:00:00:02", TARGET.advertised_name, True)


class Scan:
    def __init__(self, observations, *, fail_stop=False, block_stop=False):
        self.observations = observations
        self.starts = self.stops = 0
        self.started, self.stopping, self.finish_stop = (asyncio.Event() for _ in range(3))
        self.fail_stop, self.block_stop = fail_stop, block_stop

    def factory(self, *, detection_callback):
        owner = self
        class Scanner:
            async def start(self):
                owner.starts += 1
                for device, advertisement in owner.observations:
                    detection_callback(device, advertisement)
                owner.started.set()
            async def stop(self):
                owner.stops += 1
                owner.stopping.set()
                if owner.block_stop:
                    await owner.finish_stop.wait()
                if owner.fail_stop:
                    raise OSError("synthetic stop failure")
        return Scanner()


def link(target, discovery, scan):
    return ExistingKeyLink(target, discovery=discovery, scanner_factory=scan.factory,
                           client_factory=lambda *_:pytest.fail("Scan never opens a client"))


async def test_one_scan_finds_both_and_neither_can_connect_before_scanner_stops():
    observations = [identity_observation(t.address, b"") for t in (TARGET, OTHER)]
    scan = Scan(observations, block_stop=True)
    discovery = SharedShoeDiscovery([TARGET, OTHER], scanner_factory=scan.factory, scan_seconds=0.001)
    readers = [asyncio.create_task(link(t, discovery, scan)._scan()) for t in (TARGET, OTHER)]
    await scan.stopping.wait()
    assert scan.starts == scan.stops == 1 and not any(t.done() for t in readers)
    scan.finish_stop.set()
    assert await asyncio.gather(*readers) == [row[0] for row in observations]
    await discovery.close()
    with pytest.raises(ValueError):
        await discovery.matches_for(TARGET)


async def test_missing_partner_does_not_hide_found_shoe():
    scan = Scan([identity_observation(TARGET.address, b"")])
    discovery = SharedShoeDiscovery([TARGET, OTHER], scanner_factory=scan.factory, scan_seconds=0.001)
    results = await asyncio.gather(*(link(t, discovery, scan)._scan() for t in (TARGET, OTHER)), return_exceptions=True)
    assert results[0].address == TARGET.address and isinstance(results[1], LookupError)
    assert scan.starts == scan.stops == 1
    await discovery.close()


async def test_stop_failure_blocks_both_connections():
    scan = Scan([identity_observation(t.address, b"") for t in (TARGET, OTHER)], fail_stop=True)
    discovery = SharedShoeDiscovery([TARGET, OTHER], scanner_factory=scan.factory, scan_seconds=0.001)
    results = await asyncio.gather(*(link(t, discovery, scan)._scan() for t in (TARGET, OTHER)), return_exceptions=True)
    assert all(isinstance(r, CleanupError) for r in results)
    await discovery.close()


async def test_cancelled_readers_and_owner_close_stop_shared_scan_once():
    scan = Scan([], block_stop=True)
    discovery = SharedShoeDiscovery([TARGET, OTHER], scanner_factory=scan.factory, scan_seconds=5)
    readers = [asyncio.create_task(discovery.matches_for(t)) for t in (TARGET, OTHER)]
    await scan.started.wait()
    for task in readers:
        task.cancel()
    await asyncio.gather(*readers, return_exceptions=True)
    closing = asyncio.create_task(discovery.close())
    await scan.stopping.wait()
    assert not closing.done()
    scan.finish_stop.set()
    await closing
    assert discovery.task.done() and scan.starts == scan.stops == 1


@pytest.mark.parametrize("paired,connected", [(False,False), (True,True), (True,None)])
async def test_shared_scan_preserves_bond_and_existing_connection_guards(paired, connected):
    scan = Scan([identity_observation(TARGET.address, b"", paired=paired, connected=connected)])
    discovery = SharedShoeDiscovery([TARGET], scanner_factory=scan.factory, scan_seconds=0.001)
    with pytest.raises(PermissionError):
        await link(TARGET, discovery, scan)._scan()
    await discovery.close()


async def test_shared_scan_preserves_identity_ambiguity_guard():
    identity = bytes([2,3,4,5,6,0])
    target = OwnedTarget("", TARGET.advertised_name, True, identity)
    scan = Scan([identity_observation(t.address, b"\xaf\x28"+identity) for t in (TARGET, OTHER)])
    discovery = SharedShoeDiscovery([target], scanner_factory=scan.factory, scan_seconds=0.001)
    with pytest.raises(PermissionError, match="ambiguous"):
        await link(target, discovery, scan)._scan()
    await discovery.close()

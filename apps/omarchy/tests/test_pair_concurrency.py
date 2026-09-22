"""Independent shoes progress concurrently without a Bluetooth adapter."""
import asyncio
import pytest
from test_panel_session import FakeLink, controller
import openadapt_session as session


class GatedLink(FakeLink):
    gates = {}
    entered = {}
    cancelled = set()
    fail_side = None
    delayed_action = None

    async def pause(self, action):
        if action == self.delayed_action:
            self.entered[self.side].set()
            try:
                await self.gates[self.side].wait()
            except asyncio.CancelledError:
                self.cancelled.add(self.side)
                raise

    async def start(self, key):
        await self.pause("connect")
        return await super().start(key)

    async def execute(self, action, **kwargs):
        if action == "lace":
            self.changed("moving", {"raw_position":30, "battery_percent":88})
        await self.pause(action)
        if self.side == self.fail_side:
            self.connected = False
            self.changed("disconnected", None)
            raise ConnectionError("private shoe details")
        return await super().execute(action, **kwargs)


@pytest.fixture
def concurrent(controller):
    controller.link_factory = GatedLink
    GatedLink.gates = {s:asyncio.Event() for s in session.storage.SIDES}
    GatedLink.entered = {s:asyncio.Event() for s in session.storage.SIDES}
    GatedLink.cancelled = set()
    GatedLink.fail_side = None
    GatedLink.delayed_action = None
    return controller


async def entered_both():
    await asyncio.wait_for(asyncio.gather(*(e.wait() for e in GatedLink.entered.values())), 1)


async def test_both_connections_begin_before_either_finishes(concurrent):
    GatedLink.delayed_action = "connect"
    task = asyncio.create_task(concurrent.dispatch({"action":"connect", "pair_id":"first"}))
    try:
        await entered_both()
        assert all(f["connection"] == "connecting" for f in concurrent.public()["feet"].values())
        GatedLink.gates["right"].set()
        async with asyncio.timeout(1):
            while not concurrent.public()["feet"]["right"]["connected"]:
                await asyncio.sleep(0)
        assert not task.done() and concurrent.public()["preferred_pair_id"] is None
        GatedLink.gates["left"].set()
        await task
        assert concurrent.public()["preferred_pair_id"] == "first"
    finally:
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        await concurrent.disconnect()


@pytest.mark.parametrize("command,action", [
    ({"action":"tie"}, "lace"), ({"action":"untie"}, "lace"),
    ({"action":"lace", "side":"both", "percent":75}, "lace"),
    ({"action":"mode-apply", "mode_id":"chill"}, "lace"),
    ({"action":"color", "side":"both", "color":"green"}, "color"),
    ({"action":"lights-off"}, "lights-off"), ({"action":"battery"}, "battery"),
])
async def test_paired_controls_start_both_and_wait_for_both(concurrent, command, action):
    await concurrent.dispatch({"action":"connect", "pair_id":"first"})
    GatedLink.delayed_action = action
    task = asyncio.create_task(concurrent.dispatch(command))
    try:
        await entered_both()
        GatedLink.gates["right"].set()
        await asyncio.sleep(0)
        assert not task.done() and concurrent.public()["busy"]
        GatedLink.gates["left"].set()
        await task
        assert not concurrent.public()["busy"]
    finally:
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)


@pytest.mark.parametrize("action", ["connect", "lace", "color"])
async def test_cancellation_drains_both_children_before_accepting_more_work(concurrent, action):
    if action != "connect":
        await concurrent.dispatch({"action":"connect", "pair_id":"first"})
    GatedLink.delayed_action = action
    request = {"connect":{"action":"connect", "pair_id":"first"}, "lace":{"action":"tie"},
               "color":{"action":"color", "side":"both", "color":"green"}}[action]
    task = asyncio.create_task(concurrent.dispatch(request))
    await entered_both()
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
    assert GatedLink.cancelled == {"left", "right"}
    assert not concurrent.public()["busy"]
    await concurrent.disconnect()
    for gate in GatedLink.gates.values():
        gate.set()
    await asyncio.sleep(0)
    assert not concurrent.public()["connected"]
    assert all(f["movement"] is None for f in concurrent.public()["feet"].values())


@pytest.mark.parametrize("failed_side", ["left", "right"])
@pytest.mark.parametrize("action", ["lace", "color"])
async def test_one_failure_preserves_partner_completion_and_reports_correct_side(concurrent, failed_side, action):
    await concurrent.dispatch({"action":"connect", "pair_id":"first"})
    GatedLink.delayed_action = action
    GatedLink.fail_side = failed_side
    other = "right" if failed_side == "left" else "left"
    request = {"action":"mode-apply", "mode_id":"chill"} if action == "lace" else {"action":"color", "side":"both", "color":"green"}
    task = asyncio.create_task(concurrent.dispatch(request))
    await entered_both()
    GatedLink.gates[failed_side].set()
    await asyncio.sleep(0)
    assert not task.done()
    GatedLink.gates[other].set()
    with pytest.raises(session.storage.UserError, match=other.capitalize()+" shoe updated"):
        await task
    assert concurrent.public()["feet"][other]["status"] == "verified"
    assert concurrent.public()["feet"][failed_side]["status"] == "check-shoe"
    assert concurrent.public()["tie_mode_id"] == "move"
    assert "private shoe" not in concurrent.public()["message"]

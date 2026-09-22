"""Behavioral tests with simulated shoes; no Bluetooth adapter is opened."""
import asyncio
import copy
import stat
import pytest
from test_panel_session import FakeLink, controller, pair
import openadapt_session as session
from panel_preferences import Preferences


class MovingLink(FakeLink):
    fail_side = None
    gate = None
    moved = None
    preflight_gate = None
    async def execute(self, action, **kwargs):
        self.calls.append((action, kwargs))
        if action != "lace":
            return {}
        if self.preflight_gate is not None and self.side == "right":
            await self.preflight_gate.wait()
        before = {"raw_position":30, "battery_percent":88}
        self.changed("moving", before)
        if self.side == self.fail_side:
            self.connected = False
            self.changed("disconnected", None)
            raise ConnectionError("private device detail")
        if self.gate is not None and self.side == "left":
            self.moved.set()
            await self.gate.wait()
        return {"before":before, "after_raw_position":round(kwargs["percent"] * kwargs["maximum"] / 100)}


@pytest.fixture
def moving(controller):
    controller.link_factory = MovingLink
    MovingLink.fail_side = None
    MovingLink.fail_right = False
    MovingLink.gate = None
    MovingLink.preflight_gate = None
    return controller


async def test_preferred_pair_requires_complete_connection_and_restores_without_radio(controller):
    await controller.dispatch({"action":"connect", "pair_id":"second"})
    FakeLink.fail_right = True
    await controller.dispatch({"action":"connect", "pair_id":"first"})
    assert controller.public()["selected_id"] == "first"
    assert controller.public()["preferred_pair_id"] == "second"
    await controller.disconnect()
    count = len(FakeLink.instances)
    restarted = session.Controller(entries=[pair(), pair("second")], link_factory=FakeLink)
    assert restarted.public()["selected_id"] == "second"
    assert len(FakeLink.instances) == count and not restarted.public()["connected"]


async def test_retry_preserves_authenticated_partner(controller):
    FakeLink.fail_right = True
    await controller.dispatch({"action":"connect", "pair_id":"first"})
    first = FakeLink.instances[0]
    FakeLink.fail_right = False
    await controller.dispatch({"action":"connect", "pair_id":"first"})
    assert first.calls == ["connect"] and len(FakeLink.instances) == 3
    assert controller.public()["preferred_pair_id"] == "first"


async def test_tie_initial_default_and_remembered_mode_survive_untie_and_manual_fit(moving):
    await moving.dispatch({"action":"connect", "pair_id":"first"})
    await moving.dispatch({"action":"tie"})
    assert [moving.feet[s]["percent"] for s in session.storage.SIDES] == [60, 60]
    await moving.dispatch({"action":"mode-apply", "mode_id":"chill"})
    await moving.dispatch({"action":"untie"})
    assert [moving.feet[s]["percent"] for s in session.storage.SIDES] == [0, 0]
    await moving.dispatch({"action":"lace", "side":"left", "percent":75})
    await moving.dispatch({"action":"tie"})
    assert [moving.feet[s]["percent"] for s in session.storage.SIDES] == [30, 30]


async def test_modes_capture_confirmed_sides_persist_and_do_not_touch_credentials(moving):
    await moving.dispatch({"action":"connect", "pair_id":"first"})
    await moving.dispatch({"action":"lace", "side":"left", "percent":75})
    await moving.dispatch({"action":"mode-save", "name":"  Everyday  "})
    mode = moving.public()["modes"][-1]
    assert (mode["name"], mode["left"], mode["right"]) == ("Everyday", 75, 50)
    await moving.dispatch({"action":"mode-rename", "mode_id":mode["id"], "name":"Walk"})
    await moving.dispatch({"action":"mode-apply", "mode_id":mode["id"]})
    prefs = Preferences(["first", "second"])
    assert prefs.public("first")["tie_mode_id"] == mode["id"]
    assert prefs.public("first")["modes"][-1]["name"] == "Walk"
    assert prefs.public("second")["tie_mode_id"] == "move"
    assert stat.S_IMODE(prefs.path.stat().st_mode) == 0o600
    assert not session.storage.CONFIG.exists()
    assert "key_hex" not in prefs.path.read_text()


async def test_deleted_mode_is_never_replayed_and_empty_list_blocks_tie(moving):
    await moving.dispatch({"action":"connect", "pair_id":"first"})
    await moving.dispatch({"action":"mode-apply", "mode_id":"chill"})
    await moving.dispatch({"action":"mode-remove", "mode_id":"chill"})
    assert moving.public()["tie_mode_id"] == "move"
    await moving.dispatch({"action":"mode-remove", "mode_id":"move"})
    count = [len(moving.links[s].calls) for s in session.storage.SIDES]
    for request in [{"action":"tie"}, {"action":"mode-apply", "mode_id":"chill"}]:
        with pytest.raises(session.storage.UserError):
            await moving.dispatch(request)
    assert [len(moving.links[s].calls) for s in session.storage.SIDES] == count


async def test_partial_fit_does_not_remember_mode_or_claim_full_completion(moving):
    await moving.dispatch({"action":"connect", "pair_id":"first"})
    MovingLink.fail_side = "right"
    with pytest.raises(session.storage.UserError, match="Left shoe updated"):
        await moving.dispatch({"action":"mode-apply", "mode_id":"chill"})
    assert moving.public()["tie_mode_id"] == "move"
    assert moving.public()["feet"]["left"]["movement"]["phase"] == "confirmed"
    assert moving.public()["feet"]["right"]["movement"]["phase"] == "unconfirmed"
    assert "private device" not in moving.message


async def test_queued_shoe_does_not_animate_and_each_completion_is_confirmed(moving):
    await moving.dispatch({"action":"connect", "pair_id":"first"})
    MovingLink.gate, MovingLink.moved = asyncio.Event(), asyncio.Event()
    MovingLink.preflight_gate = asyncio.Event()
    updates = []
    moving.emit = lambda state: updates.append(copy.deepcopy(state))
    task = asyncio.create_task(moving.dispatch({"action":"tie"}))
    await MovingLink.moved.wait()
    state = moving.public()
    assert state["feet"]["left"]["movement"]["phase"] == "moving"
    assert state["feet"]["right"]["movement"]["phase"] == "queued"
    assert state["feet"]["right"]["movement"]["started_at"] is None
    assert state["feet"]["left"]["percent"] == 50
    MovingLink.preflight_gate.set()
    # Right can complete while left is still moving, after its own preflight.
    async with asyncio.timeout(1):
        while moving.public()["feet"]["right"]["movement"]["phase"] != "confirmed":
            await asyncio.sleep(0)
    assert not task.done()
    MovingLink.gate.set()
    await task
    assert all(moving.public()["feet"][s]["movement"]["phase"] == "confirmed" for s in session.storage.SIDES)
    assert any((u["feet"]["left"]["movement"] or {}).get("phase") == "moving" and u["feet"]["right"]["movement"]["phase"] == "confirmed" for u in updates)


async def test_old_link_notifications_cannot_change_new_pair(moving):
    await moving.dispatch({"action":"connect", "pair_id":"first"})
    old = moving.links["left"]
    await moving.dispatch({"action":"connect", "pair_id":"second"})
    before = moving.public()
    old.changed("position", {"raw_position":1})
    old.changed("disconnected", None)
    assert moving.public() == before


async def test_cancelled_fit_is_not_remembered_or_replayed(moving):
    await moving.dispatch({"action":"connect", "pair_id":"first"})
    MovingLink.gate, MovingLink.moved = asyncio.Event(), asyncio.Event()
    task = asyncio.create_task(moving.dispatch({"action":"mode-apply", "mode_id":"chill"}))
    await MovingLink.moved.wait()
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
    await moving.dispatch({"action":"disconnect"})
    assert moving.public()["tie_mode_id"] == "move"
    assert all(f["movement"] is None for f in moving.public()["feet"].values())
    assert not moving.public()["busy"]


@pytest.mark.parametrize("action", ["tie", "untie", "mode-save", "lights-off"])
async def test_pair_actions_reject_partial_connection_before_any_command(moving, action):
    MovingLink.fail_right = True
    await moving.dispatch({"action":"connect", "pair_id":"first"})
    MovingLink.fail_right = False
    before = list(moving.links["left"].calls)
    with pytest.raises(session.storage.UserError):
        await moving.dispatch({"action":action, **({"name":"New"} if action == "mode-save" else {})})
    assert moving.links["left"].calls == before


async def test_unknown_calibration_blocks_pair_fit_before_first_motor(moving):
    await moving.dispatch({"action":"connect", "pair_id":"first"})
    target, key, _ = moving.profiles["right"]
    moving.profiles["right"] = (target, key, 0)
    before = [list(moving.links[s].calls) for s in session.storage.SIDES]
    with pytest.raises(session.storage.UserError, match="calibration"):
        await moving.dispatch({"action":"tie"})
    assert [moving.links[s].calls for s in session.storage.SIDES] == before


@pytest.mark.parametrize("command", [{"action":"mode-save", "name":" "}, {"action":"mode-save", "name":"a"*41},
    {"action":"mode-rename", "name":"x", "mode_id":"../oops"}, {"action":"tie", "percent":60},
    {"action":"mode-save", "name":"bad\nname"}])
def test_invalid_mode_requests_rejected(command):
    with pytest.raises(session.storage.UserError):
        session.validate_request(command)


async def test_panel_open_restores_default_only_when_no_live_shoes(controller):
    await controller.dispatch({"action":"connect", "pair_id":"second"})
    FakeLink.fail_right = True
    await controller.dispatch({"action":"connect", "pair_id":"first"})
    await controller.dispatch({"action":"panel-open"})
    assert controller.public()["selected_id"] == "first"  # Preserve its live left shoe.
    await controller.disconnect()
    count = len(FakeLink.instances)
    await controller.dispatch({"action":"panel-open"})
    assert controller.public()["selected_id"] == "second"
    assert len(FakeLink.instances) == count and not controller.public()["connected"]


async def test_mode_limit_and_invalid_empty_name_do_not_change_saved_fits(moving):
    await moving.dispatch({"action":"connect", "pair_id":"first"})
    for index in range(18):
        await moving.dispatch({"action":"mode-save", "name":f"Fit {index}"})
    before = moving.public()["modes"]
    with pytest.raises(session.storage.UserError, match="20"):
        await moving.dispatch({"action":"mode-save", "name":"Extra"})
    with pytest.raises(session.storage.UserError):
        await moving.dispatch({"action":"mode-rename", "mode_id":"move", "name":" "})
    assert moving.public()["modes"] == before

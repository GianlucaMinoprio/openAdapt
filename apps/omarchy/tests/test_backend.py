import asyncio
import copy
import importlib.util
from pathlib import Path
import time

import pytest

spec = importlib.util.spec_from_file_location("openadapt_app", Path(__file__).parents[1]/"backend/openadapt_app.py")
app = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app)


@pytest.fixture
def isolated(tmp_path, monkeypatch):
    monkeypatch.setattr(app,"STATE",tmp_path/"state")
    monkeypatch.setattr(app,"CONFIG",tmp_path/"config")
    return app.blank_state()


@pytest.mark.parametrize("command", [
    {"action":"lace","side":"left","percent":3},
    {"action":"lace","side":"left","percent":105},
    {"action":"lace","side":"right","percent":True},
    {"action":"lace","side":"all","percent":80},
    {"action":"color","side":"both","color":"unknown"},
    {"action":"resume","empty_shoes":False,"nike_closed":True},
    {"action":"resume","empty_shoes":True,"nike_closed":False},
    {"action":"reset"}, {"action":"pair"}, {"action":"cache","key":"hidden"},
])
def test_unsupported_requests_are_rejected(command):
    with pytest.raises(app.UserError):
        app.validate_command(command)


def test_all_requested_slider_steps_are_accepted():
    for value in range(0,101,5):
        assert app.validate_command({"action":"lace","side":"left","percent":value}) == "lace"


def test_cache_pause_and_resume_do_not_load_radio_or_profiles(isolated):
    def forbidden():
        raise AssertionError("Radio/profile loader reached")
    for command in ({"action":"cache"}, {"action":"resume","empty_shoes":True,"nike_closed":True}, {"action":"pause"}):
        isolated=asyncio.run(app.dispatch(command,isolated,profiles_loader=forbidden))
    assert isolated["paused"] and isolated["enabled_until"] == 0


@pytest.mark.parametrize("paused,expires", [(True,time.time()+1800),(False,0)])
def test_paused_or_expired_controls_do_not_touch_profiles(isolated,paused,expires):
    isolated.update(paused=paused,enabled_until=expires)
    def forbidden():
        raise AssertionError("Radio/profile loader reached")
    with pytest.raises(app.UserError,match="paused"):
        asyncio.run(app.dispatch({"action":"lace","side":"left","percent":80},isolated,profiles_loader=forbidden))


class Link:
    calls=[]
    fail_side=None
    def __init__(self,target):
        self.side=target
    async def read_status(self,key):
        self.calls.append((self.side,"status"))
        return {"before":{"raw_position":30,"battery_percent":88}}
    async def set_position(self,key,**kwargs):
        self.calls.append((self.side,"lace",kwargs))
        if self.side == self.fail_side:
            raise ConnectionError("synthetic private address must not reach UI")
        return {"before":{"battery_percent":88},"after_raw_position":40}
    async def set_color(self,key,color):
        self.calls.append((self.side,"color",color))
    async def lights_off(self,key):
        self.calls.append((self.side,"lights-off"))


def profiles():
    return {s:(s,bytes(range(16)),50) for s in app.SIDES}


@pytest.mark.parametrize("command,expected", [
    ({"action":"lace","side":"right","percent":80},[("right","lace")]),
    ({"action":"battery"},[("left","status"),("right","status")]),
    ({"action":"color","side":"both","color":"cyan"},[("left","color"),("right","color")]),
    ({"action":"lights-off"},[("left","lights-off"),("right","lights-off")]),
])
def test_commands_are_sequential_scoped_and_persisted(isolated,command,expected):
    Link.calls=[]; Link.fail_side=None
    isolated.update(paused=False,enabled_until=time.time()+1800)
    asyncio.run(app.dispatch(command,isolated,profiles_loader=profiles,links=(Link,Link)))
    assert [(c[0],c[1]) for c in Link.calls] == expected
    saved=app.read_json(app.STATE/"state.json")
    for side,_ in expected:
        assert saved["feet"][side]["status"] == "verified"


def test_partial_pair_failure_preserves_first_success_without_replay(isolated):
    Link.calls=[]; Link.fail_side="right"
    isolated.update(paused=False,enabled_until=time.time()+1800)
    with pytest.raises(ConnectionError):
        asyncio.run(app.dispatch({"action":"lace","side":"both","percent":80},isolated,
                                profiles_loader=profiles,links=(Link,Link)))
    saved=app.read_json(app.STATE/"state.json")
    assert saved["feet"]["left"]["percent"] == 80
    assert saved["feet"]["right"]["percent"] == 0
    assert saved["feet"]["right"]["status"] == "check-shoe"
    assert len(Link.calls) == 2
    Link.fail_side=None


def test_public_state_never_exports_keys_or_device_identifiers(isolated):
    isolated.update(key_hex="secret",address="private",identifier="owner")
    isolated["feet"]["left"].update(authenticationKey="secret",raw_position=20,address="private")
    result=app.public_state(isolated)
    text=str(result)
    assert "secret" not in text and "private" not in text and "owner" not in text


def test_exception_details_are_not_shown_to_ui():
    assert "private" not in app.friendly_error(ValueError("private data"))


def test_private_state_is_owner_only_and_expired_sessions_pause(isolated):
    isolated.update(paused=False,enabled_until=1)
    app.write_json(app.STATE/"state.json",isolated)
    assert (app.STATE.stat().st_mode & 0o777) == 0o700
    assert ((app.STATE/"state.json").stat().st_mode & 0o777) == 0o600
    assert app.load_state()["paused"]


@pytest.mark.parametrize("damage", [
    lambda state: state["feet"].pop("left"),
    lambda state: state.update(paused="false"),
    lambda state: state.update(enabled_until=float("nan")),
    lambda state: state.update(enabled_until=float("inf")),
    lambda state: state["feet"]["right"].update(percent=101),
    lambda state: state["feet"]["left"].update(battery="unknown"),
    lambda state: state["feet"]["left"].update(checked_at="tomorrow"),
])
def test_corrupt_cache_fails_closed(isolated, damage):
    damage(isolated)
    app.write_json(app.STATE/"state.json", isolated)
    with pytest.raises(app.UserError, match="Controls remain paused"):
        app.load_state()


def test_missing_old_battery_timestamp_is_migrated(isolated):
    foot = isolated["feet"]["left"]
    foot.pop("battery_checked_at")
    foot.update(battery=100, checked_at=12345)
    app.write_json(app.STATE/"state.json", isolated)
    assert app.load_state()["feet"]["left"]["battery_checked_at"] == 12345


def test_lights_do_not_make_cached_battery_look_fresh(isolated):
    Link.calls = []; Link.fail_side = None
    isolated.update(paused=False, enabled_until=time.time()+1800)
    isolated["feet"]["left"].update(battery=90, battery_checked_at=12345)
    asyncio.run(app.dispatch({"action":"color", "side":"left", "color":"cyan"}, isolated,
                            profiles_loader=profiles, links=(Link, Link)))
    saved = app.read_json(app.STATE/"state.json")
    assert saved["feet"]["left"]["battery_checked_at"] == 12345
    assert saved["feet"]["left"]["checked_at"] > 12345

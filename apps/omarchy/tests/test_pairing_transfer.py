import copy
import json
import os
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).parents[1]/"backend"))
import pairing_transfer as transfer
import openadapt_session as session

FIXTURE = Path(__file__).parent/"fixtures/iphone-pairing.synthetic.json"


@pytest.fixture
def isolated(tmp_path, monkeypatch):
    monkeypatch.setattr(transfer.storage, "CONFIG", tmp_path/"config")
    monkeypatch.setattr(transfer.storage, "STATE", tmp_path/"state")
    export = tmp_path/"received.json"
    export.write_bytes(FIXTURE.read_bytes())
    export.chmod(0o644)  # Common transfer-app permissions; private copy must be 0600.
    return export


def test_swift_fixture_loads_as_identity_targets_without_inventing_calibration():
    pair = transfer.decode(FIXTURE.read_bytes())
    profiles = transfer.storage.load_profiles({"version":1, "shoes":pair["shoes"]})
    assert profiles["left"][0].address == "" and profiles["left"][0].shoe_identity == bytes([2,3,4,5,6,0])
    assert profiles["right"][0].shoe_identity == bytes([2,3,4,5,7,1])
    assert all(row[2] == 0 for row in profiles.values())


def test_import_preserves_other_pairs_and_backs_up_replaced_keys(isolated):
    original = transfer.decode(FIXTURE.read_bytes())
    other = copy.deepcopy(original); other["id"] = "unrelated"; other["extra"] = "keep me"
    source = transfer.storage.CONFIG/"profiles.private.json"
    transfer.storage.write_json(source, {"version":2, "pairs":[other, original]})
    old = transfer.storage.read_json(source)
    changed = json.loads(isolated.read_bytes())
    changed["pairs"][0]["shoes"]["left"]["key_hex"] = bytes(range(32,48)).hex()
    isolated.write_text(json.dumps(changed))
    entries, selected = transfer.import_file(isolated, old["pairs"])
    assert entries[0] == other and entries[1] != original and selected == original["id"]
    assert source.stat().st_mode & 0o777 == 0o600
    backups = list((transfer.storage.CONFIG/"backups").iterdir())
    assert len(backups) == 1 and transfer.storage.read_json(backups[0]) == old
    transfer.import_file(isolated, entries)  # Reimport is idempotent.
    assert len(list((transfer.storage.CONFIG/"backups").iterdir())) == 1


@pytest.mark.parametrize("field,value", [
    ("credential_status", "candidate"), ("key_hex", "01"*16), ("key_hex", "bad"),
    ("fit_maximum", -1), ("fit_maximum", True), ("shoe_identity", "AgMEBQYB"),
    ("shoe_identity", "bad"), ("peripheral_id", "bad"), ("profile", "unknown"),
    ("address", "02:00:00:00:00:01")])
def test_rejects_incomplete_or_invalid_exports_without_changing_storage(isolated, field, value):
    data = json.loads(isolated.read_bytes())
    data["pairs"][0]["shoes"]["left"][field] = value
    isolated.write_text(json.dumps(data))
    with pytest.raises(transfer.storage.UserError):
        transfer.import_file(isolated, [])
    assert not transfer.storage.CONFIG.exists()


def test_rejects_duplicate_fields_partial_pairs_and_oversize_files():
    data = json.loads(FIXTURE.read_bytes())
    del data["pairs"][0]["shoes"]["right"]
    for raw in [json.dumps(data).encode(), b'{"version":2,"version":2,"pairs":[]}', b" "*(transfer.LIMIT+1)]:
        with pytest.raises(transfer.storage.UserError):
            transfer.decode(raw)


def test_rejects_symlinks_and_writable_transfers(isolated):
    link = isolated.with_name("link.json"); link.symlink_to(isolated)
    with pytest.raises(OSError):
        transfer.read_export(link)
    isolated.chmod(0o666)
    with pytest.raises(transfer.storage.UserError):
        transfer.read_export(isolated)


class StatusLink:
    instances = []
    def __init__(self, target, **kwargs):
        self.calls = []; self.connected = False; self.instances.append(self)
    async def start(self, key):
        self.connected = True; self.calls.append("connect")
        return {"raw_position":30, "battery_percent":88}
    async def stop(self):
        self.connected = False
    async def execute(self, action, **kwargs):
        self.calls.append(action)
        return {"before":{"raw_position":30, "battery_percent":88}} if action == "battery" else {}


async def test_import_has_no_radio_and_new_pair_status_lights_work_but_fit_is_blocked(isolated):
    StatusLink.instances = []
    controller = session.Controller(link_factory=StatusLink)
    await controller.dispatch({"action":"import-pairing", "file_url":isolated.as_uri()})
    assert StatusLink.instances == [] and not controller.public()["connected"]
    public = json.dumps(controller.public())
    for private in ("key_hex", "shoe_identity", "peripheral_id", "004-SYNTHETIC", "AgMEBQYA"):
        assert private not in public
    await controller.dispatch({"action":"connect", "pair_id":controller.entries[0]["id"]})
    await controller.dispatch({"action":"battery"})
    await controller.dispatch({"action":"color", "side":"both", "color":"blue"})
    assert all(not foot["fit_calibrated"] for foot in controller.public()["feet"].values())
    with pytest.raises(transfer.storage.UserError, match="calibration"):
        await controller.dispatch({"action":"lace", "side":"both", "percent":60})
    assert all(link.calls == ["connect", "battery", "color"] for link in StatusLink.instances)
    with pytest.raises(transfer.storage.UserError, match="Disconnect"):
        await controller.dispatch({"action":"import-pairing", "file_url":isolated.as_uri()})
    await controller.disconnect()


async def test_import_after_failed_connection_releases_stopped_handles(isolated):
    StatusLink.instances = []
    controller = session.Controller(link_factory=StatusLink)
    stopped = StatusLink(None)
    controller.links = {"left":stopped}
    await controller.dispatch({"action":"import-pairing", "file_url":isolated.as_uri()})
    assert controller.links == {} and stopped.calls == []
    assert len(controller.entries) == 1


async def test_pair_lacing_checks_both_calibrations_before_either_command(isolated):
    StatusLink.instances = []
    controller = session.Controller(link_factory=StatusLink)
    await controller.dispatch({"action":"import-pairing", "file_url":isolated.as_uri()})
    await controller.dispatch({"action":"connect", "pair_id":controller.entries[0]["id"]})
    target, key, _ = controller.profiles["left"]
    controller.profiles["left"] = (target, key, 60)
    with pytest.raises(transfer.storage.UserError, match="calibration"):
        await controller.dispatch({"action":"lace", "side":"both", "percent":60})
    assert all(link.calls == ["connect"] for link in StatusLink.instances)
    await controller.disconnect()


@pytest.mark.parametrize("url", ["https://example.com/pair.json", "file://remote/pair.json", "file:///tmp/pair?x", "file:///tmp/%00", 1])
def test_import_accepts_only_local_file_selection(url):
    with pytest.raises(transfer.storage.UserError):
        session.validate_request({"action":"import-pairing", "file_url":url})

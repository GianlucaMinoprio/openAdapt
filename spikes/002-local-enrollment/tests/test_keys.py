import json
import os
import stat
import pytest

KEY = bytes(range(16))  # SYNTHETIC, never an owner credential.
TARGET = "synthetic-shoe"

def test_unverified_key_durable_private_storage(feature,tmp_path):
    Store = feature("keyfile", "Store")
    path = tmp_path/"vault"/"key.json"
    with Store(path) as store:
        store.save(KEY,TARGET,synthetic=True)
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    assert stat.S_IMODE(path.parent.stat().st_mode) == 0o700
    data = json.loads(path.read_text())
    assert data == {"format":1,"status":"UNVERIFIED","target":TARGET,"key_hex":KEY.hex(),"synthetic":True}

@pytest.mark.parametrize("case", ["existing","file-symlink","parent-symlink","ancestor-symlink","public-dir"])
def test_store_preflight_no_overwrite_or_symlinks(feature,tmp_path,case):
    Store = feature("keyfile", "Store")
    vault=tmp_path/"vault"; vault.mkdir(mode=0o700)
    path=vault/"key.json"
    if case=="existing": path.write_text("preserve"); path.chmod(0o600)
    if case=="file-symlink": path.symlink_to(vault/"absent")
    if case=="public-dir": vault.chmod(0o755)
    if case=="parent-symlink":
        link=tmp_path/"alias"; link.symlink_to(vault,target_is_directory=True); path=link/"key.json"
    if case=="ancestor-symlink":
        (vault/"nested").mkdir(mode=0o700)
        link=tmp_path/"alias"; link.symlink_to(vault,target_is_directory=True); path=link/"nested"/"key.json"
    with pytest.raises((OSError, ValueError)):
        with Store(path): pass
    if case=="existing": assert path.read_text()=="preserve"

def test_existing_key_read_without_auto_enroll(feature,tmp_path):
    Store=feature("keyfile","Store"); load=feature("keyfile","load")
    path=tmp_path/"vault"/"key.json"
    with Store(path) as store: store.save(KEY,TARGET,synthetic=True)
    assert load(path,TARGET,allow_synthetic=True)==KEY
    with pytest.raises(ValueError): load(path,"other",allow_synthetic=True)
    with pytest.raises(ValueError): load(path,TARGET) # cannot use fixtures live
    for value in ["", "ff", "01"*16,"0x"+KEY.hex(), " " + KEY.hex()]:
        data=json.loads(path.read_text()); data["key_hex"]=value; path.write_text(json.dumps(data))
        with pytest.raises(ValueError): load(path,TARGET,allow_synthetic=True)

def test_atomic_publish_race_preserves_key(feature,tmp_path):
    Store=feature("keyfile","Store")
    path=tmp_path/"vault"/"key.json"
    with Store(path) as store:
        path.write_text("competitor"); path.chmod(0o600)
        with pytest.raises(FileExistsError): store.save(KEY,TARGET,synthetic=True)
    assert path.read_text()=="competitor"
    pending=list(path.parent.glob(".pending-*"))
    assert len(pending)==1 and json.loads(pending[0].read_text())["status"]=="UNVERIFIED"

def test_save_rejects_invalid_key_before_storage(feature,tmp_path):
    Store=feature("keyfile","Store")
    path=tmp_path/"vault"/"key.json"
    with Store(path) as store:
        with pytest.raises(ValueError): store.save(b"bad", TARGET)
    assert not path.exists()

def test_new_vault_parent_sync_failure_stops_before_key_storage(feature,tmp_path,monkeypatch):
    Store = feature("keyfile", "Store")
    path = tmp_path / "new-vault" / "key.json"
    parent_inode = tmp_path.stat().st_ino
    original_fsync = os.fsync
    def fail_parent_sync(fd):
        info = os.fstat(fd)
        if stat.S_ISDIR(info.st_mode) and info.st_ino == parent_inode:
            raise OSError("simulated parent directory sync failure")
        return original_fsync(fd)
    monkeypatch.setattr(os, "fsync", fail_parent_sync)
    with pytest.raises(OSError, match="parent directory sync failure"):
        with Store(path) as store:
            store.save(KEY, TARGET, synthetic=True)
    assert not path.exists()
    assert not list(path.parent.glob(".pending-*"))

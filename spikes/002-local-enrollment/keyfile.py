"""Owner-only immutable application-key files; never print these records."""
import json
import os
from pathlib import Path
import secrets
import stat

class Store:
    def __init__(self, path):
        self.path = Path(path)
        if not self.path.is_absolute() or ".." in self.path.parts or self.path.name in ("", ".", ".."):
            raise ValueError("absolute key path required")
        self.fd = private_directory(self.path.parent, create=True)
        try:
            try:
                os.stat(self.path.name, dir_fd=self.fd, follow_symlinks=False)
            except FileNotFoundError:
                pass
            else:
                raise ValueError("key target already exists; preserve it")
        except BaseException:
            os.close(self.fd)
            raise

    def __enter__(self):
        return self

    def __exit__(self, *args):
        os.close(self.fd)

    def save(self, key, target, *, synthetic=False):
        validate_key(key)
        record = {"format":1, "status":"UNVERIFIED", "target":target,
                  "key_hex":key.hex(), "synthetic":synthetic}
        temporary = ".pending-" + secrets.token_hex(12)
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=self.fd)
        with os.fdopen(fd, "w") as stream:
            json.dump(record, stream)
            stream.flush()
            os.fsync(stream.fileno())
        # Publish complete bytes atomically, without replacing even a dangling symlink.
        os.link(temporary, self.path.name, src_dir_fd=self.fd, dst_dir_fd=self.fd, follow_symlinks=False)
        os.fsync(self.fd)
        os.unlink(temporary, dir_fd=self.fd)
        os.fsync(self.fd)

def private_directory(path, *, create=False):
    path = Path(path)
    if not path.is_absolute() or ".." in path.parts:
        raise ValueError("absolute protected path required")
    fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for i, part in enumerate(path.parts[1:]):
            if create and i == len(path.parts)-2:
                try:
                    os.mkdir(part, 0o700, dir_fd=fd)
                except FileExistsError:
                    pass
                # Persist the vault's directory entry before saving credentials.
                # Sync existing entries too: an earlier failed attempt may have
                # created the directory without making its parent durable.
                os.fsync(fd)
            new = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = new
        info = os.fstat(fd)
        if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
            raise ValueError("key directory must be owner-owned mode 0700")
        return fd
    except BaseException:
        os.close(fd)
        raise

def validate_key(key):
    if not isinstance(key, bytes) or len(key) != 16 or key == b"\x01"*16:
        raise ValueError("invalid existing application key; enrollment never automatic")
    return key


def load(path, target, *, allow_synthetic=False):
    import re
    path = Path(path)
    directory = private_directory(path.parent)
    try:
        fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        with os.fdopen(fd, "r") as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or stat.S_IMODE(info.st_mode) != 0o600 or info.st_uid != os.getuid() or info.st_nlink != 1 or info.st_size > 4096:
                raise ValueError("unsafe key file")
            data = json.load(stream)
        if not isinstance(data,dict) or data.get("format") != 1 or data.get("status") != "UNVERIFIED" or data.get("target") != target or type(data.get("synthetic")) is not bool:
            raise ValueError("invalid key record")
        if data["synthetic"] and not allow_synthetic:
            raise ValueError("synthetic fixture prohibited live")
        text = data.get("key_hex")
        if not isinstance(text,str) or not re.fullmatch(r"[0-9a-fA-F]{32}", text):
            raise ValueError("invalid key representation")
        return validate_key(bytes.fromhex(text))
    finally:
        os.close(directory)

"""Offline import of a saved iPhone pair. Never enrolls, connects, or copies bonds."""
import base64
import copy
import json
import os
import re
import stat
import time
import uuid

import openadapt_app as storage

LIMIT = 262144


def invalid():
    return storage.UserError("Choose an OpenAdapt pairing export containing one complete Auto Max pair.")


def identity(row, side):
    """Canonical six bytes used by iOS: five identity bytes, then the side bit."""
    try:
        raw = base64.b64decode(row["shoe_identity"], validate=True)
        if len(raw) != 6 or raw[-1] != storage.SIDES.index(side):
            raise ValueError()
        return raw
    except (KeyError, TypeError, ValueError):
        raise invalid() from None


def normalize_pair(pair):
    try:
        if (not isinstance(pair, dict) or not isinstance(pair.get("id"), str)
                or re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", pair["id"]) is None
                or not isinstance(pair.get("name"), str) or not 1 <= len(pair["name"]) <= 60
                or any(ord(c) < 32 for c in pair["name"])
                or not isinstance(pair.get("shoes"), dict) or set(pair["shoes"]) != set(storage.SIDES)):
            raise invalid()
        shoes = {}
        for side, row in pair["shoes"].items():
            if (not isinstance(row, dict) or row.get("profile") != "auto-max-2.4.3M"
                    or row.get("credential_status") != "hardware-verified"
                    or not isinstance(row.get("advertised_name"), str)
                    or not re.fullmatch(r"004-[A-Z0-9]+-[0-9]{3}", row["advertised_name"])
                    or not isinstance(row.get("key_hex"), str)
                    or not re.fullmatch(r"[0-9a-fA-F]{32}", row["key_hex"])
                    or bytes.fromhex(row["key_hex"]) == bytes([1])*16
                    or type(row.get("fit_maximum")) is not int):
                raise invalid()
            clean = {k: row[k] for k in ("profile", "credential_status", "advertised_name", "key_hex", "fit_maximum")}
            clean["key_hex"] = clean["key_hex"].lower()
            if row.get("shoe_identity") is not None:
                raw = identity(row, side)
                if row.get("address", "") != "" or not 0 <= row["fit_maximum"] <= 100:
                    raise invalid()
                # Retain the source's UUID for round trips; Linux never treats it as an address.
                clean.update(address="", shoe_identity=base64.b64encode(raw).decode())
                clean["peripheral_id"] = str(uuid.UUID(row["peripheral_id"]))
            else:
                if (not isinstance(row.get("address"), str)
                        or not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", row["address"])
                        or not 1 <= row["fit_maximum"] <= 100 or row.get("peripheral_id") is not None):
                    raise invalid()
                clean["address"] = row["address"].upper()
            shoes[side] = clean
        left, right = shoes["left"], shoes["right"]
        if left["key_hex"] == right["key_hex"] or ("shoe_identity" in left) != ("shoe_identity" in right):
            raise invalid()
        if "shoe_identity" in left:
            if left["peripheral_id"] == right["peripheral_id"]:
                raise invalid()
        elif left["address"] == right["address"]:
            raise invalid()
        return {"id": pair["id"], "name": pair["name"], "shoes": shoes}
    except (KeyError, TypeError, ValueError, AttributeError):
        raise invalid() from None


def decode(data):
    try:
        if len(data) > LIMIT:
            raise invalid()
        def unique_fields(items):
            result = {}
            for key, value in items:
                if key in result:
                    raise invalid()
                result[key] = value
            return result
        value = json.loads(data, object_pairs_hook=unique_fields)
        if (not isinstance(value, dict) or type(value.get("version")) is not int
                or value["version"] != 2 or not isinstance(value.get("pairs"), list)
                or len(value["pairs"]) != 1):
            raise invalid()
        return normalize_pair(value["pairs"][0])
    except (ValueError, TypeError, UnicodeError):
        raise invalid() from None


def read_export(path):
    # Files saved by a transfer app may be 0644; explicit import copies them into
    # private storage. Reject links, special files, foreign ownership and writers.
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as stream:
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid()
                or info.st_nlink != 1 or info.st_mode & 0o022 or info.st_size > LIMIT):
            raise invalid()
        return decode(stream.read(LIMIT + 1))


def import_file(path, existing):
    """Call only under the controller's process lock, with all links stopped."""
    pair = read_export(path)
    result = copy.deepcopy(existing)
    index = next((i for i, row in enumerate(result) if row["id"] == pair["id"]), None)
    if index is not None:
        if result[index] == pair:
            return result, pair["id"]
        result[index] = pair
    else:
        if len(result) >= 20:
            raise storage.UserError("The saved list is full. Keep at most 20 pairs.")
        result.insert(0, pair)
    # Back up the entire old catalog, including unknown metadata, before replacing it.
    destination = storage.CONFIG/"profiles.private.json"
    try:
        previous = storage.read_json(destination)
    except FileNotFoundError:
        previous = None
    if previous is not None:
        backup = storage.CONFIG/"backups"/(str(time.time_ns()) + "-profiles.private.json")
        storage.write_json(backup, previous)
    storage.write_json(destination, {"version": 2, "pairs": result})
    return result, pair["id"]

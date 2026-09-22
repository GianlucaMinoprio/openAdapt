"""Local fit modes and connection history. Never contains pairing credentials."""
import copy
import re
import uuid

import openadapt_app as storage


def valid_id(value):
    return isinstance(value, str) and re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", value)


def mode_name(value):
    if not isinstance(value, str) or not 1 <= len(value.strip()) <= 40 or any(ord(c) < 32 for c in value):
        raise storage.UserError("Choose a fit name between 1 and 40 characters.")
    return value.strip()


def defaults():
    return {"modes": [{"id":"move", "name":"Move", "left":60, "right":60},
                      {"id":"chill", "name":"Chill", "left":30, "right":30}], "last_mode":None}


class Preferences:
    def __init__(self, pair_ids):
        self.path = storage.STATE / "panel-preferences.json"
        try:
            data = storage.read_json(self.path)
        except FileNotFoundError:
            data = {"version":1, "preferred_pair":None, "pairs":{}}
        if (not isinstance(data, dict) or data.get("version") != 1
                or not isinstance(data.get("pairs"), dict)
                or (data.get("preferred_pair") is not None and not valid_id(data["preferred_pair"]))):
            raise storage.UserError("Saved fit preferences could not be read.")
        for ident, row in data["pairs"].items():
            if (not valid_id(ident) or not isinstance(row, dict) or not isinstance(row.get("modes"), list)
                    or len(row["modes"]) > 20):
                raise storage.UserError("Saved fits could not be read.")
            seen = set()
            for mode in row["modes"]:
                if (not isinstance(mode, dict) or not valid_id(mode.get("id")) or mode["id"] in seen
                        or any(type(mode.get(s)) is not int or not 0 <= mode[s] <= 100 or mode[s] % 5 for s in storage.SIDES)):
                    raise storage.UserError("Saved fits could not be read.")
                mode_name(mode.get("name"))
                seen.add(mode["id"])
            if row.get("last_mode") not in seen:
                row["last_mode"] = None
        self.data = data
        self.data["pairs"] = {k:v for k,v in data["pairs"].items() if k in pair_ids}
        if self.data.get("preferred_pair") not in pair_ids:
            self.data["preferred_pair"] = None

    def save(self):
        storage.write_json(self.path, self.data)

    @property
    def preferred_pair(self):
        return self.data.get("preferred_pair")

    def row(self, pair_id):
        return self.data["pairs"].setdefault(pair_id, defaults())

    def public(self, pair_id):
        row = self.row(pair_id)
        tie_id = row["last_mode"] or (row["modes"][0]["id"] if row["modes"] else None)
        return {"modes":copy.deepcopy(row["modes"]), "tie_mode_id":tie_id}

    def find(self, pair_id, mode_id):
        mode = next((m for m in self.row(pair_id)["modes"] if m["id"] == mode_id), None)
        if mode is None:
            raise storage.UserError("That saved fit is no longer available.")
        return mode

    def add(self, pair_id, name, feet):
        row = self.row(pair_id)
        if len(row["modes"]) >= 20:
            raise storage.UserError("You can save up to 20 fits per pair.")
        row["modes"].append({"id":uuid.uuid4().hex, "name":mode_name(name),
                             **{s:feet[s]["percent"] for s in storage.SIDES}})
        self.save()

    def rename(self, pair_id, mode_id, name):
        self.find(pair_id, mode_id)["name"] = mode_name(name)
        self.save()

    def remove(self, pair_id, mode_id):
        self.find(pair_id, mode_id)
        row = self.row(pair_id)
        row["modes"] = [m for m in row["modes"] if m["id"] != mode_id]
        if row["last_mode"] == mode_id:
            row["last_mode"] = None
        self.save()

    def remember_pair(self, pair_id):
        self.data["preferred_pair"] = pair_id
        self.save()

    def remember_mode(self, pair_id, mode_id):
        self.find(pair_id, mode_id)
        self.row(pair_id)["last_mode"] = mode_id
        self.save()

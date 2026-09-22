"""Local JSON command bridge for the native Omarchy panel.

Loading cached state never imports Bluetooth libraries or touches the radio.
Live commands require a current owner-enabled, empty-shoe testing session.
"""
import argparse
import asyncio
import contextlib
import fcntl
import json
import math
import os
from pathlib import Path
import signal
import stat
import sys
import tempfile
import time
import traceback

PROJECT = Path(__file__).resolve().parents[3]
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home()/".config"))/"openadapt"
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home()/".local/state"))/"openadapt"
SIDES = ("left", "right")
COLORS = {
    "cyan": (0, 255, 255), "sky": (0, 60, 255), "blue": (0, 0, 255),
    "purple": (100, 0, 200), "pink": (255, 10, 80), "red": (240, 0, 8),
    "coral": (255, 16, 3), "orange": (255, 40, 0), "yellow": (255, 255, 0),
    "lime": (120, 240, 0), "green": (20, 240, 0), "white": (255, 255, 255),
}


class UserError(Exception):
    pass


def secure_dir(path):
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise UserError("OpenAdapt's private storage permissions need attention.")


def read_json(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd) as stream:
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid()
                or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1 or info.st_size > 262144):
            raise UserError("OpenAdapt's private file permissions need attention.")
        return json.load(stream)


def write_json(path, value):
    secure_dir(path.parent)
    fd, temporary = tempfile.mkstemp(prefix=".openadapt-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def blank_state():
    return {"version": 1, "paused": True, "enabled_until": 0, "pair_name": "Auto Max",
            "last_action": "Ready when you are", "feet": {s:{"percent":0, "battery":None,
            "color":None, "lights":"unknown", "checked_at":None,
            "battery_checked_at":None, "status":"saved"} for s in SIDES}}


def valid_number(value):
    return type(value) in (int, float) and math.isfinite(value) and value >= 0


def validate_state(value):
    valid = (isinstance(value, dict) and type(value.get("version")) is int
             and value["version"] == 1 and type(value.get("paused")) is bool
             and valid_number(value.get("enabled_until"))
             and isinstance(value.get("last_action", ""), str)
             and isinstance(value.get("feet"), dict) and set(value["feet"]) == set(SIDES))
    if valid:
        for side in SIDES:
            foot = value["feet"].get(side)
            if not isinstance(foot, dict):
                valid = False
                break
            percent, battery = foot.get("percent"), foot.get("battery")
            valid = (type(percent) is int and 0 <= percent <= 100 and percent % 5 == 0
                     and (battery is None or type(battery) is int and 0 <= battery <= 100)
                     and foot.get("color") in (None, *COLORS)
                     and foot.get("lights") in ("unknown", "color-set", "off")
                     and foot.get("status") in ("saved", "verified", "check-shoe"))
            for timestamp in ("checked_at", "battery_checked_at"):
                valid = valid and (foot.get(timestamp) is None or valid_number(foot[timestamp]))
            if not valid:
                break
    if not valid:
        raise UserError("OpenAdapt's saved state could not be read. Controls remain paused.")
    # Migrate the original status-only cache once. Light commands then preserve
    # the time of the actual battery reading instead of making it look fresh.
    for foot in value["feet"].values():
        foot.setdefault("battery_checked_at", foot.get("checked_at"))
    return value


def load_state():
    try:
        value = read_json(STATE/"state.json")
    except FileNotFoundError:
        value = blank_state()
    validate_state(value)
    if value.get("enabled_until", 0) <= time.time():
        value["paused"] = True
    return value


def public_state(state):
    # An explicit projection prevents profile IDs, addresses or keys reaching QML.
    return {"version":1, "paused":bool(state["paused"]),
            "pair_name":"Auto Max", "last_action":state.get("last_action", ""),
            "profile_available": (CONFIG/"profiles.private.json").is_file(),
            "fresh_pairing_supported":False,
            "feet":{s:{k:state["feet"][s].get(k) for k in
                ("percent", "battery", "color", "lights", "checked_at", "battery_checked_at", "status")} for s in SIDES}}


def load_profiles(data=None):
    if data is None:
        secure_dir(CONFIG)
        data = read_json(CONFIG/"profiles.private.json")
    if data.get("version") != 1 or set(data.get("shoes", {})) != set(SIDES):
        raise UserError("The saved shoe profile is incomplete.")
    sys.path.insert(0, str(PROJECT/"spikes/002-local-enrollment"))
    from ble_link import OwnedTarget
    from keyfile import validate_key
    from control_wire import relative_target
    result = {}
    for side in SIDES:
        row = data["shoes"][side]
        if row.get("profile") != "auto-max-2.4.3M" or row.get("credential_status") != "hardware-verified":
            raise UserError("This shoe profile has not been verified for live control.")
        native_identity = None
        if row.get("shoe_identity") is not None:
            from pairing_transfer import identity
            native_identity = identity(row, side)
        target = OwnedTarget(row["address"], row["advertised_name"], True, native_identity)
        if not target.advertised_name.startswith("004-"):
            raise UserError("This version supports the verified Auto Max pair.")
        key = validate_key(bytes.fromhex(row["key_hex"]))
        maximum = row["fit_maximum"]
        if not (native_identity is not None and type(maximum) is int and maximum == 0):
            relative_target(100, maximum)
        result[side] = (target, key, maximum)
    left, right = result["left"][0], result["right"][0]
    if (left.shoe_identity is None) != (right.shoe_identity is None):
        raise UserError("The two shoe profiles use different identity formats.")
    if left.shoe_identity is None and left.address.upper() == right.address.upper():
        raise UserError("The two shoe profiles refer to the same shoe.")
    return result


def validate_command(command):
    if not isinstance(command, dict):
        raise UserError("Invalid control request.")
    action = command.get("action")
    allowed = {"cache":set(), "pause":set(), "resume":{"empty_shoes","nike_closed"},
               "battery":set(), "connect":set(), "lace":{"side","percent"},
               "color":{"side","color"}, "lights-off":set()}
    if not isinstance(action, str) or action not in allowed or set(command) != allowed[action] | {"action"}:
        raise UserError("Unsupported control request.")
    if action in ("lace", "color") and command["side"] not in (*SIDES, "both"):
        raise UserError("Select left, right, or both shoes.")
    if action == "lace":
        percent = command["percent"]
        if type(percent) is not int or not 0 <= percent <= 100 or percent % 5:
            raise UserError("Lacing must be 0–100 in steps of 5.")
    if action == "color" and (not isinstance(command["color"], str) or command["color"] not in COLORS):
        raise UserError("Select a color from the palette.")
    if action == "resume" and (command["empty_shoes"] is not True or command["nike_closed"] is not True):
        raise UserError("Confirm empty shoes and close Nike Adapt before live testing.")
    return action


def friendly_error(error):
    if isinstance(error, UserError):
        return str(error)
    if isinstance(error, FileNotFoundError):
        return "Saved shoe credentials are missing. Open Pair shoes for setup details."
    if isinstance(error, LookupError):
        return "Shoe not found. Wake it normally, keep it nearby, then try again."
    if isinstance(error, TimeoutError):
        return "The shoe did not finish in time. Check it before trying again."
    if isinstance(error, PermissionError):
        return "Disconnect other shoe apps and pair both shoes in Omarchy’s Bluetooth settings, then try again."
    if isinstance(error, asyncio.CancelledError):
        return "Operation stopped. Check the shoe before trying again."
    if isinstance(error, ConnectionError):
        return "The shoe disconnected. No command was retried."
    return "The shoe response could not be verified. No command was retried."


async def hardware(command, state, *, profiles_loader=load_profiles, links=None):
    if state["paused"] or state.get("enabled_until", 0) <= time.time():
        raise UserError("Controls are paused. Enable live testing when you are ready.")
    profiles = profiles_loader()
    if links is None:
        from control import AutoMaxControlLink
        from lights import AutoMaxLightLink
        links = (AutoMaxControlLink, AutoMaxLightLink)
    action = command["action"]
    selected = command.get("side", "both")
    sides = SIDES if selected == "both" else (selected,)
    if action == "lace" and any(profiles[side][2] <= 0 for side in sides):
        raise UserError("Fit calibration is not available for this pair. Use the shoe buttons for now.")
    completed = []
    for side in sides:
        if state.get("enabled_until",0) <= time.time():
            raise UserError("Live testing paused after 30 minutes. Enable it again when ready.")
        target, key, maximum = profiles[side]
        foot = state["feet"][side]
        link = links[1 if action in ("color", "lights-off") else 0](target)
        try:
            if action in ("connect", "battery"):
                result = await link.read_status(key)
                current = result["before"]
                foot.update(percent=max(0,min(100,round(current["raw_position"]/maximum*20)*5)) if maximum else 0,
                            battery=current["battery_percent"], raw_position=current["raw_position"],
                            battery_checked_at=int(time.time()))
            elif action == "lace":
                result = await link.set_position(key, percent=command["percent"], fit_maximum=maximum,
                                                 empty_shoe_confirmed=True)
                foot.update(percent=command["percent"], raw_position=result["after_raw_position"],
                            battery=result["before"]["battery_percent"], battery_checked_at=int(time.time()))
            elif action == "color":
                await link.set_color(key, COLORS[command["color"]])
                foot.update(color=command["color"], lights="color-set")
            elif action == "lights-off":
                await link.lights_off(key)
                foot["lights"] = "off"
            foot.update(checked_at=int(time.time()), status="verified")
            completed.append(side)
            state["last_action"] = f"{side.capitalize()} updated"
            write_json(STATE/"state.json", state)
        except BaseException:
            foot["status"] = "check-shoe"
            if completed:
                state["last_action"] = f"{completed[0].capitalize()} updated; check {side}"
            else:
                state["last_action"] = f"Check the {side} shoe"
            write_json(STATE/"state.json", state)
            raise
    labels = {"connect":"Saved pair verified", "battery":"Battery checked", "lace":"Lacing updated",
              "color":"Color preview sent", "lights-off":"Lights off"}
    state["last_action"] = labels[action]
    return state


async def dispatch(command, state, **kwargs):
    action = validate_command(command)
    if action == "cache":
        return state
    if action == "pause":
        state.update(paused=True, enabled_until=0, last_action="Controls paused")
    elif action == "resume":
        # This action changes only the local gate. It never connects to shoes.
        state.update(paused=False, enabled_until=time.time()+1800, last_action="Live testing enabled")
    else:
        await hardware(command, state, **kwargs)
    write_json(STATE/"state.json", state)
    return state


async def run(command, state):
    loop, task = asyncio.get_running_loop(), asyncio.current_task()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, task.cancel)
    try:
        return await dispatch(command, state)
    finally:
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.remove_signal_handler(sig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("request", help="A JSON request without credentials")
    args = parser.parse_args()
    os.umask(0o077)
    state = blank_state()
    lock = None
    try:
        if len(args.request) > 2048:
            raise UserError("Control request is too large.")
        command = json.loads(args.request)
        action = validate_command(command)
        secure_dir(STATE)
        state = load_state()
        if action != "cache":
            lock = os.open(STATE/"operation.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise UserError("A shoe operation is already running. Please wait for it to finish.")
            # Re-read after acquiring the lock so an expired/paused gate cannot
            # be replaced by a stale concurrent snapshot.
            state = load_state()
        with (STATE/"backend.private.log").open("a") as log:
            with contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
                try:
                    state = asyncio.run(run(command, state))
                except BaseException:
                    traceback.print_exc(file=log)
                    raise
        reply = {"ok":True, "state":public_state(state)}
    except (Exception, asyncio.CancelledError) as error:
        reply = {"ok":False, "message":friendly_error(error), "state":public_state(state)}
    finally:
        if lock is not None:
            os.close(lock)
    print(json.dumps(reply), flush=True)


if __name__ == "__main__":
    main()

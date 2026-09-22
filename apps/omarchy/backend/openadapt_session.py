#!/usr/bin/env python3
"""Native panel's persistent local session. No radio access until Connect.

Stdin/stdout carry JSON lines without credentials. Closing stdin or receiving
SIGTERM cancels the active action and disconnects only this process's links.
"""
import asyncio
import contextlib
import copy
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import sys
import time
import traceback
from urllib.parse import unquote, urlsplit

import openadapt_app as storage
from panel_preferences import Preferences, mode_name, valid_id

LEGACY_ID = "auto-max"
PUBLIC_FOOT = ("percent", "battery", "color", "lights", "checked_at", "battery_checked_at", "status")


def catalog():
    try:
        data = storage.read_json(storage.CONFIG/"profiles.private.json")
    except FileNotFoundError:
        return []
    if data.get("version") == 1:
        entries = [{"id":LEGACY_ID, "name":"Auto Max", "shoes":data.get("shoes", {})}]
    elif data.get("version") == 2 and isinstance(data.get("pairs"), list):
        entries = data["pairs"]
    else:
        raise storage.UserError("The saved shoe list could not be read.")
    seen = set()
    for pair in entries:
        if (not isinstance(pair, dict) or not isinstance(pair.get("id"), str)
                or not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", pair["id"])
                or pair["id"] in seen or not isinstance(pair.get("name"), str)
                or not 1 <= len(pair["name"]) <= 60 or not isinstance(pair.get("shoes"), dict)):
            raise storage.UserError("The saved shoe list is incomplete.")
        seen.add(pair["id"])
    return entries


def connectable(pair):
    shoes = pair["shoes"]
    return set(shoes) == set(storage.SIDES) and all(
        isinstance(row, dict) and row.get("profile") == "auto-max-2.4.3M"
        and row.get("credential_status") == "hardware-verified" for row in shoes.values())


def validate_request(request):
    allowed = {"status":set(), "panel-open":set(), "connect":{"pair_id"}, "disconnect":set(), "battery":set(),
               "lace":{"side", "percent"}, "color":{"side", "color"}, "lights-off":set(),
               "import-pairing":{"file_url"}, "tie":set(), "untie":set(),
               "mode-save":{"name"}, "mode-rename":{"mode_id", "name"},
               "mode-remove":{"mode_id"}, "mode-apply":{"mode_id"}}
    if not isinstance(request, dict) or not isinstance(request.get("action"), str):
        raise storage.UserError("Invalid control request.")
    action = request["action"]
    if action not in allowed or set(request) != allowed[action] | {"action"}:
        raise storage.UserError("Unsupported control request.")
    if action in ("lace", "color"):
        storage.validate_command(request)
    if action == "connect" and (not isinstance(request["pair_id"], str)
                               or not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", request["pair_id"])):
        raise storage.UserError("Choose a saved pair.")
    if action == "import-pairing":
        export_path(request["file_url"])
    if "mode_id" in request and not valid_id(request["mode_id"]):
        raise storage.UserError("Choose a saved fit.")
    if "name" in request:
        mode_name(request["name"])
    return action


def export_path(value):
    if not isinstance(value, str) or len(value) > 4096:
        raise storage.UserError("Choose a local pairing file.")
    try:
        url = urlsplit(value)
        path = unquote(url.path)
        if (url.scheme != "file" or url.netloc not in ("", "localhost") or url.query or url.fragment
                or not path.startswith("/") or "\x00" in path):
            raise ValueError()
        return Path(path)
    except ValueError:
        raise storage.UserError("Choose a local pairing file.") from None


async def together(actions):
    """Settle each shoe independently; drain all children before ending an action."""
    tasks = [asyncio.create_task(action) for action in actions]
    try:
        return await asyncio.gather(*tasks, return_exceptions=True)
    finally:
        for task in tasks:
            if not task.done():
                task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)


class Controller:
    def __init__(self, *, entries=None, link_factory=None, emit=None, trace=None):
        self.entries = catalog() if entries is None else entries
        self.link_factory = link_factory
        self.emit = emit or (lambda *_: None)
        self.trace = trace or (lambda *_: None)
        self.selected = None
        self.links = {}
        self.profiles = {}
        self.feet = {}
        self.connections = {s:"disconnected" for s in storage.SIDES}
        self.operation = ""
        self.message = ""
        self.failed = False
        self.stopping = False
        self.cache = self.load_cache()
        self.preferences = Preferences([p["id"] for p in self.entries])
        self.operation_id = 0
        self.link_epochs = {s:0 for s in storage.SIDES}
        self.movement = {}
        self.restore_selection()

    def restore_selection(self):
        self.selected = next((p for p in self.entries if p["id"] == self.preferences.preferred_pair),
                             self.entries[0] if self.entries else None)
        self.feet = copy.deepcopy(self.cache.get(self.selected["id"], storage.blank_state()["feet"])) if self.selected else {}

    def load_cache(self):
        try:
            cache = storage.read_json(storage.STATE/"readings.json")
            if cache.get("version") != 2 or not isinstance(cache.get("pairs"), dict):
                raise storage.UserError("Saved readings could not be read.")
            for feet in cache["pairs"].values():
                candidate = storage.blank_state(); candidate["feet"] = feet
                storage.validate_state(candidate)
            return cache["pairs"]
        except FileNotFoundError:
            # Copy only readings from the original V0 cache. Never restore its
            # preview, live gate or any remembered connection as a live link.
            return {LEGACY_ID:copy.deepcopy(storage.load_state()["feet"])}

    def persist(self):
        if self.selected:
            self.cache[self.selected["id"]] = copy.deepcopy(self.feet)
            storage.write_json(storage.STATE/"readings.json", {"version":2, "pairs":self.cache})

    def public(self):
        connected = {side:bool(self.links.get(side) and self.links[side].connected) for side in storage.SIDES}
        selected_id = self.selected["id"] if self.selected else None
        feet = self.feet or storage.blank_state()["feet"]
        return {"saved_pairs":[{"id":pair["id"], "name":pair["name"], "connectable":connectable(pair),
                                "selected":pair["id"] == selected_id} for pair in self.entries],
                "selected_id":selected_id, "pair_name":self.selected["name"] if self.selected else "",
                "connected":any(connected.values()), "busy":bool(self.operation), "operation":self.operation,
                "operation_id":self.operation_id, "preferred_pair_id":self.preferences.preferred_pair,
                **(self.preferences.public(selected_id) if selected_id else {"modes":[], "tie_mode_id":None}),
                "message":self.message, "failed":self.failed, "new_pairing_available":False,
                "feet":{s:{**{k:feet[s].get(k) for k in PUBLIC_FOOT}, "connected":connected[s],
                           "fit_calibrated":bool(self.profiles.get(s) and self.profiles[s][2] > 0),
                           "movement":copy.deepcopy(self.movement.get(s)),
                           "connection":"connected" if connected[s] else self.connections[s]} for s in storage.SIDES}}

    def publish(self):
        self.emit(self.public())

    def changed(self, side, event, value, epoch=None):
        if epoch is not None and epoch != self.link_epochs[side]:
            return
        if event == "position" and side in self.profiles:
            self.feet[side]["percent"] = self.percent(value["raw_position"], self.profiles[side][2])
            self.feet[side]["raw_position"] = value["raw_position"]
            self.persist()
        elif event == "moving" and side in self.movement:
            move = self.movement[side]
            if move["operation_id"] != self.operation_id or move["phase"] != "queued":
                return
            self.status_read(side, value)
            move.update(phase="moving", start=self.feet[side]["percent"], started_at=time.time())
        elif event == "disconnected":
            self.connections[side] = "disconnected"
            if side in self.movement and self.movement[side]["phase"] in ("queued", "moving"):
                self.movement[side]["phase"] = "unconfirmed"
            if not self.stopping and self.operation != "connect":
                self.message = f"{side.capitalize()} shoe disconnected."
        self.publish()

    @staticmethod
    def percent(raw, maximum):
        return max(0, min(100, round(raw/maximum*20)*5)) if maximum > 0 else 0

    def status_read(self, side, result):
        self.feet[side].update(percent=self.percent(result["raw_position"], self.profiles[side][2]),
                               raw_position=result["raw_position"], battery=result["battery_percent"],
                               checked_at=int(time.time()), battery_checked_at=int(time.time()), status="verified")
        self.persist()

    async def connect(self, pair_id):
        pair = next((row for row in self.entries if row["id"] == pair_id), None)
        if pair is None or not connectable(pair):
            raise storage.UserError("This saved pair is not ready for connection yet.")
        if self.selected and self.selected["id"] != pair_id:
            await self.disconnect()
            self.feet = {}
        self.selected = pair
        self.movement = {}
        self.profiles = storage.load_profiles({"version":1, "shoes":pair["shoes"]})
        if not self.feet:
            self.feet = copy.deepcopy(self.cache.get(pair_id, storage.blank_state()["feet"]))
        pending = [s for s in storage.SIDES if not (self.links.get(s) and self.links[s].connected)]
        discovery = None
        factory = self.link_factory
        if factory is None:
            from live import AutoMaxLiveLink
            from ble_link import SharedShoeDiscovery
            if pending:
                discovery = SharedShoeDiscovery([self.profiles[s][0] for s in pending])
            factory = lambda target, **kwargs: AutoMaxLiveLink(target, discovery=discovery, **kwargs)
        operation_id = self.operation_id
        for side in pending:
            self.connections[side] = "connecting"
        self.message = "Connecting shoes…"
        self.publish()

        async def connect_side(side):
            link = None
            try:
                self.link_epochs[side] += 1
                if self.links.get(side):
                    await self.links[side].stop()
                target, key, _ = self.profiles[side]
                link = factory(target, on_change=lambda event,value,s=side,e=self.link_epochs[side]:self.changed(s,event,value,e),
                               trace=lambda direction,packet,s=side:self.trace(s,direction,packet))
                self.links[side] = link
                result = await link.start(key)
                self.check_operation(operation_id, side, link)
                self.status_read(side, result)
                self.connections[side] = "connected"
                self.publish()
            except BaseException as error:
                if operation_id == self.operation_id:
                    self.connections[side] = "disconnected"
                self.trace(side, "error", type(error).__name__)
                if link is not None:
                    await link.stop()
                self.publish()
                raise

        try:
            results = await together(connect_side(s) for s in pending)
        finally:
            if discovery is not None:
                await discovery.close()
        errors = [f"{s.capitalize()}: {storage.friendly_error(r)}" for s,r in zip(pending, results) if isinstance(r, Exception)]
        for result in results:
            if isinstance(result, asyncio.CancelledError):
                raise result
        if operation_id != self.operation_id:
            raise asyncio.CancelledError()
        count = sum(link.connected for link in self.links.values())
        self.message = "Both shoes connected" if count == 2 else " ".join(errors)
        self.failed = bool(errors)
        if count == 2 and not errors:
            self.preferences.remember_pair(pair_id)

    async def disconnect(self):
        self.stopping = True
        self.operation_id += 1
        self.link_epochs = {s:self.link_epochs[s]+1 for s in storage.SIDES}
        self.movement = {}
        try:
            results = await together(link.stop() for link in self.links.values())
            for result in results:
                if isinstance(result, BaseException):
                    raise result
        finally:
            self.links.clear()
            self.connections = {s:"disconnected" for s in storage.SIDES}
            self.profiles = {}
            self.stopping = False
        self.message = "Disconnected"

    def require_ready(self, sides, *, fit=False):
        if not self.selected or any(not self.links.get(s) or not self.links[s].connected for s in sides):
            raise storage.UserError("Connect both shoes first." if len(sides) == 2 else "Connect your shoes first.")
        if fit and any(self.profiles[s][2] <= 0 for s in sides):
            raise storage.UserError("Fit calibration is not available for this pair. Use the shoe buttons for now.")

    def check_operation(self, operation_id, side, link):
        if operation_id != self.operation_id or self.links.get(side) is not link or not link.connected:
            raise storage.UserError("The connection changed. Check your shoes before trying again.")

    async def fit(self, targets):
        self.require_ready(targets, fit=True)
        operation_id = self.operation_id
        self.movement = {s:{"operation_id":operation_id, "phase":"queued", "start":self.feet[s]["percent"],
                            "target":target, "started_at":None} for s,target in targets.items()}
        self.publish()
        completed = []
        links = {s:self.links[s] for s in targets}
        maxima = {s:self.profiles[s][2] for s in targets}

        async def move_side(side, target):
            link = links[side]
            try:
                result = await link.execute("lace", percent=target, maximum=maxima[side])
                self.check_operation(operation_id, side, link)
                self.status_read(side, result["before"])
                raw = result["after_raw_position"]
                self.feet[side].update(percent=self.percent(raw, maxima[side]), raw_position=raw, status="verified")
                self.movement[side]["phase"] = "confirmed"
                completed.append(side)
                self.persist()
                self.publish()
            except BaseException:
                if operation_id == self.operation_id:
                    self.movement[side]["phase"] = "unconfirmed"
                    self.feet[side]["status"] = "check-shoe"
                    self.persist()
                    self.publish()
                raise

        results = await together(move_side(s, target) for s,target in targets.items())
        for result in results:
            if isinstance(result, asyncio.CancelledError):
                raise result
        errors = [r for r in results if isinstance(r, Exception)]
        if errors:
            if completed:
                raise storage.UserError(f"{completed[0].capitalize()} shoe updated; the other fit is unconfirmed. Check your shoes before trying again.") from errors[0]
            raise errors[0]
        self.message = "Fit updated"

    async def mode_action(self, request):
        if not self.selected:
            raise storage.UserError("Choose your shoes first.")
        pair_id = self.selected["id"]
        action = request["action"]
        if action == "mode-save":
            self.require_ready(storage.SIDES, fit=True)
            if any(self.feet[s].get("status") != "verified" for s in storage.SIDES):
                raise storage.UserError("Refresh your shoes before saving this fit.")
            self.preferences.add(pair_id, request["name"], self.feet)
            self.message = "Fit saved"
        elif action == "mode-rename":
            self.preferences.rename(pair_id, request["mode_id"], request["name"])
            self.message = "Fit renamed"
        elif action == "mode-remove":
            self.preferences.remove(pair_id, request["mode_id"])
            self.message = "Fit removed"
        elif action == "untie":
            await self.fit({s:0 for s in storage.SIDES})
            self.message = "Shoes untied"
        else:
            mode_id = request.get("mode_id") if action == "mode-apply" else self.preferences.public(pair_id)["tie_mode_id"]
            if mode_id is None:
                raise storage.UserError("Save a fit in Modes before using Tie.")
            mode = self.preferences.find(pair_id, mode_id)
            await self.fit({s:mode[s] for s in storage.SIDES})
            self.preferences.remember_mode(pair_id, mode_id)
            self.message = "Fit applied"

    async def control(self, request):
        selected = request.get("side", "both")
        if request["action"] == "battery":
            sides = tuple(s for s in storage.SIDES if self.links.get(s) and self.links[s].connected)
        else:
            sides = storage.SIDES if selected == "both" else (selected,)
        if not sides:
            raise storage.UserError("Connect your shoes first.")
        self.require_ready(sides)
        if request["action"] == "lace":
            await self.fit({s:request["percent"] for s in sides})
            return
        completed = []
        operation_id = self.operation_id
        links = {s:self.links[s] for s in sides}

        async def control_side(side):
            foot = self.feet[side]
            kwargs = {"color":storage.COLORS[request["color"]]} if request["action"] == "color" else {}
            try:
                result = await links[side].execute(request["action"], **kwargs)
                self.check_operation(operation_id, side, links[side])
                if "before" in result:
                    self.status_read(side, result["before"])
                if request["action"] == "color":
                    foot.update(color=request["color"], lights="color-set")
                elif request["action"] == "lights-off":
                    foot["lights"] = "off"
                foot.update(checked_at=int(time.time()), status="verified")
                self.persist()
                completed.append(side)
                self.publish()
            except BaseException:
                if operation_id == self.operation_id:
                    foot["status"] = "check-shoe"
                    self.persist()
                    self.publish()
                raise
        results = await together(control_side(s) for s in sides)
        for result in results:
            if isinstance(result, asyncio.CancelledError):
                raise result
        errors = [r for r in results if isinstance(r, Exception)]
        if errors:
            if completed:
                raise storage.UserError(f"{completed[0].capitalize()} shoe updated; the other shoe did not confirm. Try again when both are connected.") from errors[0]
            raise errors[0]
        self.message = {"color":"Color updated",
                        "battery":"Battery checked", "lights-off":"Lights off"}[request["action"]]

    async def dispatch(self, request):
        action = validate_request(request)
        if action in ("status", "panel-open"):
            if action == "panel-open" and not self.operation and not any(link.connected for link in self.links.values()):
                self.link_epochs = {s:self.link_epochs[s]+1 for s in storage.SIDES}
                self.profiles = {}
                self.movement = {}
                self.restore_selection()
                self.message = ""
                self.failed = False
            self.publish()
            return
        if self.operation:
            raise storage.UserError("An operation is already running.")
        self.operation = action
        self.operation_id += 1
        self.failed = False
        self.message = "Working…"
        self.publish()
        try:
            if action == "connect":
                await self.connect(request["pair_id"])
            elif action == "disconnect":
                await self.disconnect()
            elif action == "import-pairing":
                if any(link.connected for link in self.links.values()):
                    raise storage.UserError("Disconnect your shoes before importing a pairing.")
                if self.links:
                    # Failed attempts leave stopped handles behind. Release those
                    # without asking for an inaccessible Disconnect button.
                    await self.disconnect()
                from pairing_transfer import import_file
                entries, imported_id = import_file(export_path(request["file_url"]), catalog())
                self.entries = entries
                self.profiles = {}
                self.movement = {}
                # Never reuse an old reading/calibration after credentials are replaced.
                self.cache.pop(imported_id, None)
                storage.write_json(storage.STATE/"readings.json", {"version":2, "pairs":self.cache})
                self.restore_selection()
                self.message = "Pairing imported. Wake both shoes, disconnect your iPhone, then choose Connect."
            elif action.startswith("mode-") or action in ("tie", "untie"):
                await self.mode_action(request)
            else:
                await self.control(request)
        except (Exception, asyncio.CancelledError) as error:
            self.failed = True
            self.message = storage.friendly_error(error)
            raise
        finally:
            self.operation = ""
            self.publish()


async def serve(output, trace):
    def emit(state):
        print(json.dumps({"state":state}), file=output, flush=True)
    controller = Controller(emit=emit, trace=trace)
    controller.publish()
    reader = asyncio.StreamReader(limit=4096)
    protocol = asyncio.StreamReaderProtocol(reader)
    transport, _ = await asyncio.get_running_loop().connect_read_pipe(lambda:protocol, sys.stdin)
    active = None

    async def perform(request):
        try:
            await controller.dispatch(request)
        except asyncio.CancelledError:
            pass
        except Exception:
            traceback.print_exc()

    try:
        while line := await reader.readline():
            try:
                request = json.loads(line)
                action = validate_request(request)
                if action == "status":
                    controller.publish()
                elif action == "disconnect":
                    if active and not active.done():
                        active.cancel(); await active
                    active = asyncio.create_task(perform(request))
                elif active and not active.done():
                    controller.message = "An operation is already running."
                    controller.publish()
                else:
                    active = asyncio.create_task(perform(request))
            except (ValueError, storage.UserError) as error:
                controller.failed = True
                controller.message = storage.friendly_error(error)
                controller.publish()
    finally:
        transport.close()
        if active and not active.done():
            active.cancel(); await active
        await controller.disconnect()


async def run(output, trace):
    loop, task = asyncio.get_running_loop(), asyncio.current_task()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, task.cancel)
    try:
        await serve(output, trace)
    except asyncio.CancelledError:
        pass


def main():
    os.umask(0o077)
    storage.secure_dir(storage.STATE)
    lock = os.open(storage.STATE/"operation.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit("Another OpenAdapt controller is running.")
    output = sys.stdout
    traces = storage.STATE/"sessions"
    storage.secure_dir(traces)
    trace_path = traces/(str(time.time_ns())+".private.jsonl")
    with trace_path.open("x") as evidence, (storage.STATE/"backend.private.log").open("a") as log:
        count = 0
        def trace(side, direction, packet):
            nonlocal count
            if count >= 4096:
                return
            count += 1
            value = packet.hex() if isinstance(packet, bytes) else packet
            evidence.write(json.dumps({"time":time.time(), "side":side, "direction":direction, "value":value})+"\n")
            evidence.flush()
        with contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
            try:
                asyncio.run(run(output, trace))
            except Exception:
                traceback.print_exc()
                print(json.dumps({"error":"The saved shoe list could not be loaded."}), file=output, flush=True)
    os.close(lock)


if __name__ == "__main__":
    main()

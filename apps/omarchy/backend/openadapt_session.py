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

import openadapt_app as storage

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
    allowed = {"status":set(), "connect":{"pair_id"}, "disconnect":set(), "battery":set(),
               "lace":{"side", "percent"}, "color":{"side", "color"}, "lights-off":set()}
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
    return action


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
                "message":self.message, "failed":self.failed, "new_pairing_available":False,
                "feet":{s:{**{k:feet[s].get(k) for k in PUBLIC_FOOT}, "connected":connected[s],
                           "connection":"connected" if connected[s] else self.connections[s]} for s in storage.SIDES}}

    def publish(self):
        self.emit(self.public())

    def changed(self, side, event, value):
        if event == "position" and side in self.profiles:
            self.feet[side]["percent"] = self.percent(value["raw_position"], self.profiles[side][2])
            self.feet[side]["raw_position"] = value["raw_position"]
            self.persist()
        elif event == "disconnected":
            self.connections[side] = "disconnected"
            if not self.stopping and self.operation != "connect":
                self.message = f"{side.capitalize()} shoe disconnected."
        self.publish()

    @staticmethod
    def percent(raw, maximum):
        return max(0, min(100, round(raw/maximum*20)*5))

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
        self.selected = pair
        self.profiles = storage.load_profiles({"version":1, "shoes":pair["shoes"]})
        if not self.feet:
            self.feet = copy.deepcopy(self.cache.get(pair_id, storage.blank_state()["feet"]))
        factory = self.link_factory
        if factory is None:
            from live import AutoMaxLiveLink
            factory = AutoMaxLiveLink
        errors = []
        for side in storage.SIDES:
            if self.links.get(side) and self.links[side].connected:
                continue
            if self.links.get(side):
                await self.links[side].stop()
            self.connections[side] = "connecting"
            self.message = f"Connecting {side} shoe…"
            self.publish()
            target, key, _ = self.profiles[side]
            link = factory(target, on_change=lambda event,value,s=side:self.changed(s,event,value),
                           trace=lambda direction,packet,s=side:self.trace(s,direction,packet))
            self.links[side] = link
            try:
                result = await link.start(key)
                self.status_read(side, result)
                self.connections[side] = "connected"
            except asyncio.CancelledError:
                raise
            except Exception as error:
                self.connections[side] = "disconnected"
                errors.append(f"{side.capitalize()}: {storage.friendly_error(error)}")
                self.trace(side, "error", type(error).__name__)
        count = sum(link.connected for link in self.links.values())
        self.message = "Both shoes connected" if count == 2 else " ".join(errors)
        self.failed = bool(errors)

    async def disconnect(self):
        self.stopping = True
        try:
            for link in self.links.values():
                await link.stop()
        finally:
            self.links.clear()
            self.connections = {s:"disconnected" for s in storage.SIDES}
            self.selected = None
            self.profiles = {}
            self.feet = {}
            self.stopping = False
        self.message = "Disconnected"

    async def control(self, request):
        selected = request.get("side", "both")
        if request["action"] in ("battery", "lights-off"):
            sides = tuple(s for s in storage.SIDES if self.links.get(s) and self.links[s].connected)
        else:
            sides = storage.SIDES if selected == "both" else (selected,)
        if not sides or not self.selected or any(not self.links.get(s) or not self.links[s].connected for s in sides):
            raise storage.UserError("Connect the selected shoes first.")
        for side in sides:
            foot = self.feet[side]
            kwargs = {}
            if request["action"] == "lace":
                kwargs = {"percent":request["percent"], "maximum":self.profiles[side][2]}
            if request["action"] == "color":
                kwargs = {"color":storage.COLORS[request["color"]]}
            try:
                result = await self.links[side].execute(request["action"], **kwargs)
                if "before" in result:
                    self.status_read(side, result["before"])
                if request["action"] == "lace":
                    foot.update(percent=request["percent"], raw_position=result["after_raw_position"])
                elif request["action"] == "color":
                    foot.update(color=request["color"], lights="color-set")
                elif request["action"] == "lights-off":
                    foot["lights"] = "off"
                foot.update(checked_at=int(time.time()), status="verified")
                self.persist()
            except BaseException:
                foot["status"] = "check-shoe"
                self.persist()
                raise
        self.message = {"lace":"Lacing updated", "color":"Color updated",
                        "battery":"Battery checked", "lights-off":"Lights off"}[request["action"]]

    async def dispatch(self, request):
        action = validate_request(request)
        if action == "status":
            self.publish()
            return
        if self.operation:
            raise storage.UserError("An operation is already running.")
        self.operation = action
        self.failed = False
        self.message = "Working…"
        self.publish()
        try:
            if action == "connect":
                await self.connect(request["pair_id"])
            elif action == "disconnect":
                await self.disconnect()
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

"""Read-only Nike Adapt BLE discovery; name hints never prove ownership."""
import argparse
import asyncio
import json
import math
import os
import tempfile
import sys
from pathlib import Path

from bleak import BleakClient, BleakScanner


CLEANUP_TIMEOUT = 5.0
BASE_UUID = "-0000-1000-8000-00805f9b34fb"
READ_ALLOWLIST = {
    "0000180a" + BASE_UUID: {"0000" + short + BASE_UUID for short in ("2a29", "2a24", "2a27", "2a26", "2a28")},
    "0000180f" + BASE_UUID: {"00002a19" + BASE_UUID},
}


async def cleanup(action, result, phase):
    async def finish():
        try:
            await asyncio.wait_for(action(), CLEANUP_TIMEOUT)
        except (Exception, asyncio.CancelledError) as exc:
            result["errors"].append({"phase": phase, "type": type(exc).__name__, "message": str(exc)})
            if isinstance(exc, asyncio.CancelledError):
                raise

    task = asyncio.create_task(finish())
    cancellation = None
    # The deadline and one Ctrl-C may both cancel this waiter. Keep shielding
    # the same task so neither aborts cleanup nor restarts its separate budget.
    while not task.done():
        try:
            await asyncio.shield(task)
        except asyncio.CancelledError as exc:
            cancellation = exc
    task.result()
    if cancellation is not None:
        raise cancellation


async def scan(args, result, scanner_factory):
    devices = {}

    def observe(device, data):
        if 0x0078 not in data.manufacturer_data or not (data.local_name or "").startswith(args.name_prefix):
            return
        devices[device.address] = (device, {
            "address": device.address, "local_name": data.local_name,
            "candidate": True, "ownership_verified": False,
            "manufacturer_data": {f"0x{k:04x}": bytes(v).hex() for k, v in data.manufacturer_data.items()},
            "service_uuids": list(data.service_uuids),
            "service_data": {k: bytes(v).hex() for k, v in data.service_data.items()},
            "rssi": data.rssi, "tx_power": data.tx_power,
        })
        result["advertisements"] = [record for _, record in devices.values()]

    scanner = scanner_factory(detection_callback=observe)
    try:
        await scanner.start()
        await asyncio.sleep(args.duration)
    finally:
        await cleanup(scanner.stop, result, "scan-stop")
    return devices


def metadata(item):
    return {"uuid": item.uuid, "handle": item.handle, "description": item.description}


async def run(args, result, scanner_factory, client_factory):
    devices = await scan(args, result, scanner_factory)
    if args.command == "scan" or result["errors"]:
        return
    if args.address not in devices:
        raise ValueError("Target not seen as a candidate in fresh scan")
    result["phase"] = "connect"
    client = client_factory(devices[args.address][0], pair=False, timeout=args.timeout)
    try:
        await client.connect()
        result["phase"] = "gatt"
        pending_reads = []
        for service in client.services:
            entry = metadata(service)
            entry["characteristics"] = []
            result["services"].append(entry)
            for characteristic in service.characteristics:
                item = metadata(characteristic)
                item["properties"] = list(characteristic.properties)
                item["descriptors"] = [metadata(d) for d in characteristic.descriptors]
                entry["characteristics"].append(item)
                if (args.read_standard and "read" in characteristic.properties
                        and characteristic.uuid.lower() in READ_ALLOWLIST.get(service.uuid.lower(), set())):
                    item["read"] = {"status": "not_attempted"}
                    pending_reads.append((characteristic, item))
        for characteristic, item in pending_reads:
            try:
                value = await asyncio.wait_for(client.read_gatt_char(characteristic), args.read_timeout)
                item["read"] = {"status": "ok", "hex": bytes(value).hex()}
            except (Exception, asyncio.CancelledError) as exc:
                item["read"] = {"status": "error", "timeout_seconds": args.read_timeout,
                                "error": {"type": type(exc).__name__, "message": str(exc)}}
                if isinstance(exc, asyncio.CancelledError):
                    raise
    finally:
        await cleanup(client.disconnect, result, "disconnect")


def save(path, result):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(json.dumps(result, indent=2) + "\n")
            stream.close()
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def main(argv=None, *, scanner_factory=BleakScanner, client_factory=BleakClient):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    commands = parser.add_subparsers(dest="command", required=True)
    scan_parser = commands.add_parser("scan", allow_abbrev=False, help="Capture candidate advertisements; no connection")
    inspect_parser = commands.add_parser("inspect", allow_abbrev=False, help="Inspect GATT metadata of an explicitly owned candidate")
    inspect_parser.add_argument("--read-standard", action="store_true", help="Read only the fixed standard allowlist (no serial number)")
    inspect_parser.add_argument("--read-timeout", type=float, default=3.0)
    inspect_parser.add_argument("--address", required=True)
    inspect_parser.add_argument("--confirm-owned", action="store_true", required=True)
    for sub in (scan_parser, inspect_parser):
        sub.add_argument("--duration", type=float, default=5.0)
        sub.add_argument("--timeout", type=float, default=30.0)
        sub.add_argument("--name-prefix", default="002-BV6397-110")
        sub.add_argument("--output", type=Path,
                         default=Path(__file__).resolve().parents[2] / f"private/{sub.prog.split()[-1]}.json")
    args = parser.parse_args(argv)
    for field, maximum in (("duration", 60), ("timeout", 120), ("read_timeout", 10)):
        value = getattr(args, field, 1)
        if not math.isfinite(value) or not 0 < value <= maximum:
            parser.error(f"--{field.replace('_', '-')} must be finite, > 0 and <= {maximum}")
    if not args.name_prefix.strip() or (args.command == "inspect" and not args.address.strip()):
        parser.error("--name-prefix and --address must not be empty")
    result = {"command": args.command, "advertisements": [], "errors": [], "phase": "scan"}
    if args.command == "inspect":
        result.update(address=args.address, ownership_confirmed_by_user=args.confirm_owned, services=[])
    async def run_with_deadline():
        # Keep cancellation and cleanup in the runner's main task. An outer
        # wait_for can exit early on SIGINT while its cancelled child cleans up.
        async with asyncio.timeout(args.timeout):
            await run(args, result, scanner_factory, client_factory)

    try:
        asyncio.run(run_with_deadline())
    except (Exception, asyncio.CancelledError, KeyboardInterrupt) as exc:
        result["errors"].append({"phase": result["phase"], "type": type(exc).__name__, "message": str(exc)})
    try:
        save(args.output, result)
    except OSError as exc:
        result["errors"].append({"phase": "save", "type": type(exc).__name__, "message": str(exc)})
        print(f"Could not save {args.output}; partial JSON follows on stdout", file=sys.stderr)
        print(json.dumps(result, indent=2))
    return 130 if any(e["type"] in {"CancelledError", "KeyboardInterrupt"} for e in result["errors"]) else int(bool(result["errors"]))


if __name__ == "__main__":
    raise SystemExit(main())

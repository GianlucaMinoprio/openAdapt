"""SIMULATED unit tests only. Never instantiate real BLE hardware boundaries."""
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace as NS

import pytest


ROOT = Path(__file__).resolve().parents[1]


def cli():
    spec = importlib.util.spec_from_file_location("adapt_ble", ROOT / "adapt_ble.py")
    assert spec is not None and Path(spec.origin).exists(), "CLI implementation missing"
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def advertisement(address="SIMULATED-OWNED", name="002-BV6397-110", maker=0x0078):
    device = NS(address=address, name="cached-name-must-not-be-used")
    data = NS(local_name=name, manufacturer_data={maker: b"\x01\xab"},
              service_uuids=["0000180a-0000-1000-8000-00805f9b34fb"],
              service_data={}, rssi=-61, tx_power=None)
    return device, data


class Radio:
    """Only the scanner/client boundary is simulated, not application logic."""
    def __init__(self, advertisements=()):
        self.advertisements = advertisements
        self.events = []

    def scanner(self, *, detection_callback):
        radio = self

        class Scanner:
            async def start(self):
                radio.events.append("scan-start")
                for device, data in radio.advertisements:
                    detection_callback(device, data)

            async def stop(self):
                radio.events.append("scan-stop")

        return Scanner()

    def no_client(self, *args, **kwargs):
        raise AssertionError("scan must never construct a client")


def test_scan_exports_only_manufacturer_and_name_candidates(tmp_path):
    radio = Radio([advertisement(), advertisement("WRONG-MAKER", maker=1),
                   advertisement("WRONG-NAME", name="other"),
                   advertisement("NO-NAME", name=None)])
    output = tmp_path / "scan.json"
    status = cli().main(["scan", "--duration", "0.001", "--output", str(output)],
                        scanner_factory=radio.scanner, client_factory=radio.no_client)
    assert status == 0
    result = json.loads(output.read_text())
    assert result["command"] == "scan"
    assert result["advertisements"] == [{
        "address": "SIMULATED-OWNED", "local_name": "002-BV6397-110",
        "candidate": True, "ownership_verified": False,
        "manufacturer_data": {"0x0078": "01ab"},
        "service_uuids": ["0000180a-0000-1000-8000-00805f9b34fb"],
        "service_data": {}, "rssi": -61, "tx_power": None,
    }]
    assert radio.events == ["scan-start", "scan-stop"]


def test_scan_start_failure_saves_partial_json_and_stops(tmp_path):
    radio = Radio([advertisement()])
    def failing_scanner(**kwargs):
        scanner = radio.scanner(**kwargs)
        original_start = scanner.start
        async def start():
            await original_start()
            raise RuntimeError("simulated scanner failure")
        scanner.start = start
        return scanner
    output = tmp_path / "partial.json"
    status = cli().main(["scan", "--duration", "0.001", "--output", str(output)],
                        scanner_factory=failing_scanner, client_factory=radio.no_client)
    assert status == 1
    result = json.loads(output.read_text())
    assert len(result["advertisements"]) == 1
    assert result["errors"][0]["type"] == "RuntimeError"
    assert "simulated scanner failure" in result["errors"][0]["message"]
    assert radio.events[-1] == "scan-stop"

def test_scan_deadline_stops_hanging_scanner_and_saves_json(tmp_path):
    import asyncio
    import time
    radio = Radio()
    def hanging_scanner(**kwargs):
        scanner = radio.scanner(**kwargs)
        async def start():
            radio.events.append("scan-start")
            await asyncio.Event().wait()
        scanner.start = start
        return scanner
    output = tmp_path / "timeout.json"
    started = time.monotonic()
    status = cli().main(["scan", "--timeout", "0.02", "--output", str(output)],
                        scanner_factory=hanging_scanner, client_factory=radio.no_client)
    assert status == 1
    assert time.monotonic() - started < 1
    assert json.loads(output.read_text())["errors"][0]["type"] == "TimeoutError"
    assert radio.events == ["scan-start", "scan-stop"]


def test_scan_cleanup_is_bounded_and_failure_recorded(tmp_path):
    import asyncio
    import time
    radio = Radio()
    def slow_cleanup(**kwargs):
        scanner = radio.scanner(**kwargs)
        async def stop():
            radio.events.append("scan-stop")
            await asyncio.sleep(0.2)
        scanner.stop = stop
        return scanner
    module = cli()
    module.CLEANUP_TIMEOUT = 0.01
    output = tmp_path / "cleanup.json"
    started = time.monotonic()
    status = module.main(["scan", "--duration", "0.001", "--output", str(output)],
                         scanner_factory=slow_cleanup, client_factory=radio.no_client)
    assert status == 1
    assert time.monotonic() - started < 0.15
    assert json.loads(output.read_text())["errors"][0]["phase"] == "scan-stop"
    assert radio.events[-1] == "scan-stop"


def test_inspect_requires_explicit_address_and_ownership(tmp_path, capsys):
    import pytest
    radio = Radio()
    for flags, missing in [([], "--address"), (["--address", "SIMULATED-OWNED"], "--confirm-owned"),
                           (["--confirm-owned"], "--address")]:
        with pytest.raises(SystemExit) as exit:
            cli().main(["inspect", *flags, "--output", str(tmp_path / "no.json")],
                       scanner_factory=radio.scanner, client_factory=radio.no_client)
        assert exit.value.code == 2
        diagnostic = capsys.readouterr().err
        assert "required" in diagnostic and missing in diagnostic
        assert radio.events == []
        assert not (tmp_path / "no.json").exists()


def test_inspect_connects_fresh_device_and_emits_metadata_without_reads(tmp_path):
    observed = advertisement()
    radio = Radio([observed])
    descriptor = NS(uuid="00002902-0000-1000-8000-00805f9b34fb", handle=4, description="CCCD")
    characteristic = NS(uuid="30c4142f-b083-42cf-865a-d5b91801bcd7", handle=3,
                        description="Custom", properties=["read", "notify"], descriptors=[descriptor])
    service = NS(uuid="1a2328af-3d0b-4b04-a2aa-973c239d3904", handle=1,
                 description="Custom service", characteristics=[characteristic])
    def client(device, *, pair, timeout):
        assert device is observed[0], "must pass fresh BLEDevice, never raw address"
        assert pair is False
        assert radio.events[-1] == "scan-stop", "scan must stop before connecting"
        class Client:
            services = [service]
            async def connect(self):
                radio.events.append("connect")
            async def disconnect(self):
                radio.events.append("disconnect")
        return Client()
    output = tmp_path / "inspect.json"
    status = cli().main(["inspect", "--address", "SIMULATED-OWNED", "--confirm-owned",
                         "--duration", "0.001", "--output", str(output)],
                        scanner_factory=radio.scanner, client_factory=client)
    assert status == 0
    result = json.loads(output.read_text())
    assert result["address"] == "SIMULATED-OWNED"
    assert result["ownership_confirmed_by_user"] is True
    assert result["services"] == [{"uuid": service.uuid, "handle": 1,
        "description": "Custom service", "characteristics": [{"uuid": characteristic.uuid,
        "handle": 3, "description": "Custom", "properties": ["read", "notify"],
        "descriptors": [{"uuid": descriptor.uuid, "handle": 4, "description": "CCCD"}]}]}]
    assert radio.events == ["scan-start", "scan-stop", "connect", "disconnect"]


def test_inspect_missing_or_nonmatching_target_never_connects(tmp_path):
    for observed in ([], [advertisement(maker=1)], [advertisement(name="unrelated")],
                     [advertisement("OTHER-CANDIDATE")]):
        radio = Radio(observed)
        output = tmp_path / "missing.json"
        status = cli().main(["inspect", "--address", "SIMULATED-OWNED", "--confirm-owned",
                             "--duration", "0.001", "--output", str(output)],
                            scanner_factory=radio.scanner, client_factory=radio.no_client)
        assert status == 1
        result = json.loads(output.read_text())
        assert "not seen as a candidate in fresh scan" in result["errors"][0]["message"]
        assert result["services"] == []
        assert radio.events == ["scan-start", "scan-stop"]


def test_inspect_scan_stop_failure_prevents_connection(tmp_path):
    radio = Radio([advertisement()])
    def failing_stop(**kwargs):
        scanner = radio.scanner(**kwargs)
        async def stop():
            radio.events.append("scan-stop")
            raise RuntimeError("simulated stop failure")
        scanner.stop = stop
        return scanner
    output = tmp_path / "failed-stop.json"
    status = cli().main(["inspect", "--address", "SIMULATED-OWNED", "--confirm-owned",
                         "--duration", "0.001", "--output", str(output)],
                        scanner_factory=failing_stop, client_factory=radio.no_client)
    assert status == 1
    assert len(json.loads(output.read_text())["errors"]) == 1, "never attempt connection after failed scan cleanup"


def uuid(short):
    return f"0000{short}-0000-1000-8000-00805f9b34fb"


def characteristic(short, handle, properties=("read",)):
    return NS(uuid=uuid(short), handle=handle, description="simulated", properties=properties, descriptors=[])


def service(short, characteristics):
    return NS(uuid=uuid(short), handle=0, description="simulated", characteristics=characteristics)


class InspectRadio(Radio):
    def __init__(self, services=()):
        super().__init__([advertisement()])
        self.services = services
        self.reads = []

    def client(self, device, *, pair, timeout):
        assert device is self.advertisements[0][0]
        assert pair is False
        assert self.events[-1] == "scan-stop"
        radio = self
        class Client:
            services = radio.services
            async def connect(self):
                radio.events.append("connect")
            async def disconnect(self):
                radio.events.append("disconnect")
            async def read_gatt_char(self, item):
                assert not isinstance(item, (str, int)), "read by object, not ambiguous UUID"
                radio.reads.append(item)
                return b"test"
        return Client()


def inspect_run(tmp_path, radio, *extra, module=None):
    output = tmp_path / "inspect.json"
    status = (module or cli()).main(["inspect", "--address", "SIMULATED-OWNED", "--confirm-owned",
                                    "--duration", "0.001", "--output", str(output), *extra],
                                   scanner_factory=radio.scanner, client_factory=radio.client)
    return status, json.loads(output.read_text())


def test_optional_reads_use_standard_service_allowlist_and_objects(tmp_path):
    approved = [characteristic(short, n) for n, short in enumerate(("2a29", "2a24", "2a27", "2a26", "2a28"), 1)]
    duplicate = characteristic("2a29", 10)
    battery = characteristic("2a19", 11)
    radio = InspectRadio([
        service("180a", approved + [duplicate, characteristic("2a25", 12), characteristic("2a00", 13),
                                     characteristic("2a26", 14, ["write"])]),
        service("180f", [battery]), service("1800", [characteristic("2a00", 15)]),
        service("ffff", [characteristic("2a29", 16)]),
    ])
    status, result = inspect_run(tmp_path, radio, "--read-standard")
    assert status == 0
    assert radio.reads == approved + [duplicate, battery]
    items = [c for s in result["services"] for c in s["characteristics"]]
    assert [c["handle"] for c in items if "read" in c] == [c.handle for c in radio.reads]
    assert all(c["read"] == {"status": "ok", "hex": "74657374"} for c in items if "read" in c)
    assert radio.events[-1] == "disconnect"


def test_individual_read_failure_is_recorded_and_remaining_reads_continue(tmp_path):
    items = [characteristic("2a29", 1), characteristic("2a24", 2)]
    radio = InspectRadio([service("180a", items)])
    original = radio.client
    def failing_read(*args, **kwargs):
        client = original(*args, **kwargs)
        async def read(item):
            radio.reads.append(item)
            if item.handle == 1:
                raise RuntimeError("simulated read denied; do not pair")
            return b"model"
        client.read_gatt_char = read
        return client
    radio.client = failing_read
    status, result = inspect_run(tmp_path, radio, "--read-standard")
    assert status == 0, "individual unavailable reads do not invalidate GATT metadata"
    reads = [c["read"] for c in result["services"][0]["characteristics"]]
    assert reads[0]["status"] == "error"
    assert reads[0]["error"]["type"] == "RuntimeError"
    assert reads[1]["hex"] == "6d6f64656c"
    assert radio.reads == items
    assert radio.events[-1] == "disconnect"


def test_read_timeout_is_per_read_and_continues(tmp_path):
    import asyncio
    radio = InspectRadio([service("180a", [characteristic("2a29", 1), characteristic("2a24", 2)])])
    original = radio.client
    def slow_read(*args, **kwargs):
        client = original(*args, **kwargs)
        async def read(item):
            radio.reads.append(item)
            if item.handle == 1:
                await asyncio.sleep(0.2)
            return b"ok"
        client.read_gatt_char = read
        return client
    radio.client = slow_read
    status, result = inspect_run(tmp_path, radio, "--read-standard", "--read-timeout", "0.01")
    assert status == 0
    reads = [c["read"] for c in result["services"][0]["characteristics"]]
    assert reads[0]["error"]["type"] == "TimeoutError"
    assert reads[0]["timeout_seconds"] == 0.01
    assert reads[1]["status"] == "ok"
    assert radio.events[-1] == "disconnect"


def test_rejects_unbounded_empty_or_abbreviated_arguments_before_radio(tmp_path):
    import pytest
    invalid = [["scan", "--duration", v] for v in ("-1", "0", "nan", "inf", "61")]
    invalid += [["scan", "--timeout", v] for v in ("0", "nan", "inf", "121")]
    invalid += [["scan", "--name-prefix", ""], ["scan", "--name-prefix", "   "]]
    invalid += [["inspect", "--address", "SIMULATED-OWNED", "--confirm-owned", "--read-timeout", v]
                for v in ("0", "nan", "inf", "11")]
    invalid += [["inspect", "--address", "", "--confirm-owned"],
                ["inspect", "--address", "SIMULATED-OWNED", "--confirm"]]
    for arguments in invalid:
        radio = Radio()
        with pytest.raises(SystemExit) as exit:
            arguments = [*arguments, "--output", str(tmp_path / "invalid.json")]
            cli().main([*arguments, "--duration", "0.001"] if "--duration" not in arguments else arguments,
                       scanner_factory=radio.scanner, client_factory=radio.no_client)
        assert exit.value.code == 2
        assert radio.events == []


def test_connection_failures_disconnect_and_save_phase(tmp_path):
    import asyncio
    for failure in (RuntimeError("simulated connection failure"), "timeout"):
        radio = InspectRadio()
        original = radio.client
        def failing_connect(*args, **kwargs):
            client = original(*args, **kwargs)
            async def connect():
                radio.events.append("connect")
                if failure == "timeout":
                    await asyncio.sleep(0.2)
                else:
                    raise failure
            client.connect = connect
            return client
        radio.client = failing_connect
        status, result = inspect_run(tmp_path, radio, "--timeout", "0.02")
        assert status == 1
        assert result["errors"][0]["phase"] == "connect"
        assert result["errors"][0]["type"] == ("TimeoutError" if failure == "timeout" else "RuntimeError")
        assert result["address"] == "SIMULATED-OWNED" and result["services"] == []
        assert radio.events == ["scan-start", "scan-stop", "connect", "disconnect"]


def test_gatt_enumeration_failure_preserves_already_collected_metadata(tmp_path):
    def broken_services():
        yield service("180a", [characteristic("2a29", 1)])
        raise RuntimeError("simulated enumeration failure")
    radio = InspectRadio(broken_services())
    status, result = inspect_run(tmp_path, radio)
    assert status == 1
    assert result["errors"][0]["phase"] == "gatt"
    assert len(result["services"]) == 1
    assert result["services"][0]["characteristics"][0]["handle"] == 1
    assert radio.events[-1] == "disconnect"


def test_overall_deadline_marks_interrupted_read_and_keeps_full_metadata(tmp_path):
    import asyncio
    radio = InspectRadio([service("180a", [characteristic("2a29", 1), characteristic("2a24", 2)])])
    original = radio.client
    def slow_read(*args, **kwargs):
        client = original(*args, **kwargs)
        async def read(item):
            await asyncio.sleep(0.2)
            return b"late"
        client.read_gatt_char = read
        return client
    radio.client = slow_read
    status, result = inspect_run(tmp_path, radio, "--read-standard", "--timeout", "0.02")
    assert status == 1
    items = result["services"][0]["characteristics"]
    assert len(items) == 2, "enumerate all metadata before optional reads"
    assert items[0]["read"]["error"]["type"] == "CancelledError"
    assert items[1]["read"]["status"] == "not_attempted"
    assert result["errors"][0]["type"] == "TimeoutError"
    assert radio.events[-1] == "disconnect"


def test_deadline_during_disconnect_does_not_cancel_cleanup(tmp_path):
    import asyncio
    radio = InspectRadio()
    original = radio.client
    def slow_disconnect(*args, **kwargs):
        client = original(*args, **kwargs)
        async def disconnect():
            radio.events.append("disconnect")
            await asyncio.sleep(0.04)
            radio.events.append("disconnected")
        client.disconnect = disconnect
        return client
    radio.client = slow_disconnect
    status, result = inspect_run(tmp_path, radio, "--timeout", "0.02")
    assert status == 1
    assert radio.events[-1] == "disconnected", "deadline must allow bounded cleanup to finish"
    assert result["errors"][0]["type"] == "TimeoutError"


def test_cancelled_inspection_persists_partial_result_after_disconnect(tmp_path):
    import asyncio
    radio = InspectRadio()
    original = radio.client
    def cancelled_connect(*args, **kwargs):
        client = original(*args, **kwargs)
        async def connect():
            radio.events.append("connect")
            raise asyncio.CancelledError("simulated cancellation")
        client.connect = connect
        return client
    radio.client = cancelled_connect
    status, result = inspect_run(tmp_path, radio)
    assert status == 130
    assert result["errors"][0]["type"] == "CancelledError"
    assert radio.events[-1] == "disconnect"


def test_sigint_saves_partial_json_and_disconnects_in_simulated_subprocess(tmp_path):
    import subprocess
    import sys
    script = r"""
import asyncio, os, signal, sys
from tests.test_cli import InspectRadio
import adapt_ble
radio = InspectRadio()
original = radio.client
def client(*args, **kwargs):
    instance = original(*args, **kwargs)
    async def connect():
        radio.events.append("connect")
        asyncio.get_running_loop().call_soon(os.kill, os.getpid(), signal.SIGINT)
        await asyncio.sleep(10)
    instance.connect = connect
    return instance
code = adapt_ble.main(["inspect", "--address", "SIMULATED-OWNED", "--confirm-owned",
                       "--duration", "0.001", "--output", sys.argv[1]],
                      scanner_factory=radio.scanner, client_factory=client)
assert radio.events[-1] == "disconnect", radio.events
raise SystemExit(code)
"""
    output = tmp_path / "interrupt.json"
    process = subprocess.run([sys.executable, "-c", script, str(output)], cwd=ROOT,
                             capture_output=True, text=True, timeout=3)
    assert process.returncode == 130, process.stderr
    assert output.exists(), "SIGINT must preserve partial JSON"
    assert json.loads(output.read_text())["errors"][0]["type"] == "KeyboardInterrupt"
    assert process.stderr == ""


@pytest.mark.parametrize("phase", ["scan-stop", "disconnect"])
@pytest.mark.parametrize("outcome", ["complete", "error", "timeout", "cancelled"])
@pytest.mark.parametrize("deadline_stage", ["operation", "cleanup"])
def test_sigint_after_deadline_preserves_cleanup_budget(tmp_path, phase, outcome, deadline_stage):
    import subprocess
    import sys
    script = r"""
import asyncio, json, os, signal, sys
from tests.test_cli import InspectRadio
import adapt_ble

output, phase, outcome, deadline_stage = sys.argv[1:]
radio = InspectRadio()
adapt_ble.CLEANUP_TIMEOUT = 0.3
cleanup_elapsed = None

async def hang_until_deadline():
    global operation_task
    operation_task = asyncio.current_task()
    if deadline_stage == "cleanup":
        return
    try:
        await asyncio.Event().wait()
    except asyncio.CancelledError:
        radio.events.append("operation-deadline")
        raise

async def interrupted_cleanup():
    global cleanup_elapsed
    loop = asyncio.get_running_loop()
    started = loop.time()
    radio.events.append(phase + "-start")
    def interrupt():
        radio.events.append("sigint")
        os.kill(os.getpid(), signal.SIGINT)
    def after_deadline():
        if deadline_stage == "cleanup":
            if not operation_task.cancelling():
                loop.call_later(0.001, after_deadline)
                return
            radio.events.append("operation-deadline")
        # Give the deadline cancellation a turn before the single SIGINT.
        loop.call_later(0.01, interrupt)
    after_deadline()
    try:
        if outcome == "timeout":
            await asyncio.Event().wait()
        await asyncio.sleep(0.08)
        if outcome == "error":
            radio.events.append(phase + "-failed")
            raise RuntimeError("simulated cleanup failure")
        if outcome == "cancelled":
            raise asyncio.CancelledError("simulated cleanup cancellation")
        radio.events.append(phase + "-complete")
    except asyncio.CancelledError:
        radio.events.append(phase + "-cancelled")
        raise
    finally:
        cleanup_elapsed = loop.time() - started

def scanner(**kwargs):
    instance = radio.scanner(**kwargs)
    original_start = instance.start
    if phase == "scan-stop":
        async def start():
            await original_start()
            await hang_until_deadline()
        instance.start = start
        instance.stop = interrupted_cleanup
    return instance

def client(*args, **kwargs):
    instance = radio.client(*args, **kwargs)
    original_connect = instance.connect
    async def connect():
        await original_connect()
        await hang_until_deadline()
    instance.connect = connect
    instance.disconnect = interrupted_cleanup
    return instance

arguments = (["scan"] if phase == "scan-stop" else
             ["inspect", "--address", "SIMULATED-OWNED", "--confirm-owned"])
code = adapt_ble.main([*arguments, "--duration", "0.001", "--timeout", "0.02", "--output", output],
                      scanner_factory=scanner, client_factory=client)
print(json.dumps({"events": radio.events, "cleanup_elapsed": cleanup_elapsed}))
raise SystemExit(code)
"""
    output = tmp_path / "interrupt-after-deadline.json"
    process = subprocess.run([sys.executable, "-c", script, str(output), phase, outcome, deadline_stage], cwd=ROOT,
                             capture_output=True, text=True, timeout=3)
    assert process.returncode == 130, process.stderr
    assert process.stderr == ""
    trace = json.loads(process.stdout)
    events = trace["events"]
    result = json.loads(output.read_text())
    print(json.dumps({"phase": phase, "outcome": outcome, "deadline_stage": deadline_stage, **trace, "result": result}))
    assert "operation-deadline" in events
    first, second = ("operation-deadline", phase + "-start") if deadline_stage == "operation" else (phase + "-start", "operation-deadline")
    assert events.index(first) < events.index(second) < events.index("sigint")
    terminal_event = {"complete": "complete", "error": "failed", "timeout": "cancelled", "cancelled": "cancelled"}[outcome]
    assert events[-1] == phase + "-" + terminal_event, (events, result["errors"])
    assert trace["cleanup_elapsed"] >= (0.29 if outcome == "timeout" else 0.07), trace
    expected_errors = []
    if outcome != "complete":
        error_type, message = {"error": ("RuntimeError", "simulated cleanup failure"),
                               "timeout": ("TimeoutError", ""),
                               "cancelled": ("CancelledError", "simulated cleanup cancellation")}[outcome]
        expected_errors.append({"phase": phase, "type": error_type, "message": message})
    operation_phase = "scan" if phase == "scan-stop" else ("connect" if deadline_stage == "operation" else "gatt")
    expected_errors.append({"phase": operation_phase,
                            "type": "KeyboardInterrupt", "message": ""})
    assert result["errors"] == expected_errors
    assert len(result["advertisements"]) == 1, "interruption must retain partial JSON"


def test_inspection_scan_failure_still_records_requested_target(tmp_path):
    radio = InspectRadio()
    def unavailable_scanner(**kwargs):
        raise RuntimeError("simulated adapter unavailable")
    radio.scanner = unavailable_scanner
    status, result = inspect_run(tmp_path, radio)
    assert status == 1
    assert result["address"] == "SIMULATED-OWNED"
    assert result["ownership_confirmed_by_user"] is True
    assert result["services"] == []
    assert radio.events == []


def test_json_capture_is_owner_only_even_when_replacing_existing_file(tmp_path):
    import stat
    radio = Radio()
    output = tmp_path / "private" / "scan.json"
    output.parent.mkdir()
    output.write_text("old capture")
    output.chmod(0o644)
    status = cli().main(["scan", "--duration", "0.001", "--output", str(output)],
                        scanner_factory=radio.scanner, client_factory=radio.no_client)
    assert status == 0
    assert stat.S_IMODE(output.stat().st_mode) == 0o600
    assert json.loads(output.read_text())["advertisements"] == []
    assert list(output.parent.iterdir()) == [output]


def test_output_failure_emits_partial_json_to_stdout_after_cleanup(tmp_path, capsys):
    radio = InspectRadio([service("180a", [characteristic("2a29", 1)])])
    output = tmp_path / "is-a-directory"
    output.mkdir()
    status = cli().main(["inspect", "--address", "SIMULATED-OWNED", "--confirm-owned",
                         "--duration", "0.001", "--output", str(output)],
                        scanner_factory=radio.scanner, client_factory=radio.client)
    assert status == 1
    captured = capsys.readouterr()
    result = json.loads(captured.out)
    assert len(result["services"]) == 1
    assert result["errors"][-1]["phase"] == "save"
    assert "could not save" in captured.err.lower()
    assert radio.events[-1] == "disconnect"
    assert list(tmp_path.iterdir()) == [output]

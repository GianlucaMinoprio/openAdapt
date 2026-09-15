# Nike Adapt BLE discovery spike

Small read-only Python CLI, not a shoe controller or an iPhone app.

**Verification: 37 simulated tests pass, including the timeout/SIGINT cleanup regressions. Earlier operator-run hardware tests established discovery and standard reads.** The CLI scan found both candidate shoes. Separate inspections of both shoes exited 0, each enumerating four services and successfully reading manufacturer, model, hardware and firmware. No top-level or standard-read errors were reported. Private captures and the verification summary are under the project root `private/`. Unit tests use injected scanner/client factories and were developed as vertical RED → GREEN slices, including a SIGINT subprocess. Motor control and application authentication remain untested.

## Setup

Requires Python 3.11, `uv`, and (for operator-run hardware commands) a working Linux BlueZ adapter/session. No root, pairing, trust, reset, or Bluetooth configuration commands are included.

```sh
# From the repository root:
cd spikes/001-ble-discovery
uv sync --locked
.venv/bin/python -m pytest -q
.venv/bin/python adapt_ble.py --help
```

`pyproject.toml` pins Bleak **3.0.2** and pytest **9.1.1**. `uv.lock` locks transitive dependencies. The isolated `.venv` is local to this spike; Hermes's environment is untouched.

## Operator usage — these commands access hardware

Run one Bluetooth investigation at a time. Stop other investigators before using this CLI.

```sh
# Advertising/scan-response capture only; never constructs a GATT client.
.venv/bin/python adapt_ble.py scan --duration 5 --timeout 15 \
  --output ../../private/scan.json

# Replace the placeholder with the EXACT address from a fresh capture.
# Only continue if you independently know this target is your own shoe.
.venv/bin/python adapt_ble.py inspect \
  --address '<YOUR-OWNED-DEVICE-ADDRESS>' --confirm-owned \
  --duration 5 --timeout 30 --output ../../private/owned-metadata.json

# Optional standard reads; no custom UUID arguments are supported.
.venv/bin/python adapt_ble.py inspect \
  --address '<YOUR-OWNED-DEVICE-ADDRESS>' --confirm-owned --read-standard \
  --duration 5 --timeout 30 --read-timeout 3 \
  --output ../../private/owned-standard.json
```

Without `--output`, captures go to the project root's `private/scan.json` or `private/inspect.json`, independent of working directory. **A run replaces its output file.** Use distinct filenames to preserve captures. Files are atomically replaced with owner-only permissions (0600); newly created final directories use 0700. Existing directory permissions are not changed. The project root `.gitignore` excludes `private/`; the spike `.gitignore` also excludes local private captures and `.venv`.

## Safety contract

- Candidates must have **both** Nike manufacturer ID `0x0078` **and** an advertised local name starting with `--name-prefix` (default `002-BV6397-110`). Cached device names are not used. The latest matching observation per address is saved; this is not a packet-by-packet trace. A missing/partial advertisement may mean no match.
- These are spoofable candidate hints, **not ownership proof or retail-model identification**. `ownership_verified` remains false; `ownership_confirmed_by_user` records only the operator's explicit assertion.
- `scan` performs Bleak's normal **active BLE scan**, which can send scan requests, but performs no GATT connection or read. “Advertising only” does not mean passive RF listening.
- `inspect` requires the full `--address` and `--confirm-owned` flags. It scans again, requires that exact address to match the same candidate filter, stops scanning, and connects using the newly observed **BLEDevice object**, with `pair=False`. Failed scan cleanup prevents connection.
- GATT service/characteristic/descriptor UUIDs, handles, descriptions and characteristic properties are metadata only. Descriptors are never read or written. All metadata is collected before optional characteristic reads.
- No characteristic writes, notification subscriptions, pairing, trust, unpair/reset, DFU, custom reads, arbitrary read UUIDs, or shoe-control operations exist in the CLI. It does not retry protected reads with pairing.

`--read-standard` reads only readable characteristics in this fixed **service + characteristic** allowlist:

| Service | Characteristic |
|---|---|
| Device Information `180a` | Manufacturer `2a29`, Model `2a24`, Hardware `2a27`, Firmware `2a26`, Software `2a28` |
| Battery `180f` | Battery Level `2a19` |

All short UUIDs use the standard Bluetooth base UUID. Serial Number, System ID and Device Name are intentionally excluded, including Device Name under Device Information. Missing Battery/Device Information services are not errors. Reads pass characteristic **objects**, avoiding ambiguous duplicate UUIDs. Values are preserved as raw hexadecimal, not interpreted as device identity.

## Bounds and failure output

- `--duration`: scan observation window, default 5 seconds, finite `>0`, maximum 60.
- `--timeout`: whole async operation deadline, default 30 seconds, finite `>0`, maximum 120; includes scanning, connection, metadata and all reads.
- `--read-timeout`: per optional read, default 3 seconds, finite `>0`, maximum 10.
- Scanner stop and client disconnect are always attempted in `finally`, including start/connect exceptions. Each cleanup has a separate 5-second budget and is shielded from the operation deadline. Allow cleanup time beyond `--timeout`. These are cooperative asyncio deadlines, not a guarantee against a blocked OS/backend or forced process termination. A timed-out disconnect is reported, not claimed successful.

Exit codes: **0** completed operation (possibly no scan candidates or individual read errors); **1** operation/cleanup/output failure, including target absent and connection failure; **2** invalid arguments before radio access; **130** interruption/cancellation.

Top-level `errors` records exception type, message and phase. `phase` is the last operation phase, not a success flag. Each attempted optional read has `status: ok` plus `hex`, or `status: error` plus exception details and `timeout_seconds`. Individual read failures do not stop later allowed reads; overall cancellation does. Queued reads interrupted before starting remain `not_attempted`.

Partial JSON is saved after failures or one Ctrl-C when possible. If saving fails, partial JSON is printed to stdout with a warning on stderr; treat terminal logs as private too. SIGKILL, repeated forced interrupts, OS failure and storage failure cannot guarantee capture persistence or disconnect.

## Verdict: PARTIAL

Discovery and standard reads are validated on both owner-confirmed Nike Adapt Huarache shoes. The CLI and its simulated failure-path tests pass. The full restoration goal remains partial: no replacement authentication or control has been demonstrated on hardware, and no iPhone app exists. The separate enrollment spike now has an offline handshake simulation. See [project status](../../docs/STATUS.md) for verified progress and next gates; raw hardware evidence remains private and is not included in this repository. Original discovery code is available under the project root MIT license; third-party protocol research is not incorporated into it.

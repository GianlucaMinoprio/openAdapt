# Available-pair investigation

> Historical research checkpoint. For current capabilities, test totals and remaining work, see [Project status](STATUS.md). Statements below describe the evidence available at the checkpoint date.

September 13, 2026, late morning Pacific. The owner reported two pairs, left a charged pair near the computer/Nordic board, and authorized testing either available shoe while taking the iPhone away. No factory reset was performed. This is a later pair than the Huaraches in the earlier iPhone recordings.

## Hardware result

Both available shoes accepted a fresh, unpaired BLE connection through the existing discovery CLI. Each exposed four GATT services and returned four allowlisted standard values without errors. Both disconnected cleanly. This establishes discovery, connection and standard reads, not application authentication or control.

| Observation | Both available shoes |
|---|---|
| Fresh advertised family | Auto Max (004); full name kept private |
| Nike manufacturer data | Present |
| Manufacturer characteristic | Nike |
| Generic model characteristic | Nike Adapt EARL BB |
| Hardware revision | 1.0 |
| Firmware revision | 2.4.3M |
| Nike command service | Present, with write and notification characteristics matching the inspected protocol |
| Laptop Bluetooth state immediately after inspection | Not paired, bonded, trusted or connected |

The archived app's product manifest maps shoe family `004` to **Nike Adapt AutoMax**. This explains why the default Huarache advertising filter found zero candidates; a manufacturer-only follow-up found both. The generic EARL BB device-information string is not sufficient to infer the retail model. Family mapping is supported by local app evidence; retail listings also associate this style with [Nike Adapt Auto Max](https://www.dtlr.com/products/nike-adapt-auto-max-cz6804-001). No battery characteristic was present, so the owner's statement that they were charged was not independently measured.

Targets A and B were selected from the two fresh matching advertisements under the owner's authorization to use either available shoe. A was the stronger signal in that scan. These labels do not infer left/right. Manufacturer/name/address observations are not cryptographic ownership proof; target identities remain private.

A later state query no longer found either transient device entry. Neither appeared in the laptop's connected-device list. The private analysis distinguishes that later unavailable state from the explicit unpaired/disconnected observation immediately after inspection.

## Software progress

`spikes/002-local-enrollment/ble_link.py` adds a single-use existing-key BlueZ lifecycle. It requires a valid application key before radio access, an exact owner-confirmed target in fresh Nike advertisements, and a pre-existing laptop bond before connection/subscription. Missing bond properties fail closed. The implementation uses the local Bleak BlueZ scanner's `details.props` representation; other default platforms are rejected.

It validates service/characteristic uniqueness and properties, uses explicit write-with-response on the fixed Nike characteristic, subscribes only for one existing-key handshake, and sends only authentication requests 112/113 and transport ACKs. It never invokes enrollment or post-authentication/control operations. It stops on unexpected notification threads, disconnects, bad proofs, timeout or cancellation. Cleanup is bounded and shielded, attempts disconnect after unsubscribe failure, and reports a backend that still claims to be connected after disconnect.

The **38 new simulated lifecycle tests** cover valid existing-key exchange, missing keys/targets/local bonds, incompatible services, backend failures, operation deadlines, repeated cancellation during disconnect and cleanup failure after a successful synthetic proof. The enrollment suite now has **134 passing tests**. This backend has not authenticated real hardware; only the earlier discovery CLI was used on the shoes.

## Remaining path to control

At the standard-read checkpoint, the computer had neither an established local Bluetooth bond nor a recovered application key. The later authorized USB HCI capture and Nike-only backup inspection recovered both kinds of keys privately; both Auto Max application keys reproduce the recorded original-app authentication responses. This does not establish a laptop bond. The current prototype also rejects the captured exchange at its extra peer-proof check; see [key findings](IPHONE-KEY-FINDINGS.md).

An existing-key attempt now has legitimate application credentials available, but still needs resolution of the captured peer-proof mismatch and a reviewed, explicitly scoped local pairing step. The lifecycle deliberately does not create that pairing automatically. A new-enrollment route instead needs a concrete one-shoe state-replacement decision, verified handling of physical-confirmation events, and review of the key-commit/recovery behavior. The owner offered a possible factory reset, but none was requested or executed in this run; resetting is not a substitute for those prerequisites.

The APK's notification/bonding code reports an unbonded state as unable to write and distinguishes key-exchange readiness events. Those are app-side observations, not proof of the Auto Max firmware's exact confirmation or key-retention rules. Light-command variants also need verification for this model/firmware after authentication. No light or motor command was sent, and remote control remains unproven.

## Private evidence

Ignored owner-only `private/autonomous-tests/20260913T180101Z/` contains the initial scan, manufacturer-only scan, target selection, both inspections, private console logs and aggregate analysis with source hashes. The original Hermes directories were consulted read-only. No file was staged, committed or pushed.

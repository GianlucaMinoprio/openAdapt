# Auto Max motor control verified

> Historical research checkpoint. For current capabilities, test totals and remaining work, see [Project status](STATUS.md). Statements below describe the evidence available at the checkpoint date.

September 15, 2026, 07:31 UTC. **OpenAdapt independently authenticated and laced
both owned Auto Max shoes using their existing keys and laptop bonds.** The
owner confirmed both shoes physically worked, then asked to stop because it was
late. All hardware tests are finished; do not send more shoe commands or resume
testing without the owner returning ready.

No factory reset, new enrollment or pairing-button confirmation was needed.
This demonstrates existing-key control, not independent enrollment of a fresh
or reset shoe. Whether a new application key can coexist with the original
app's key remains unknown. Fresh enrollment, Huarache support and a finished app
remain separate work.

## Scope and results

The owner previously requested 80/80 and now confirmed both shoes empty on the
table with Nike Adapt fully closed. The newly recovered fit maxima were checked
against the original app's fit-check completion events: 65 right and 61 left.
No old calibration was reused and no calibration setting was written.

| Shoe | Battery | Starting raw position | OpenAdapt 80% raw target | Completion status / position | Fresh position readback |
|---|---:|---:|---:|---|---:|
| Right | 96% | 0 | 52 | 0 / 51 | 51 |
| Left | 100% | 0 | 49 | 0 / 48 | 48 |

Each shoe completed within the one-raw-unit variation previously observed in
original-app movements. Requested percentages, raw targets and measured
positions remain distinct; this is not a claim that either measured position
is mathematically exactly 80%, or that Nike's iPhone display rounding is solved.
OpenAdapt maps percentage to nearest calibrated raw position, with positive
ties upward. A raw target of 80 would be a different command and was not sent.

The right status-only preflight succeeded first, with 19 recorded fragments.
Then the right motor operation took 17.033 seconds and the left took 15.979
seconds, including discovery, authentication, feedback and cleanup. Each motor
operation produced a complete 29-fragment transcript. Each sent exactly:

1. Existing-key authentication, opcodes 112/113.
2. Battery and current-position reads, 81/4.
3. Stop, 0, followed by one absolute-position request, 3.
4. A final current-position read, 4, after the shoe's successful opcode-5 event.

Every request was acknowledged. The independent offline verifier checks the
authentication proofs, complete message order, exact motor target, completion,
readback, fragment counters and both directions' required flow acknowledgments.
Neither motor operation required a retry or failure Stop.

Both shoes disconnected cleanly, with zero cleanup errors. Both saved laptop
bonds and their prior trust/block flags were unchanged. The original iPhone app
was kept closed; its subsequent operation has not been retested. The owner
reported “it worked just laced” after the right test, then “ok both work now”
after the left test. That corroborates the device feedback with physical results.

## Implementation and verification

`control_wire.py` implements original restricted status/position formats.
`control.py` adds a separate explicit control lifecycle using the existing
target, bond, firmware and authentication checks. The existing authentication
API still emits only 112/113; its default codec remains restricted. The public
CLI remains offline-only.

The combined spike suite passes **253 tests**. The offline capture comparison
checks **818 messages across seven recordings**, including byte-identical
request encodings. Synthetic failures cover preflight, wrong keys, malformed
responses, missing/reordered completion, position mismatch, cancellation,
cleanup and no motor replay. See [the control model](../spikes/002-local-enrollment/CONTROL.md).

Private evidence is ignored and local under `private/continuation/`:

- `20260915T072855353882Z-control-capture-verification/`
- `20260915T072930213716Z-auto-max-right-status/`
- `20260915T073053392302Z-auto-max-right-position/`
- `20260915T073117441896Z-auto-max-left-position/`

Each live folder contains its summary, raw characteristic fragments and
independent verification. Credentials, identities and proprietary evidence
remain private. No phone backup, iPhone HCI capture, Nordic operation, reset,
key replacement, debugger or firmware operation occurred during this test.
No files were staged, committed or pushed.

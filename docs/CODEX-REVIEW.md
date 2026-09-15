# Codex takeover review

> Historical research checkpoint. For current capabilities, test totals and remaining work, see [Project status](STATUS.md). Statements below describe the evidence available at the checkpoint date.

**Motor control verified, September 15 07:31 UTC:** OpenAdapt authenticated and laced both owned Auto Max shoes using their current keys, without reset. Both 80% targets have verified completion/readback and clean disconnects; the owner confirmed both physically worked. The combined suite passes **253 tests**. **The owner asked to stop for the night; do not send more shoe commands until they return ready.** Fresh enrollment and Huarache support remain unproven. See [the motor-control report](AUTO-MAX-MOTOR-CONTROL.md). Earlier checkpoints below are historical.

**Live Auto Max authentication verified, September 15 07:13 UTC:** OpenAdapt authenticated with both owned shoes using the recovered current keys. Both 12-fragment transcripts independently verify the 112/113 exchange and final shoe ACK; both shoes disconnected cleanly and both laptop bonds remain intact. The observed 20-byte, zero-padded firmware field is now accepted explicitly; **202 tests pass**. The encrypted backup refresh and Nike-only extraction are complete. Fresh enrollment after reset, Huarache authentication and motor control remain unproven. See [the live authentication report](AUTO-MAX-HOST-AUTHENTICATION.md). Earlier dated checkpoints below describe prior states.

**Latest implementation checkpoint, September 14 03:45 UTC:** explicit Auto Max setup and authentication compatibility are implemented and verified offline. All 18 known-key actual-session replays succeed; both raw setup transcripts consume all 89 fragments with all 44 outgoing fragments byte-identical. The first authentication uses the static setup key, and the owner confirmed one button press per shoe. The hardware-capable existing-key profile checks family 004 and reads exact firmware 2.4.3M before Nike subscription/write; no hardware authentication has run. Four post-enrollment exchanges still need the current keys. The enrollment suite passes **198 tests**. A separate local encrypted-backup clone is prepared; its refresh preflight found no USB iPhone and stopped before starting. Owner reconnection is pending; no phone backup refresh or hardware authentication has occurred. See [protocol verification and remaining work](ENROLLMENT-PROTOCOL-VERIFICATION.md).

Reviewed September 12–13, 2026 (Pacific), in the saved project directory. No subagents were used.

## Discovery cleanup: accepted within the documented limits

The imported fix keeps the operation deadline in `asyncio.run`'s main task and repeatedly shields the same cleanup task. An operation timeout followed by one SIGINT therefore cannot propagate cancellation through an unshielded second await or cause runner shutdown to cancel cleanup prematurely. Cleanup retains one separate timeout budget. Its own errors/cancellation are recorded with the cleanup phase, and waiter cancellation is propagated after cleanup finishes.

The 16 new subprocess cases cover scan-stop/disconnect, deadline before/during cleanup, and success/error/timeout/self-cancellation. All 37 discovery tests passed in a newly created local environment. Source and tests still match Hermes's fixed working files. No discovery code change was necessary.

This is a cooperative asyncio guarantee. Repeated forced interrupts, a blocked OS/backend, SIGKILL and storage failure remain outside it. Tests do not establish that a real adapter always disconnects successfully.

## Enrollment snapshot: incomplete, with confirmed transport defects

At import it contained four modules and 64 passing component tests. There was no handshake state machine, live BLE lifecycle, CLI, protocol document, end-to-end simulation or completed independent review. The passing suite exercised only a one-fragment transport round trip.

New regressions reproduced these failures before fixes:

- A 256-byte public-key request sent all 14 fragments without waiting for the transmit window; incoming flow-control ACKs were rejected as malformed data.
- Timeouts/cancellation/write failures left the transport reusable. A stale queued response could satisfy a new request, and concurrent requests could compete for responses.
- Notification overflow escaped the callback, and timeout values could disable the intended bounds.
- A malformed complete response could receive a final flow ACK before its schema was rejected.

The transport now enforces window/ACK sequence checks, one outstanding request, bounded notification delivery, response matching, and terminal failure without replay. Sixteen failure-path cases passed after these changes.

An original one-attempt session core distinguishes existing-key authentication from explicit enrollment, checks the peer nonce proof, preserves an `UNVERIFIED` derived candidate before authentication, and closes on error/cancellation. Eleven session tests cover success, bad keys/proofs, storage failures, interrupted authentication and no automatic retry. The four-group synthetic peer/self-test and sequence-wrap/CLI checks initially brought the enrollment suite to 96 tests; the later lifecycle work below increases it to 134.

## Readiness decision: no live enrollment or reset yet

The CLI is offline-only. Before live use the project still needs:

1. Independent review of the newly implemented existing-key BLE adapter. Exact owned-target selection, existing local bond requirements, bounded connect/subscribe/write/disconnect and fake-backend cancellation tests are now implemented; hardware authentication and live enrollment are not.
2. Independent review of the finished handshake/transport and key-file failure/recovery behavior. This takeover review is not an independent review of the code added in this same turn.
3. Firmware evidence for flow ACK/window behavior, nonce proof contents, DH provider encoding, physical-confirmation events and key commit/retention semantics. Strict event rejection currently prevents progressing any flow that requires such an event.
4. An owner-approved preservation plan and a precise one-shoe experiment. Existing-key authentication needs a legitimate existing application key. Enrollment cannot recover that key and must not be used as a probe.

Any future one-shoe test must identify the owned target privately, keep the shoe empty, stop at unexpected bonding/confirmation/errors, preserve existing/candidate keys, and disconnect after the agreed handshake. Reset, retries, actuator commands and automatic post-authentication queries are separate decisions. These are preparation boundaries, not instructions to execute a test now.

## Later existing-key lifecycle review

After the owner authorized testing either available shoe, both Auto Max shoes passed the unchanged discovery CLI's standard reads. `ble_link.py` adds a restricted existing-key connection path: key validation before radio access, fresh exact owned-target selection, pre-existing BlueZ paired/bonded properties, fixed unambiguous command/notification characteristics, no automatic pairing/enrollment, and no post-authentication commands. It closes the transport before cleanup, preserves disconnect cleanup across repeated cancellation, and reports cleanup timeouts or false backend disconnect success. A callback arriving from an unexpected thread fails closed with at most one scheduled fault callback.

Thirty-eight new synthetic lifecycle tests pass; the enrollment suite is now 134 tests. Review also added a Linux-only default-backend boundary and explicit local-bond check because `pair=False` alone is not an assurance about automatic security behavior on every platform. The module checks the installed BlueZ scanner's device-properties representation; unsupported/missing bond properties stop the attempt. This remains author review, not independent review or hardware proof. No real application key is available, and the lifecycle was not invoked against either shoe.

## Hermes reconciliation and repository state

Read-only inspection found no source delta at takeover. The latest scoped parent message was 2823 and the latest task list remained revision 42. Enrollment child transcripts ended during implementation/audit; the promised audit `REPORT.md` was absent. Partial DEX/encoding evidence exists, but it is not a completion report. The source-hash reconciliation is retained in ignored `private/hermes-handoff/codex-reconciliation.json`.

The Codex repository still has an unborn `master`, an empty index and no commit/push. Original Hermes source and index were untouched. A later initial publication must review the actual staged source and recheck private remote visibility before pushing.

## Separate continuation review, September 13 afternoon

The owner moved continuation to a fresh Codex task and became available for hardware assistance. This task reviewed the pre-existing lifecycle, handshake, codec, transport and key-store source, checked the installed Bleak 2.1.1 BlueZ implementation, and reran both baseline suites: 134 enrollment and 37 discovery tests passed.

One concrete preservation defect was reproduced: the lifecycle accepted a target whose BlueZ `Connected` property was true or unavailable. Bleak's `connect()` adopts an already-open local connection in that case, and the lifecycle's later `disconnect()` can tear down the existing session. Three new synthetic cases failed against the old lifecycle. The fix requires `Connected` to be exactly false before constructing a client; all **137 enrollment tests** pass afterward. This is a preflight check, not exclusion against another process racing to connect. Future hardware work still needs one active local investigator.

The backend inspection also distinguishes application behavior from backend behavior: Bleak may internally retry `le-connection-abort-by-local` before returning from `connect()`. The prototype does not replay the application handshake or call enrollment. Do not describe that policy as a guarantee of exactly one underlying radio connection attempt.

The archived app's subscription-ready flag is set by its GATT descriptor-write callback (`ic/g.java`, `onDescriptorWrite`, calling `hc/l.java`, `O`); this is distinct from the opcode-111 event routed by `hc/e.java`. Treating every readiness signal as a request for physical confirmation would be incorrect. The archived app mapping alone still does not establish the physical-confirmation or key-commit rules of either shoe firmware. No event acceptance or live enrollment path was enabled.

This separate review provides a concrete lifecycle finding and fix. It does not close the remaining candidate-file crash-recovery and protocol/firmware evidence work or establish hardware authentication. The correction was reviewed and tested within this continuation task; no subagent was used.

### Vault-parent durability follow-up

During the later authorized iPhone backup, review found that creating the private vault directory did not sync its parent directory. Syncing the key file and the vault alone does not establish durability of a newly created vault's name in its parent. `private_directory(create=True)` now syncs the parent before opening the vault, including when it already exists so a retry after an earlier sync failure cannot skip this step. Failure stops before creating any key or pending record.

A synthetic parent-directory sync failure reproduced the missing check against the old code, then passed after the change; the full enrollment suite passes **138 tests in 0.99 seconds**. This is an injected I/O failure regression, not a physical power-loss experiment. Interrupted hard-link publication may still leave both canonical and `.pending-*` names; recovery and key-commit semantics remain unresolved, and live enrollment remains disabled.

## Original-app authentication replay

The later Nike-only encrypted-backup inspection recovered both Auto Max application keys and validated each against the original app's opcode 113 AES response and final ACK. Feeding the captured nonce/response into the actual `Session.authenticate_existing` code still fails before opcode 113 on both shoes: the added full-block peer-proof check is incompatible with these recorded exchanges. Decryption preserves the final 12 nonce bytes but changes the first four. The inspected Android client does not check this field. The cause and appropriate verification rule remain unresolved; the prototype check was not removed or weakened. This is a concrete blocker that synthetic tests did not reveal. See [saved-key evidence](IPHONE-KEY-FINDINGS.md).

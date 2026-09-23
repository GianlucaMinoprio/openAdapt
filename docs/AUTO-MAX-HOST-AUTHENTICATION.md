# Auto Max authentication from OpenAdapt

> Historical research checkpoint. For current capabilities, test totals and remaining work, see [Project status](STATUS.md). Statements below describe the evidence available at the checkpoint date.

September 15, 2026, 07:12–07:13 UTC. OpenAdapt's existing-key implementation successfully authenticated with both owned Auto Max shoes over the laptop's Bluetooth connection. Each shoe acknowledged the client proof, notifications were stopped, and the connection was closed. Both local Bluetooth bonds remained intact.

This demonstrates independent application authentication using recovered credentials. Fresh enrollment after a reset, Huarache authentication, and replacement motor control remain unproven.

## Verified hardware results

| Shoe | Attempt started UTC | Elapsed, including scan and cleanup | Recorded characteristic fragments | Result |
|---|---|---:|---:|---|
| Right | 07:12:15.408 | 12.020 s | 12 | Authentication acknowledged; disconnected |
| Left | 07:13:06.093 | 10.292 s | 12 | Authentication acknowledged; disconnected |

The owner confirmed the shoes were awake and Nike Adapt was fully closed. Each attempt required the exact previously confirmed address, fresh Nike advertisements matching the privately saved Auto Max name (family 004), a saved local Bluetooth bond, an explicitly disconnected target, and the supported firmware revision.

A separate offline verifier reassembled each recorded transcript. Both contain exactly one opcode-112 request/reply and one opcode-113 request/reply, plus transport flow acknowledgments. It verified the 96-bit peer challenge, the client's AES proof and the final shoe ACK. No additional application message was present. These are live exchanges with fresh client nonces, distinct from replaying the iPhone recordings.

Each final BlueZ check reported both shoes disconnected and their Paired/Bonded properties still true. Trusted and Blocked properties were unchanged across the attempts. The right shoe was already Trusted on this continuation; the runner did not set that property. Both attempts reported zero cleanup errors. No pairing, enrollment, reset, actuator, light or firmware-update operation was invoked by the runner. Preservation of the iPhone's operation after these attempts has not been separately retested.

## Firmware-format correction

An earlier right-shoe attempt connected successfully but stopped before Nike subscription or writes because the firmware check required an unpadded byte string. A read of BlueZ's cached characteristic value established that the shoe returned `2.4.3M` followed by fourteen zero bytes, a 20-byte field. Obtaining that cached value did not make another connection.

The explicit Auto Max profile now accepts the unpadded revision or exactly that observed 20-byte encoding. It does not strip arbitrary suffixes or accept other versions or widths. The full enrollment suite passes **202 tests in 1.49 seconds**, including the padded-version success case and rejection of another padded version, an unsupported width and nonzero padding. The authentication proof and transport policies were unchanged by this fix. The public CLI remains offline-only.

Before the owner woke the shoes, a discovery-only attempt had found no exact right target and sent no characteristic fragments. That result and the firmware-gate stop remain preserved separately from the two successful attempts.

## Current credentials and backup

The prepared isolated backup clone was refreshed successfully after the iPhone update. Completion checks found exit 0, `Backup Successful`, a finished encrypted snapshot, `IsFullBackup: false`, iOS 27.0 metadata and unchanged original backup metadata. The incremental refresh received 17,080 files in 1,300 seconds.

After local password entry, extraction read only Nike Adapt's 3,077-byte saved-device database. No keychain or other-app files were extracted; no temporary decrypted files remain. Both current Auto Max keys match all four post-enrollment original-app exchanges, including the actual-session replays. Combined with the earlier 18 known-key replays, all 22 complete original-app exchanges now have matching credentials. The backup password was not retained.

## Private evidence

- Key validation: `private/iphone-backup/20260914T034321Z/saved-devices-20260915T070750Z/key-validation-20260915T070844696008Z/`.
- Right live attempt: `private/continuation/20260915T071215408569Z-auto-max-right-existing-key-auth/`.
- Left live attempt: `private/continuation/20260915T071306093717Z-auto-max-left-existing-key-auth/`.
- Each live directory contains a sanitized lifecycle summary, owner-only characteristic fragments and `transcript-verification.json`.
- Continuation checkpoint and synthetic runner/verifier checks: `private/continuation/20260915T064400Z-current-key-recovery/`.

All credentials, identifiers and raw captures remain ignored and local. Nothing was staged, committed or pushed. Backup, password-dialog and Bluetooth test processes finished.

## Remaining work

Fresh pairing must eventually create and retain OpenAdapt's own keys. The observed setup-key authentication, 110/111 public exchange and subsequent authentication have an offline model, but the host enrollment path has not run on a shoe. Candidate crash recovery, the shoe's key-commit/retention behavior and a real DH derivation result remain unresolved. This result does not authorize another reset or enable live enrollment.

The owner's earlier 80/80 request remains unexecuted. Authentication is now demonstrated for Auto Max; a control implementation still needs the current fit calibration, verified position conversion and the owner's current empty-shoe setup. The earlier calibration and position observations predate the completed reset and fit check. Huarache keys still need matching original-app evidence before selecting any Huarache compatibility policy.

# First-setup fit calibration: existing evidence

September 22, 2026. Read-only analysis of the existing Omarchy recordings and archived original-app implementation. No phone or shoe connection, reset, calibration, motor command, or setting change was performed. Raw recordings and proprietary source/disassembly remain private.

## Conclusion

The original app runs a distinct fit check after pairing. It learns a maximum position from each shoe's movement completion and stores those values in its pair profile. Connection/authentication alone is not calibration, and this recording does not establish a separate command for reading a saved calibration maximum from the shoes.

We already have the normal-path capture needed to begin an original calibration implementation. A new reset recording is not necessary just to recover that sequence. OpenAdapt still needs its own implementation, failure handling, and owner-operated validation before enabling fit on newly paired shoes.

## Recording examined

The [successful original-app setup and fit check](../ORIGINAL-APP-ENROLLMENT-CAPTURE.md#successful-new-profile-setup-and-fit-check) was recorded September 13 Pacific / September 14 UTC. This audit inspected its final aligned decode on Omarchy: **452 complete Nike messages**, zero decoder problems and no unfinished messages. The raw PacketLogger file's SHA-256 matches the value recorded in the original report.

The fit-check interval is approximately **03:18:24–03:18:35 UTC** in the aligned timeline. Intra-capture durations below come from packet timestamps; wall-clock alignment retains the original report's uncertainty. The established capture mapping is shoe_1 = right and shoe_2 = left.

| Step | Left | Right |
| --- | --- | --- |
| Auto-Lace off (82), acknowledged | 03:18:24.033 | 03:18:24.034 |
| Initial loosening | Stop (0), raw target 2 (3), completion status 0 at position 1 | Earlier position read returned 0; no additional loosening command in this interval |
| Stop before maximum search, acknowledged | 03:18:25.241 | 03:18:25.242 |
| Absolute raw target **100** (3), acknowledged | 03:18:25.297 | 03:18:25.292 |
| Completion event (5) | 03:18:30.366; **status 4, position 61** | 03:18:30.839; **status 4, position 65** |
| Time from maximum request to completion | 5.069 seconds | 5.547 seconds |
| Auto-Lace on (82), acknowledged after both results | 03:18:30.861 | 03:18:30.862 |
| Subsequent fit adjustment | Raw target 25; status 0 at position 24 | Raw target 29; status 0 at position 28 |

The two maximum-search requests start about 5 ms apart and finish independently. Every off/Stop/maximum-request/on transaction in the table has a matching empty ACK before proceeding to its subsequent observed result. ACK and movement completion remain distinct.

The raw target of 100 belongs to the recorded maximum-search procedure. It is **not** a normal calibrated 100% request, and the recording is not an instruction to replay it through the current fit controls. Status 4 is corroborated as the result used for this particular fit check; its meaning across all errors, models, or firmware is not established.

The later [motor-control verification](../AUTO-MAX-MOTOR-CONTROL.md#scope-and-results) independently matched these 61/65 positions to the maxima recovered from the original app's saved profile. They are this pair's historical results, not defaults for another pair or a future reset.

Opcode 85 (`FPS_CALIBRATE` in the archived opcode table) is absent from this setup recording. Do not confuse the fit check with a separate foot-presence sensor calibration command. Opcode 2 preset reads also remain distinct: they return raw 46 for both shoes before and after this fit check, not the discovered 61/65 maxima.

## Original-app implementation cross-check

The archived Android app supplies corroborating semantics for the iPhone wire trace, not proof that every platform has identical behavior. Critical control flow was checked against DEX bytecode as well as the decompiled source.

- The calibration helper has separate states for disabling Auto-Lace, moving toward zero, searching for a maximum, reporting each result, enabling Auto-Lace, and completion. Its overall timer is 40 seconds.
- When a shoe is already at raw position 0 or 1, the helper can skip its initial zero movement. It waits for both shoes to be ready before requesting raw 100 on each. The Android helper requests raw 0 when loosening; the iPhone capture requests raw 2 and completes at 1. This difference remains explicit rather than assuming byte-identical platform behavior.
- The helper waits for both maximum results and emits each separately. The profile listener updates each shoe's `maxTightness`, then passes the updated pair to its repository. The observed protocol does not show a separate maximum-write command to the shoes.
- The Android movement-event adapter passes the position into calibration without preserving the completion status. Its helper also clamps very low reported maxima up to 10. These are reference behaviors to review, not validation rules OpenAdapt should inherit blindly.
- Cancellation in the helper unregisters callbacks and cancels its timer. That alone does not prove a physical Stop was sent or Auto-Lace restored on every interruption; UI helpers may perform additional cleanup. OpenAdapt must define and test its own bounded cleanup and must not claim a disconnected motor has stopped.
- The Android onboarding resources ask the wearer to put on the shoes and reject shoes left on their charger. The captured iPhone app log has no explicit calibration marker, so exact screen-to-packet timing and the wearer's physical actions are not independently reconstructed here.

Private source anchors: `fb/o.java` and its extracted bytecode (state machine), `w9/x.java` inner class `l` and corresponding bytecode (profile update), `hc/e.java` and its bytecode (movement event), `gc/a0.java` (event fields), `ea/b.java` (stored maximum), and the `i9` onboarding views/resources. No proprietary implementation or raw excerpt is included in this report.

## Consequences for OpenAdapt

1. Add an explicit calibration operation after both pairing credentials are saved. Ordinary fit commands must keep their existing calibration prerequisite and status-0 completion policy. Do not globally accept status 4 as ordinary movement success.
2. Make physical preparation and starting calibration explicit. Keep charger, battery, connection, and firmware checks; keep each result bound to its shoe and the current calibration attempt.
3. Model loosening, maximum search, per-shoe completion, and verified profile persistence separately. Reject invalid results rather than inventing or copying maxima. Add position readback where supported to corroborate completion; a position read alone is not a calibration getter.
4. Preserve pairing on calibration failure and keep unfinished fit controls unavailable. Test cancellation, timeout, radio loss, one-sided completion, stale notifications, and profile-save failure. Auto-Lace restoration needs an explicit policy because the current app stores a preference, not an authoritative enabled-state readback.
5. Export the verified per-shoe limits through the existing pairing-file format so Omarchy can use them. Reconnect, app restart, and shoe power-cycle tests must establish persistence on hardware.

An additional original-app capture is only needed if a specific unresolved behavior blocks implementation—for example, cancellation cleanup or the iPhone zero-target choice. The normal sequence and the source of the stored fit limits are now documented. No calibration feature was enabled by this investigation.

## Private audit artifacts

New derived evidence is stored under the working copy's ignored `private/calibration-research/20260922/` on Omarchy. It includes a numeric-only capture audit and targeted DEX extracts. The original research archive and recordings were read without modification. The audit asserts the original capture hash, message completeness, per-shoe request/ACK ordering, status-4 results, matching maxima, and the absence of opcode-85 requests.

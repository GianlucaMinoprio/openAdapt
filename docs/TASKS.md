# openAdapt tasks

Updated September 22, 2026. Current evidence is summarized in [STATUS.md](STATUS.md) and [new-shoe readiness](ios/NEW-SHOES-READINESS.md). Completed hardware work does not authorize repeating it.

## Completed

- [x] Import and reconcile the original research into an independent working copy.
- [x] Implement and test bounded discovery, existing-key authentication and explicit Auto Max protocol compatibility.
- [x] Validate the current Auto Max keys against recorded app exchanges and successful host authentication.
- [x] Verify empty-shoe lacing on both owned Auto Max shoes, including owner confirmation.
- [x] Build the Omarchy panel with theme-reactive sneaker artwork, lacing sliders, base colors, Battery and Lights off.
- [x] Replace Preview with saved-pair selection and persistent authenticated connections.
- [x] Verify session reuse and owner-requested Disconnect while retaining existing bonds.
- [x] Run the initial source checkpoint's offline checks: 374 Python tests and 14 Qt test results.

## Next session

The owner wants a complete first-time Auto Max setup, including fit calibration, before relying on a reset pair in OpenAdapt. Pairing and calibration are separate: a successful connection does not establish a usable fit maximum. The iOS enrollment flow and candidate journal pass offline/Simulator checks, but newly enrolled profiles deliberately keep calibration unknown and block app fit commands.

### Calibration investigation and setup plan

1. **Analyze the existing original-app recording first.** The [September 13/14 setup capture](ORIGINAL-APP-ENROLLMENT-CAPTURE.md#successful-new-profile-setup-and-fit-check) includes the owner's completed fit check and subsequent configuration/position traffic. The later [motor-control verification](AUTO-MAX-MOTOR-CONTROL.md#scope-and-results) checked recovered per-shoe maxima against fit-check completion events. Those results do not yet establish the complete calibration procedure or a supported readback path; a new recording is not automatically necessary.
2. **Reconstruct the full calibration exchange.** Identify the trigger, instructions shown by Nike Adapt, each shoe's start/progress/completion messages, returned fit limits, storage location, and any subsequent readback. Distinguish calibration from ordinary position commands, saved fits, and the Auto-Lace preset. Determine whether the shoe calibrates itself and reports results or requires a separate app-controlled procedure; do not assume connection alone performs it.
3. **Capture only missing evidence on the original phone.** If existing logs cannot answer those questions, prepare a bounded Bluetooth recording with screen/action timing while the owner follows Nike Adapt's fit-check flow. Confirm actual radio packets before starting. Prefer its existing Calibrate Fit flow if it can answer the gap without another reset; a new reset/setup experiment remains an explicit owner-operated step.
4. **Implement and test the verified protocol.** Add original codecs and synthetic tests for both feet, distinct maxima, invalid/incomplete results, timeouts, cancellation, disconnects, and interrupted recovery. Keep unknown calibration blocked and do not reuse pre-reset maxima or turn authentication success into calibration success.
5. **Add a guided fit check after pairing in iOS.** Save both verified credentials first, then guide the user through the required physical steps and confirm each shoe's calibration. Preserve pairing if calibration fails, and allow an explicit resume/retry without enrolling again. Enable a shoe's fit controls only after its calibration is verified; paired actions require both ready. Persist the verified limits and include them in pairing exports so Omarchy can use the same profile.
6. **Validate the full flow on hardware.** Establish pairing → calibration → bounded fit control, then app restart, shoe power-cycle persistence, and export/import to Omarchy. Confirm the actual UI percentage mapping and command readback before claiming complete fresh-shoe support.

Until this is verified, new pairs use their physical buttons for fit; app battery/light control is available after authentication. See [first-time pairing](ios/FIRST-PAIRING.md). This planning update performed no reset, calibration, or shoe command.

## Remaining

- [x] Implement and install Omarchy Fit / Lights / Battery / Modes, centered linked-fit control, 5% bar marks, saved modes, Tie/Untie and successful-pair history; pass offline/native UI checks.
- [ ] Collect owner feedback on the updated panel's physical progress timing and pair-wide commands.
- [x] Run Omarchy pair connection and controls concurrently, with a shared scan, independent outcomes and drained cancellation; pass 410 protocol/backend tests.
- [x] Install the concurrent-pair update on idle Omarchy, run all 410 tests on Linux, verify one new controller and radio-free panel opening, and retain a rollback backup.

- [x] Add Developer-mode export of a completed iPhone pair and Omarchy import with backups, identity matching and unknown-calibration protection.
- [x] Install the updated Omarchy client including pairing-file import when the desktop became reachable and idle.
- [ ] Validate the native pairing-import dialog and owner-operated post-reset transfer/local Bluetooth bond with an exported pair.

- [ ] Validate physical LED appearance and perceived control latency with owner feedback.
- [ ] Establish fresh-enrollment candidate recovery and shoe key-commit/retention behavior before a concrete owner-authorized hardware experiment.
- [x] Implement automatic two-shoe setup, side/model detection, button prompts, candidate persistence, verification, and native profile publication.
- [x] Simplify first-time pairing to one large shoe and sequential physical confirmation, with a detected opposite-side prompt, larger-text scrolling, and VoiceOver focus.
- [ ] Analyze the captured Nike fit check, fill any evidence gaps, and implement guided post-pairing calibration with verified limits persisted for iOS and Omarchy export.
- [ ] Validate this enrollment flow on hardware and establish calibration readback before enabling app fit controls for new pairs.
- [ ] Validate Huarache credentials and firmware behavior before enabling that model.
- [ ] Investigate exact original-app percentage rounding and worn-shoe behavior.
- [ ] Extend beyond base colors to verified animation support.
- [x] Implement the native iPhone controller, private local owner defaults, and offline protocol tests.
- [x] Add native guided setup/help, disabled connecting state, an Omarchy-derived sneaker mark, and reviewed gesture/motion polish.
- [x] Authenticate both current Auto Max shoes and read their status through the native iPhone client.
- [x] Diagnose the September 22 saved-pair write-queue stall; use supported acknowledged writes and verify both physical shoes reconnect with the existing keys.
- [ ] Validate physical iPhone motor/light behavior and Siri, then prepare signed public distribution.
- [x] Add App Intents and nine Siri/Shortcuts actions with confirmed completion, background execution, remembered-peripheral connection, and offline tests.
- [x] Automatically reconnect the last successfully connected pair when opening the iPhone app, with a bounded attempt and Cancel; keep browsing, partial results, and failed attempts from replacing the default.
- [x] Add parameter-free Tie Shoes using the last confirmed saved mode, concise replies, and an in-app guide for natural personal shortcut names.
- [ ] Validate Siri recognition and background command completion with the owner’s physical shoes.
- [x] Simplify Siri setup to two everyday actions and Help; add native Liquid Glass top controls, cleaner Settings, Debug-only shoe details, and the repository link.
- [x] Implement firmware inspection that does not authenticate or enable commands for unknown versions; add strict parsing and compatibility tests.
- [ ] Validate firmware inspection on a new physical pair and establish compatibility for any other observed version.
- [x] Add My shoes cards without repeated names, connected/disconnected detail pages, local nickname/appearance changes, native removal confirmation, five retail model names, and the animated Add shoes flow.
- [x] Implement auto-lace Enable/Disable with per-shoe connection-scoped confirmations and synthetic success/failure tests.
- [x] Match exact auto-lace and gesture vectors from the supplied Omarchy report; correct auto-lace false to omit its proto3 field.
- [x] Implement gesture readback and double-tap activation with preflight, acknowledgement, readback, and no overwrite of unfamiliar/multiple mappings.
- [ ] Verify physical auto-lace/gesture behavior and power-cycle persistence; establish auto-lace enabled-state readback.
- [x] Simplify Auto-Lace, Quick Unlace, and colors to pair-wide controls; remember the last fully acknowledged Auto-Lace preference, defaulting off.
- [x] Implement schema-derived Quick Unlace off with preflight, successful acknowledgement, and exact matching readback.
- [ ] Validate physical Quick Unlace off, obtain a captured disable transaction, and establish multi-mapping replacement semantics before supporting additional gesture configurations.
- [ ] Establish shoe-stored preset-write and display mapping evidence before implementing step-in fit selection.
- [ ] Establish trusted firmware availability, exact hardware targeting, transfer/install behavior, and recovery before implementing OTA.

## Publication

The owner requested pushing all current iPhone and Omarchy updates on September 22. Review actual staged contents, omit private/proprietary evidence, verify offline checks and confirm the remote result. The repository remains private. Public release remains a later decision. Do not describe this project as the first of its kind without evidence.

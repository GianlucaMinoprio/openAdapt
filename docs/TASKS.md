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

The owner wants to test adding a factory-reset Auto Max. The iOS enrollment flow and candidate journal are now implemented and pass offline/Simulator checks. Next establish owner-operated physical enrollment, restart/reconnect, and shoe power-cycle persistence. A newly enrolled pair lacks verified fit calibration, so it uses physical buttons for fit; app battery/light control is available after authentication. See [first-time pairing](ios/FIRST-PAIRING.md). No hardware reset or enrollment experiment was run by development tools.

## Remaining

- [x] Implement and install Omarchy Fit / Lights / Battery / Modes, centered linked-fit control, 5% bar marks, saved modes, Tie/Untie and successful-pair history; pass offline/native UI checks.
- [ ] Collect owner feedback on the updated panel's physical progress timing and pair-wide commands.
- [x] Run Omarchy pair connection and controls concurrently, with a shared scan, independent outcomes and drained cancellation; pass 410 protocol/backend tests.

- [x] Add Developer-mode export of a completed iPhone pair and Omarchy import with backups, identity matching and unknown-calibration protection.
- [x] Install the updated Omarchy client including pairing-file import when the desktop became reachable and idle.
- [ ] Validate the native pairing-import dialog and owner-operated post-reset transfer/local Bluetooth bond with an exported pair.

- [ ] Validate physical LED appearance and perceived control latency with owner feedback.
- [ ] Establish fresh-enrollment candidate recovery and shoe key-commit/retention behavior before a concrete owner-authorized hardware experiment.
- [x] Implement automatic two-shoe setup, side/model detection, button prompts, candidate persistence, verification, and native profile publication.
- [x] Simplify first-time pairing to one large shoe and sequential physical confirmation, with a detected opposite-side prompt, larger-text scrolling, and VoiceOver focus.
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

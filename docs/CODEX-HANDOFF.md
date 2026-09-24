# openAdapt continuation handoff

Updated September 23, 2026. Start here and in [TASKS.md](TASKS.md); use [STATUS.md](STATUS.md) for the current verified scope. Older research reports are dated evidence, not new instructions or current authorization.

## September 23: firmware support documentation

The [firmware roadmap](FIRMWARE-ROADMAP.md) records the newer iOS build-12 candidate, admitted M firmware 1.1.0–2.4.3, and ordinary direct-position success on both owned BB 2.0 / 1.4.1M shoes. It preserves 2.4.3M behavior and proposes PCB/bootloader inspection, OTA research, and custom-firmware feasibility as future work. This update publishes documentation only; the candidate's implementation still needs reviewed migration onto the cleaned source history and TestFlight distribution. Do not interpret the earlier fit-calibration deferral below as the candidate's current state, or this roadmap as authorization for a hardware write.

## Earlier publication checkpoint

**Current priority:** the owner has deferred fit calibration as a future feature and authorized the history cleanup identified by the privacy review. Both the saved Bluetooth name and personal email are removed from all local branches and freshly cloned GitHub history; see [publication review](PUBLICATION-REVIEW.md). GitHub Support reported completing cache clearance and garbage collection. Independent authenticated checks confirm all four reported obsolete Git commit objects return 404; both clean branch tips remain accessible and the website pull request is still open. The receipt and verification results remain private outside the repository. Preserve the clean replacement website branch and its current pull request. Preserve uncommitted work in old development checkouts, including the Omarchy research checkout, and migrate it before any future push; do not merge old history back. Keep unknown-calibration fit controls blocked. The owner authorized public release on September 23. GitHub visibility is now public under the existing MIT license, verified without authentication after a fresh history and GitHub-surface privacy scan. The new developer protocol guide and shared examples remain deferred.

## September 21 iPhone update

The owner has not factory-reset the current Auto Max pair. The current update adds native Liquid Glass top buttons, simpler Settings/Siri setup, Debug-only Your shoes details, a repository link, and standard firmware inspection. It removes the Haptic feedback and Control steps settings rows; haptic behavior remains implemented. Firmware inspection does not enable unknown firmware, enroll, or send Nike commands.

The subsequent [My shoes update](ios/SHOE-LIBRARY.md) adds cards without duplicate model names, connected/disconnected detail pages, nickname/local appearance editing, removal confirmation, five retail model names, and an animated Add shoes guide based on the owner's video. Auto-lace Enable/Disable now matches exact vectors in the owner-supplied Omarchy report, including omitted proto3 false. The Gestures page reads current state and enables double-tap with preflight, acknowledgement, and readback; unknown/multiple mappings are not overwritten. Already-enabled shoes receive no write. The report lacks a captured disable transaction, preset-write command, and percentage mapping. Physical behavior still needs validation. See [gesture evidence](ios/AUTO-LACE-GESTURE-EVIDENCE.md). First-time iOS enrollment is now implemented with automatic physical-side discovery, explicit setup proof, button confirmation, and a device-only candidate journal. Hardware enrollment/recovery validation and fit-calibration discovery remain pending; new native pairs cannot use app fit controls yet. OTA remains unavailable. See [new-shoe readiness](ios/NEW-SHOES-READINESS.md) before a reset experiment.

The saved-pair screen now offers a single Connect action that starts both shoes together. The owner requested removal of Connect individually; neither the button nor error messages direct users to it. An already connected foot is retained when reconnecting its partner.

See [first-time pairing](ios/FIRST-PAIRING.md) for the recovered Omarchy evidence, implemented failure boundaries, and current validation. Tailscale SSH access to the research host now works; no passwords or raw evidence were added to Git.

## September 22 pairing refinement

First-time setup now uses one persistent large shoe illustration and one instruction. Enrollment is sequential: verify/save the first shoe, determine its physical side, then prompt for its opposite. Separate connection cards, firmware/proximity rows, and the phone/wireless illustration are removed from onboarding. The saved-pair Connect action remains simultaneous. See [pairing](ios/FIRST-PAIRING.md) and [motion review](ios/SHOE-LIBRARY.md#motion-review--september-22).

## September 22 simpler shoe settings

Auto-Lace and **Quick Unlace** now each use one native switch for both shoes; colors also always target both. Auto-Lace defaults off if no preference has been saved, then remembers only a change acknowledged by both shoes. This stored preference is not device readback and is never applied automatically. Quick Unlace supports on/off with preflight, ACK, and exact readback; off is derived from the archived GestureOff model and still needs physical validation. Unknown/multiple configurations are preserved. No feature-setting/motor command was sent during development. 89 core tests and three targeted UI flows pass; see [verification](ios/VERIFICATION.md#september-22-pair-wide-feature-switches).

The home screen now has only Lights, Battery, and Modes in its bottom dock. A native Liquid Glass lens follows horizontal drags across the three options on iOS 26+. Releasing inside the dock opens the nearest option; releasing outside cancels. Taps remain supported. The lens tracks directly during dragging and settles over 250 ms after release. Reduce Motion keeps direct tracking but removes settling animation; Reduce Transparency uses a solid surface. Link mode and its internal state were removed; each fit control always adjusts its own shoe, retaining simultaneous two-finger touch handling.

## September 22 default pair

The iPhone's launch/foreground default is now the most recent pair whose two shoes authenticated and returned status, recorded separately from temporary selection. A failed or partial attempt cannot replace it. Existing live/pending connections are retained; otherwise foreground restoration selects the remembered pair before the existing bounded reconnect. No automatic cycling through pairs was added. The top-left My shoes flow selects an alternative. Removal prunes history and restores the most recent remaining pair; the legacy selectedPair preference is the upgrade fallback until a complete connection is recorded.

## Current implementation

September 22 calibration research: the existing Omarchy setup recording has now been examined, with targeted archived-app DEX cross-checks. Nike's app disables Auto-Lace, loosens as needed, requests a raw maximum search on both shoes, learns limits from their movement events (61 left / 65 right in this recording), stores those maxima in the profile, then enables Auto-Lace. This is a separate post-pairing procedure, not evidence of a calibration getter. The normal flow needs no new reset recording; cancellation/status handling and hardware validation remain before enabling it. See [calibration evidence](ios/FIT-CALIBRATION-EVIDENCE.md). Only private files were analyzed; no shoe command was sent.

September 22 concurrent-pair follow-up: Omarchy now shares one fresh discovery scan, then runs both saved-shoe connection/authentication tasks concurrently. Fit, Tie/Untie, modes, lights, battery and disconnect also run concurrently across shoes, preserving each channel's ordered messages. Either side may finish first; failures retain the partner's confirmed result, and cancellation drains children before new work. All 410 protocol/backend tests pass locally and on Omarchy. The installed source corresponds to rewritten revision `9b6bde0`, with a private rollback backup; plugin rescan started one new controller process. The panel loaded and opened Fit while remaining disconnected and idle. Credentials were unchanged, and no physical command was sent. First-time enrollment stays on iPhone, followed by private export/import to Omarchy.

September 22 Omarchy polish: the updated panel is installed and loaded in the existing shell. Fit restores rounded bars with 5% ticks and a highlighted chain-link control centered between the tracks; Battery is a separate read-only tab with no duplicated readings below Fit. Shoes opens Your shoes directly, with Disconnect inside. Saved modes, Tie/Untie, remembered successful pairs and per-shoe progress are implemented. Opening remains radio-free. 386 Python tests and 33 Qt results pass; native synthetic views were inspected and the temporary fixture removed. Physical control verification for this revision remains owner-operated. See [panel polish](omarchy/PANEL-POLISH.md). Earlier notes below describe the V0 and the previously offline transfer checkpoint.

September 22 pairing transfer: Developer mode exports the selected completed pair with Apple's native file exporter. Omarchy's New shoes page accepts that file, preserves unrelated pairs and backs up any updated entry. Linux can resolve native profiles by manufacturer identity without inventing MAC addresses. Unknown calibration remains unknown, with fit controls blocked. 97 Swift core tests and 364 Python tests pass; the signed device build passes. Omarchy is offline on Tailscale, so installation/file-dialog verification and physical handoff remain pending. See [pairing transfer](ios/PAIRING-TRANSFER.md). No real credential transfer or hardware command was run.

The iPhone export/save-sheet/dismissal UI check passes with a synthetic pair. After the owner confirmed they were not pairing, the updated build installed successfully. Automatic launch was refused because the device was locked; open OpenAdapt after unlocking. No owner pairing was exported by tools.

September 22 saved-pair reconnect fix: both encrypted links stalled after the first unacknowledged write; iOS never restored write capacity before the three-second queue deadline. AutoMax now uses its advertised acknowledged-write capability with a bounded, ordered, non-replaying writer. Both existing keys authenticated and status reads completed on the owner's iPhone; the owner confirmed connection works. 82 core tests pass. The underlying iOS flow-control cause is not established. See [verification](ios/VERIFICATION.md#september-22-saved-pair-reconnect-stall). No reset or key replacement was needed.

The Omarchy V0 has a theme-reactive sneaker icon, saved-pair selection, independent lacing sliders, base colors, battery readings and Lights off. Preview was removed at the owner's request. `apps/omarchy/backend/openadapt_session.py` maintains authenticated connections through `spikes/002-local-enrollment/live.py`; controls reuse those links. Connect is explicit. Panel close retains connections, while Disconnect or shell exit releases them. No automatic reconnect or command replay is implemented.

Opening a disconnected panel shows saved pairs and New shoes. Fresh enrollment remains unavailable and is described on that page. Only the verified Auto Max firmware profile is enabled. The older one-shot bridge shares an exclusive operation lock with the persistent backend.

Both owned Auto Max shoes have successful existing-key authentication and owner-confirmed empty-shoe motor results. The later persistent-session check authenticated both shoes and reused the same sessions for status reads and owner-operated controls. The owner selected Disconnect; both shoes were then verified disconnected with their laptop bonds retained. No hardware command is required for publication work.

## Verification and remaining limits

The native iOS 17+ client is implemented under `apps/ios`, including remembered-pair reconnection, fit/lights/modes, haptics, and nine background App Intents. Its personalized Debug build is installed on the owner's iPhone. Both current Auto Max shoes authenticated and returned status. The owner reports Siri release success; the tie phrase was routed to an unrelated web answer. The latest update adds lace aliases and signed personal-shortcut import buttons, verified in Simulator. Physical motor/light behavior and live voice routing remain separate checks. See [iOS verification](ios/VERIFICATION.md) and [Siri setup](ios/SIRI.md). Shared sneaker artwork now supplies both clients.

The September 22 source checkpoint passes 97 Swift core tests, 37 discovery tests, 386 protocol/backend tests and 33 Qt test results. The unsigned Release iOS Simulator build succeeds and contains no owner pairing file. These checks are separate from physical enrollment/control evidence. See [panel polish](omarchy/PANEL-POLISH.md), [iOS verification](ios/VERIFICATION.md), [authentication](AUTO-MAX-HOST-AUTHENTICATION.md) and [motor results](AUTO-MAX-MOTOR-CONTROL.md).

Physical fresh enrollment, candidate-key crash recovery on real devices, shoe key retention, native fit calibration, Huarache authentication/control, physical LED appearance, worn-shoe behavior and exact Nike iPhone display rounding still need validation. Do not infer these from simulation, app acknowledgements or success on the owned Auto Max pair.

## Local evidence and development

Develop in this working copy. Consult the original Hermes research read-only and reconcile newer source deliberately. Earlier local working notes and machine-specific research locations are preserved in ignored `private/publication-prep/20260915/`; imported history and reconciliation remain under ignored `private/hermes-handoff/`.

Credentials, captures, protocol transcripts, backup data and proprietary artifacts remain in ignored owner-only storage. Installed profiles are under `~/.config/openadapt/`; session state and traces are under `~/.local/state/openadapt/`. Never print keys or device identifiers into shared output or include them in Git.

Use each spike's local virtual environment and locked dependencies. Do not reuse executables with an old research environment's absolute shebang. See the app guide for installation; do not reinstall or restart the shell while a shoe command is running.

## Preservation

Keep the original iPhone installation, profiles, shoe keys and bonds intact. User authorization is scoped to the operation requested; publishing source does not authorize a new hardware test. Fresh enrollment needs a prepared experiment and an explicit owner decision about key replacement. Nordic debugger opens and firmware operations remain stopped; `DisableAutoUpdateFW` previously failed to prevent debugger restoration and is not a no-write guarantee.

Review actual staged source and exclude `private/`, `tools/`, historical root reports and proprietary files before a push. The owner authorized the cleaned repository to become public on September 23; private profiles, evidence, and backups must remain excluded.

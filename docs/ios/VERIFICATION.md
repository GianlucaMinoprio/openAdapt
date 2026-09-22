# iOS implementation and verification

## September 22 source publication check

The complete current source passes 97 Swift core tests and an unsigned Release iOS Simulator build. The Release app contains no owner pairing file. Staged source was checked against the local owner profiles; credentials, device identities, private configuration, radio captures and signed personal shortcuts are excluded. Documentation screenshots use synthetic UI data. No iPhone installation, Bluetooth connection, reset or enrollment was performed for this source check.

## September 22 most recently connected pair

- Saved-pair connection history is separate from temporary selection. Only both shoes authenticating and returning status records a pair as the default, including connections made through the shared Siri connection path. Browsing, canceled attempts, failed attempts, and partial connections cannot overwrite it.
- Launch restores the most recent valid pair; foreground restoration does the same only when no connection or operation is active. It then uses the existing bounded reconnect for that pair alone. There is no automatic cycling through other saved pairs. My shoes at the top left still lets the user select another pair and press Connect.
- Removing a pair prunes its history, with the most recently connected remaining pair preferred. Before any new history exists, the previous selectedPair preference is preserved as an upgrade fallback.
- **94 core tests pass**, including five history tests for restarts, latest successful connection, partial/failure retention, removal, missing profiles, and upgrade fallback. The first full run timed out in the pre-existing gesture cancellation test during a concurrent build; an unchanged full rerun passed after the build finished. No protocol timing was changed.
- The targeted multi-pair Simulator flow passes: failure and retry, choosing another saved pair through the top-left My shoes button, explicitly connecting it, and seeing that pair on the main page. The initial UI test attempted Done inside a detail page; the corrected test follows the visible Back button before Done. Synthetic profiles never initialize Bluetooth. Screenshot: [another pair selected](screenshots/other-pair-selected.png).
- The final signed build passed, installed, and launched on the owner's iPhone. No motor, lights, feature settings, enrollment, or firmware writes were sent by development tools. Multi-pair history is verified offline; simultaneous access to multiple physical pairs was not tested.
- Evidence: `/tmp/openadapt-last-pair-core-final.log`, `/tmp/openadapt-last-pair-ui-final.xcresult`, `/tmp/openadapt-last-pair-device-final.log`. Installation receipts remain private. Changes remain local and uncommitted.


## September 22 three-option sliding Liquid Glass dock

- Removed Link mode and its state from the home controls and touch handler. The bottom dock contains only Lights, Battery, and Modes; left/right fit controls remain independent, including multi-touch ownership.
- The glass selector follows horizontal dragging directly, preserving the initial finger offset. Releasing inside the dock opens the nearest option; releasing outside cancels. Tap and VoiceOver button activation remain available. A 250 ms, zero-bounce animation settles the lens; Reduce Motion disables settling while keeping direct tracking. Reduce Transparency uses a solid fallback.
- The updated `testIndependentFitAndSheets` passes: independent left/right drags, Link absent, Lights→Battery, Battery→Lights, Lights→Modes, normal taps, colors, lights off, and applying a saved mode in demo. Cancellation and device touch feel were reviewed in code but still need hands-on validation.
- Reviewed a Simulator recording and caught a native glass-container layering issue that washed out selected labels. The corrected lens is rendered as a background behind the button row. The final UI run passes again; visually inspected crisp labels on [blue](screenshots/fit-glass-dock-blue.png) and [white](screenshots/fit-glass-dock-white.png).
- Final signed iPhone build passed, installed, and launched successfully. No physical motor/light/feature-setting operation was executed by development tools. Existing protocol tests were not rerun for this presentation change.
- Evidence: `/tmp/openadapt-sliding-dock-final-ui.xcresult`, `/tmp/openadapt-sliding-dock-final-device.log`; private installation receipts remain outside Git. `git diff --check` passes. Changes remain local and uncommitted.

## September 22 pair-wide feature switches

- Auto-Lace now has one native switch, defaulting **off** when no preference is saved. It stores a preference per pair only after both shoes acknowledge the same change. Loading that preference sends nothing; partial failures keep the previous preference and display an error.
- **Quick Unlace** replaces the double-tap wording and supports one on/off switch for both shoes. It reads on entry/reconnection, preflights before setting, validates the ACK, and requires exact readback. The off request is derived from the archived GestureOff model, not a captured disable exchange; physical validation remains pending.
- Removed the left/right selector from both feature pages and Lights. Every such action requires both shoes to be connected and available. The main independent L/R fit controls remain available.
- **89 core tests passed.** Three targeted Simulator UI flows passed across the final runs: default-off Auto-Lace and on/off, Quick Unlace on/off and re-entry readback, and colors with existing fit/sheet behavior. Initial switch tests tapped the middle of a full-width accessibility row; the corrected tests tap its actual native switch control. No product change was needed for that test targeting issue.
- Visually reviewed [Auto-Lace](screenshots/auto-lace-simple.png), [Quick Unlace](screenshots/quick-unlace-simple.png), and [Lights](screenshots/lights-pair.png). The [motion review](SHOE-LIBRARY.md#motion-review--pair-wide-switches) approves this change's native feedback.
- **Final signed iPhone build passed, installed, and launched successfully.** No feature-setting, motor, reset, or enrollment operation was invoked by development tools. Hardware feature behavior remains a separate owner check.
- Evidence: `/tmp/openadapt-simple-settings-core-final.log`, `/tmp/openadapt-simple-settings-ui.xcresult`, `/tmp/openadapt-simple-settings-ui-final.xcresult`, and `/tmp/openadapt-simple-settings-device-final.log`. Installation receipts remain private. Changes are local and uncommitted.


## September 22: saved-pair reconnect stall

- Reproduced the owner's failure on both saved shoes. Console showed encrypted Bluetooth links, successful service/firmware reads, notification subscription, one unacknowledged write per shoe, then app-initiated disconnects about three seconds later. Bounded Debug diagnostics confirmed `canSendWriteWithoutResponse` stayed false after the first fragment, no readiness callback arrived, and the pending second fragment hit the writer timeout. The underlying iOS flow-control cause remains undetermined; the trace did not show a rejected application key.
- The AutoMax command characteristic advertises both ATT write types. The iPhone client now chooses acknowledged writes at discovery when supported, serializes fragments and flow acknowledgements, and waits for `didWriteValueFor` before sending the next packet. Timeout, disconnect, write error, and cancellation terminate the stream without replay or switching transport. The existing capacity-gated path remains for characteristics supporting only unacknowledged writes. Packet length is checked against CoreBluetooth's reported limit. The application handshake/proof validation is unchanged.
- The installed update authenticated **both physical saved shoes** and completed status reads. The owner confirmed, “now it works.” No reset, re-enrollment, credential replacement, calibration, actuator, feature-setting, or firmware operation was initiated by the development tools.
- **82 core tests pass**, including five new writer cases: ordered fragment/flow writes, error without replay, missing acknowledgement timeout, disconnect with queued writes, and cancellation with a late callback. Signed iPhone build passes. Tests cover writer lifecycle; this reconnect check does not establish physical motor/light behavior or fresh enrollment with the new transport.
- Debug diagnostics retain at most 160 local events containing timestamps, transient link numbers, controlled stage labels, and numeric error codes. They contain no identifiers, credentials, or packet bytes; Release does not record them. Raw Console/device evidence stays outside Git. Local build/test logs: `/tmp/openadapt-reconnect-build.log`, `/tmp/openadapt-writer-tests.log`.

## September 22: sequential, accessible first-time setup

- Replaced separate connection cards with a single persistent large shoe, a concise physical instruction, and first/second-step progress. Firmware, proximity, and model-selection rows are absent from onboarding. The lamp cue runs only while waiting for a physical press.
- Enrollment now saves/authenticates the first shoe before starting its partner. Manufacturer metadata determines physical side; proximity only chooses which shoe to approach first. The next instruction names the opposite foot. If the partner was not found initially, it can be discovered after the first confirmation. Retained candidate records are prioritized on retry; errors never advance the sequence or publish a partial pair.
- Saved-pair Connect still connects both shoes together. Existing key-exchange persistence and no-replay rules are unchanged. These checks used synthetic responses and did not enroll, reset, or move physical shoes.
- **77 core tests pass. Seven targeted Simulator flows pass** across the initial six-flow run and final accessibility check: first-only instruction/cancel, left → right, right → left with Reduce Motion, failed first foot without advancing, complete pair publication, welcome/reset help, and accessibility-size text. Final confirmation/success reruns also verify automatic scrolling to each new instruction.
- Signed iPhone and unsigned Release Simulator builds pass. Installed and successfully launched the update on the owner’s iPhone. Visually inspected [first shoe](screenshots/new-shoes-first-confirmation.png), [opposite shoe](screenshots/new-shoes-second-confirmation.png), and [completion](screenshots/new-shoes-saved.png). The [motion review](SHOE-LIBRARY.md#motion-review--september-22) records the simplified transitions and reduced-motion behavior.
- Evidence: `/tmp/openadapt-sequential-setup-core.log`, `/tmp/openadapt-sequential-setup-ui.xcresult`, `/tmp/openadapt-sequential-accessibility-ui.xcresult`, `/tmp/openadapt-sequential-setup-iphone-final.log`, and `/tmp/openadapt-sequential-setup-release.log`. Hardware enrollment and new-shoe fit calibration remain unverified.

## September 21: first-time two-shoe enrollment

- Recovered read-only Omarchy evidence for product families, manufacturer physical-side identity, setup readiness proof, button-event routing, and legacy DH derivation. No reset-state advertisement flag was established. [First-time pairing](FIRST-PAIRING.md) records the findings and limits.
- Added explicit setup/enrollment APIs, pinned Swift Crypto 4.5.2 BoringSSL DH, durable Keychain attempt/candidate records, candidate-only recovery, both-shoe verification, and native profiles. Normal saved-key failure cannot trigger enrollment. A lost peer response can require an owner-performed manual reset; no automatic reenrollment or reset command is implemented.
- New native pairs have unknown fit calibration. App L/R, saved-mode application, and Siri fit targets remain blocked until verified calibration is available. Existing calibrated profiles retain their controls. No fabricated MAC address, copied fit maximum, or pairing success based solely on an advertisement is used.
- **77 Swift core tests passed.** Coverage includes all four MODP groups against independent synthetic arithmetic vectors, invalid values, side metadata, exact request sequence, readiness event versus final ACK, write-ahead storage, timeout, cancellation, persistence failure before final receive ACK, candidate-only retry, both-foot publication, and calibration rejection.
- **Four relevant Simulator flows passed**: automatic inspection, welcome/reset guidance, physical button prompts without shoe selection, and synthetic verified-pair publication. The final compact layout rerun passed both enrollment flows; screenshots were visually inspected: [button prompts](screenshots/new-shoes-button-confirmation.png), [saved pair](screenshots/new-shoes-saved.png). These are synthetic previews, not live pairing evidence.
- **Signed Debug iPhone and unsigned Release Simulator builds passed.** The Release bundle excludes the private owner profile. The Debug update was installed and successfully launched on the owner's iPhone. No physical reset, enrollment, feature setting, motor, or firmware-write command was invoked by development tools.
- Evidence: `/tmp/openadapt-enrollment-core-final.log`, `/tmp/openadapt-enrollment-ui.xcresult`, `/tmp/openadapt-enrollment-ui-final.xcresult`, `/tmp/openadapt-enrollment-device-final.log`, `/tmp/openadapt-enrollment-release-final.log`. Installation receipts remain private. `git diff --check` passes; changes remain local and uncommitted.
- **Remaining:** owner-operated factory-reset enrollment, successful candidate authentication on hardware, app restart/reconnect and shoe power-cycle retention, fit-calibration readback, other model/firmware compatibility, and OTA. No runtime original-iPhone derivation known answer was obtained; primary implementation evidence plus synthetic vectors do not replace these physical checks.

## September 21: one Connect action for the pair

- Removed Connect individually from saved-pair details and removed the obsolete navigation advice from ambiguous-identity errors. The single Connect button uses the existing pair reconnect operation, which starts both disconnected shoes together and retains an already connected foot.
- The nine saved-connection core tests, existing shoe-details/removal UI flow, and signed iPhone build pass. Updated and visually checked the disconnected-pair screenshot. Installed and launched the update on the owner's iPhone. No physical setting or motor command was issued.
- Evidence: `/tmp/openadapt-pair-connect-core.log`, `/tmp/openadapt-pair-connect-ui.xcresult`, `/tmp/openadapt-pair-connect-iphone.log`. Connection/authentication behavior was not broadened to accept ambiguous or unverified shoes.

## September 21: Omarchy report and double-tap activation

- Used the owner-supplied sanitized report to correct auto-lace Off from explicit protobuf false to the captured empty payload. On/Off requests and empty ACK now match the report’s full envelope vectors. This is comparison with the report, not independent reanalysis of the original raw captures on this Mac.
- Added strict repeated-entry gesture parsing, opcode 179 readback, and captured opcode 178 double-tap activation. Activation reads first, avoids a write if already enabled, and leaves unfamiliar/multiple configurations unchanged. Only response 3 plus exact enabled readback becomes success. Critical-battery, active-session, unknown, negative, malformed, missing, canceled, or mismatched results never replay the write.
- Gestures displays each foot’s actual readback, Left/Both/Right activation, and Refresh setting. Setting reads occur on page entry/reconnection. Disable remains unavailable; the report derives an off request but provides no captured disable transaction. No preset-write or percentage mapping was established. Removed the unsupported assertion that the raw stored preset was proven to be the step-in target.
- **64 Swift core tests passed**, including eight additional message/session cases. **Both targeted UI flows passed**: independent gesture activation/readback (including mixed state and already-enabled controls), and the existing nickname/appearance/auto-lace/disconnect/removal flow. Tests used synthetic shoes and made no radio connections.
- **Signed Debug iPhone and unsigned Release Simulator builds passed. Installed and successfully launched the update on the owner’s iPhone.** No gesture/auto-lace setting, motor, enrollment, reset, or firmware-write command was invoked on physical shoes by development tools. Actual step-in/double-tap behavior remains an owner-operated check.
- Visually reviewed and saved [mixed gesture state](screenshots/gesture-settings-mixed.png) and [both enabled](screenshots/gesture-settings-enabled.png). These are Simulator demo state. The native Form/navigation and progress indicators add no custom motion or delayed interaction.
- Evidence: `/tmp/openadapt-gesture-core.log`, `/tmp/openadapt-gesture-ui.xcresult`, `/tmp/openadapt-gesture-iphone.log`, `/tmp/openadapt-gesture-release.log`. Installation/launch receipts are private outside Git. `git diff --check` passed. Changes remain local and uncommitted.
- Protocol scope and remaining evidence: [AUTO-LACE-GESTURE-EVIDENCE.md](AUTO-LACE-GESTURE-EVIDENCE.md).

## September 21: My shoes, model names, and auto-lace controls

- Implemented the owner's reference flow: saved-pair cards without repeated model names; separate connected and disconnected details; local nickname and appearance editing; native remove/cancel confirmation; five retail model names; and an Add shoes illustration based on the supplied video. Calibration is omitted. Original reference images and video frames are not bundled.
- Auto-lace can request opcode 82 Enable/Disable on either or both connected feet. Per-foot state begins Unknown, records only accepted responses, and clears on disconnect. Synthetic tests verify both boolean encodings, authentication requirements, no fit write, missing/negative/malformed ACKs, and no replay. Full captured request/ACK comparison, state readback, persistence, and physical behavior remain unverified.
- Gesture configuration and shoe-stored fit selection remain unavailable pending the complete schema from the Omarchy archive. The UI explains that limitation. Firmware inspection remains read-only; no fresh enrollment or OTA is added.
- **56 Swift core tests passed. Four targeted UI flows passed** across the initial run and corrected rerun: new-shoe catalog/search, connected details/nickname/appearance/auto-lace/disconnect/removal, Settings/Siri discovery, and welcome/reset guidance. The details test verifies Both → Enabled, then Left → Disabled while Right stays Enabled, Cancel retains the pair, and Remove deletes the synthetic pair. Earlier failures were accessibility queries: a combined color label and duplicate native alert button elements; corrected queries passed.
- **Signed Debug iPhone and unsigned Release Simulator builds passed.** Installed the final Debug build on the owner's iPhone. Automatic launch was refused because the phone was locked; unlock and open OpenAdapt. Installation/launch receipts remain private outside Git. No physical shoe configuration, motor, reset, enrollment, or firmware-write command was issued by development tools.
- Visually inspected and saved Simulator screenshots: [cards](screenshots/shoes-cards.png), [connected details](screenshots/shoe-connected-details.png), [appearance](screenshots/shoe-colorways.png), [auto-lace](screenshots/auto-lace-settings.png), [disconnected pair](screenshots/shoe-disconnected-details.png), [remove confirmation](screenshots/remove-shoe-confirmation.png), [setup intro](screenshots/new-shoes-intro.png), and [search](screenshots/new-shoes-search.png). These use synthetic sample state, with no private identifiers or credentials. Motion review: [SHOE-LIBRARY.md](SHOE-LIBRARY.md#motion-review).
- Evidence: `/tmp/openadapt-shoes-core.log`, `/tmp/openadapt-shoes-ui-v2.xcresult` (three passing flows), `/tmp/openadapt-shoes-ui-v4.xcresult` (corrected details flow), `/tmp/openadapt-shoes-iphone-final-v2.log`, and `/tmp/openadapt-shoes-release-final.log`. `git diff --check` passed. Source changes remain local and uncommitted.

## September 21: settings, Glass, and firmware inspection

- Native circular Liquid Glass top buttons on iOS 26+, with the existing native-compatible fallback for earlier systems and opaque backgrounds for Reduce Transparency. No second custom press scale is layered over Glass.
- Removed Haptic feedback and Control steps from Settings. Kept Your shoes under a Debug-only Developer mode section; the Release binary excludes that section. Added the repository link.
- Simplified Siri setup to Add Tie / Add Untie and Help. Builds lacking signed resources show functional manual-setup links. Remembered-fit semantics and background intents are unchanged.
- Added bounded firmware inspection through standard service `180A` / characteristic `2A26`. It discovers no Nike service, creates no command session, and disconnects temporary links. Unknown revisions can be displayed without weakening the existing control allowlist. Authenticated connections retain their reported revision for developer details.
- **51 Swift core tests passed**, including four new firmware-format/compatibility cases. **Four targeted XCUITest flows passed** across the initial run and corrected rerun: native shortcut confirmation/action resolution, simplified Settings and Siri/help navigation, initial Move 60/60, and new-shoe/reset guidance. The first Settings test queried the repository Link as a Button; the corrected accessibility query passed without changing the product control.
- **Signed Debug iPhone build and unsigned Release Simulator build passed.** The Release app has no private resource file or Developer mode section. `git diff --check` passed.
- Installed the current Debug build and launched it on the owner's iPhone 15 Pro. Installation/launch receipts remain owner-only outside Git. No actuator, configuration, enrollment, reset, or firmware-write command was invoked by the development tools.
- Visually reviewed five demo screenshots under `screenshots/`: Glass controls, simplified Settings, developer details, Siri actions, and Siri help. See the [motion review](SETTINGS-MOTION-REVIEW.md).

**Limits at this earlier checkpoint:** the new inspection path still needed a real-shoe check; UI/core tests do not verify radio behavior. Auto-lace and gesture pages were explanatory; auto-lace controls were subsequently added above. The current shoes have not been reset. Fresh enrollment and key recovery, shoe-stored auto-lace fit, gesture configuration/readback, and OTA remain open. `2.4.3M` is tested, not confirmed latest. See [new-shoe readiness](NEW-SHOES-READINESS.md).

## Original September 15 implementation snapshot

September 15, 2026. Native source lives in `apps/ios`; it is an existing-key Auto Max port of OpenAdapt's original Python protocol.

## Confirmed in this development session

- Cloned the existing repository into the Mac's Projects folder and developed on `codex/ios-client`.
- Compiled the Swift protocol package with Apple Swift 6.4 and the native iOS application with Xcode 27.
- **15 Swift tests passed**, using synthetic keys and identifiers. Tests cover known AES and wire vectors, the firmware allowlist, v1/v2 imports, invalid credentials/calibration, duplicate/reordered fragments, sequence wrap, repeated authenticated sessions, charger/battery preflight, completion ordering, missing completion, disagreeing readback, cancellation, disconnect, physical-button notifications, and rejection without command replay.
- The SwiftUI app includes independent/linked fit, haptics, estimated movement feedback, base lights, battery, local presets, guided setup/help, and native settings/sheets.
- No Nike assets, recording frames, private credentials, shoe identifiers, Bluetooth captures, or proprietary software were added to the source tree. UI screenshots use a labeled Debug demo.

## Native build and Simulator results

- **Debug Simulator build passed.**
- **Release arm64 iPhone build passed**, using the iPhoneOS SDK with signing disabled for compilation. This artifact is not a distributable/signed installation package.
- **4 XCUITest flows passed** on the iPhone 18 Pro / iOS 27 Simulator. They cover a real drag of the independent left control while the right remains unchanged, linked adjustment reaching matching targets, battery and lights sheets, changing lights to Blue and Indigo, switching lights off, restoring Volt, applying the Chill mode, the welcome screen, guided new-shoe setup/reset help, disabled connecting controls and Cancel, and the app’s reduced-motion path.
- Visually reviewed the welcome, fit, lights, battery, and modes screens, plus blue/indigo backgrounds and the white lights-off state. The main controls switch between black and white for contrast. The app and welcome screen use the original OpenAdapt sneaker drawing. Saved original Simulator screenshots under [`screenshots`](screenshots/); they contain sample values only.
- The debug demo now bypasses Keychain entirely. The normal empty-state test runs a locally signed Simulator build and asserts there is no startup alert. Unsigned Simulator installation is insufficient to verify Keychain behavior.
- `git diff --check` passed. The new workflow runs core tests and a Simulator compilation on GitHub; that remote workflow has not been run in this local session.

These are 19 test cases in total. Simultaneous two-finger dragging is implemented with UIKit touch ownership; the automated UI test exercises independent and linked drags sequentially. Device haptics and concurrent fingers still need hands-on validation.

## Owner defaults and public source

- The optional owner JSON and local xcconfig are ignored by Git. The owner file is included only by the Debug build phase, then validated and persisted in the device-only Keychain on the first normal launch. Existing saved pairs are never overwritten.
- A normal local Simulator launch selected the supplied Auto Max pair without an import screen or startup alert. Its one-time bootstrap receipt was present, and relaunch retained the saved pair.
- Release was built with the local owner configuration present; the resulting app contained no private resource, owner key, or shoe address. A separate Debug build from only public source files also passed and contained none of those values.
- A scan of tracked and unignored source files found no owner keys or addresses. The original supplied profile is unchanged.
- Onboarding and connection-state test launches bypass private defaults and Keychain, and never scan or connect to hardware.
- The reset help links to [Nike’s manual system-reset guide](https://www.nike.com/my/help/a/adapt-troubleshooting). It explains the current inability to set up a reset pair before displaying the manual steps. No reset command is implemented.

## Physical iPhone installation

- Built the personalized Debug variant with Apple Development signing and installed it on the owner’s iPhone 15 Pro running iOS 27.
- Launched the app successfully and confirmed its process remained running. Read the app’s bootstrap receipt and confirmed the supplied Auto Max profile was installed into Keychain.
- The local signing team and personal bundle identifier are configured in the ignored owner xcconfig. The public configuration retains its generic bundle identifier.
- Installation did not validate Bluetooth authentication, haptics, concurrent gestures, or physical shoe behavior.

## Hardware validation still required

Simulator tests do not establish a working radio link or physical behavior. The CoreBluetooth implementation still needs validation on an actual iPhone with the owner's current pair and keys:

1. Confirm the saved pair’s presentation on the iPhone and that Keychain persistence survives app restarts. The signed owner build, installation, launch, and initial Keychain bootstrap are verified.
2. Explicitly select each owned shoe. Read firmware, authenticate, and read battery/position. Observe any iOS system-pairing dialog; verify continued original-phone operation separately.
3. With the owner present and ready, start with empty shoes and an explicit moderate fit command. Compare target, protocol completion, readback, and physical movement. Verify independent and linked gestures.
4. Confirm base color appearance, lights-off behavior, actual motor duration, and haptic feel. The current 2.8-second progress curve is an estimate, not telemetry or measured iPhone lacing time.
5. Test first-time side selection, remembered-peripheral reconnect, cancellation, radio loss, app backgrounding, low battery, charging, and wrong-side selection. Confirm controls become unavailable and no command is replayed.

No shoe hardware experiment was executed during this implementation. The owner supplied a private profile, which was configured only for local Debug builds. Shoes were not reset, and no motor/light command was sent to hardware.

## Public-release requirements

The repository already licenses original code under MIT. Public source visibility and a downloadable iPhone release are separate steps. The local iOS work does not change GitHub visibility, upload a build, create an App Store listing, or supply a TestFlight link.

A release needs a chosen Apple Developer signing team, physical-device results, an App Store Connect app record, beta submission, and review before external TestFlight distribution. TestFlight supports public invitation links; see [Apple's distribution guide](https://developer.apple.com/testflight/). Source builders can select their own team and build the checked-in Xcode project.

Most importantly, owners without their current saved keys still need a validated fresh-enrollment and recovery implementation. That work remains open in the parent project and is not enabled by this UI or by synthetic tests. Effects, Huarache, auto-lace changes, calibration writes, and firmware updates are also outside this first iOS implementation. Siri and Shortcuts were subsequently added, as recorded below.

## Shared sneaker redesign

- Replaced the angular icon with a rounded original sneaker silhouette, open lace details, a curved sole and a heel cushion window. The iPhone app icon, template PDF, Omarchy bar/panel Canvas, and desktop launcher now come from `assets/brand/sneaker.svg` through one generator.
- Signed iPhone and Simulator builds passed. Installed and launched the updated app on the owner’s iPhone 15 Pro after restoring its connection. Launched the Simulator demo and visually verified the new template in the main toolbar; screenshot: `screenshots/fit-new-icon.png`.
- Rendered the actual Omarchy QML using Qt Quick’s software backend at 24, 32 and 64 px in white and green, including a rectangular container. The renderer reported no QML errors; the preview is `assets/brand/preview.png`. This verifies the drawing component, not installation in a running Omarchy shell.
- Updating the running Omarchy installation requires the owner’s computer address; no remote desktop installation was available from this Mac during the redesign.


## Siri integration and reference-based icon

- Added eight foreground App Intents and App Shortcuts, side/color parameters, saved-mode entities, and a native Siri & Shortcuts section. Xcode extracted all eight actions and phrases, including the foreground/authentication policies and 0–100 fit bounds. See [Siri behavior and setup](SIRI.md).
- The core suite now passes **25 tests** (15 existing protocol tests plus 10 shortcut orchestration tests). Shortcut results wait for confirmed device results, preflight both requested shoes, report partial failures explicitly, and reject canceled or stale requests without replay.
- Simplified the shared mark after owner feedback to a clean laceless silhouette with **two solid blue dots**, inspired by the supplied shoe reference. iOS uses a tintable upper plus a separate original-color lamp vector. Omarchy uses white dots on the green/accent upper and blue dots on the white bar mark. Rendered the actual QML at multiple small sizes; the updated preview is `assets/brand/preview.png`.
- Siri voice recognition and physical shoe response require on-device verification with the owner. Development and automated tests sent no motor or light commands to hardware.

- Final signed Debug iPhone and unsigned Release builds passed. Release was checked again for absence of the owner resource, key bytes and shoe addresses; all eight foreground/authenticated intent definitions remain present.
- Installed the final Siri + simplified-icon Debug build on the owner’s iPhone 15 Pro. Installation succeeded; automatic launch was refused because the phone was locked. Unlock and open OpenAdapt to use the update.
- The four existing UI flows passed after the Siri integration. The added Siri-settings discovery check also passed, verifying the native Shortcuts link and first-connection guidance. **25 core tests and 5 UI flows pass** in total.


## Background Siri and automatic reconnection

- All eight App Intents now declare `openAppWhenRun = false` and iOS 26+ `.background` execution. The existing local-device-authentication policy and when-unlocked Keychain protection remain intact.
- Added the `bluetooth-central` Info.plist background mode, direct retrieval of previously authenticated CoreBluetooth identifiers, and a finite UIKit background execution assertion. Commands retain the existing firmware, key, battery, charger, calibration and acknowledged-completion checks.
- One command can run at a time, with a 25-second app deadline. System expiration and caller cancellation close pending connections; late completion cannot become success. No persisted action, delayed replay, or background discovery scan is used. Ordinary background actions release temporary connections; explicit Connect can retain idle links.
- Opening the app reloads the selected saved pair and automatically reconnects its known peripherals. The attempt is bounded to 20 seconds, is cancelable, and leaves L/R disabled until authentication. An explicit disconnect remains disconnected until the next app opening or connect request. First-time side selection is still required to establish the iPhone's identifiers.
- **31 core tests pass**, including six new execution-lifetime tests, and **all five Simulator UI flows pass** after the lifecycle changes. The first intermediate UI run caught that the onboarding test needed to bypass profile reload on foregrounding; the final run verifies that isolation.
- Final signed Debug iPhone and unsigned Release builds passed. Compiled metadata in both builds confirms eight background actions, no foreground opening, and local authentication. Both compiled Info.plists contain the correct `bluetooth-central` array. Release contains no owner resource, keys, shoe addresses, or advertised names.
- Installed and successfully launched the updated Debug app on the owner's iPhone 15 Pro. Receipts and full local build/test logs remain under `/tmp/openadapt-background-*`; device identifiers are not included here.
- Actual Siri voice recognition, offscreen Bluetooth completion, and automatic reconnection to physical shoes remain unverified. The automated checks do not establish those hardware results; no motor or light action was issued during this work.


## Target and lacing bars

- Reviewed frames from the owner's Nike recording at 0:15–0:20. Added an immediate drag-following target bar. On release, the target remains faintly visible while a separate solid bar catches up from the last measured fit.
- Increased the estimated movement curve from 1.8 to 2.8 seconds. Progress still waits short of the target until confirmed completion; the demo's simulated completion was adjusted to match. Removed the visible lacing/estimated-progress caption while preserving layout and accessible lacing state.
- Prevented idle-position observations from moving a requested target during lacing. Reduced Motion suppresses interpolated movement; only the small progress marker redraws each frame.
- Signed Debug iPhone build passed. Three relevant Simulator UI flows passed: independent/linked adjustment and sheets, disabled connecting controls, and reduced-motion adjustment. Inspected the simulator recording frame by frame to verify the held target, separate catch-up bar and hidden caption. A short demo is saved at [screenshots/fit-bars.mp4](screenshots/fit-bars.mp4).
- Installed and launched this update on the owner's iPhone. No physical motor/light command was issued as part of verification. The 2.8-second curve remains a visual estimate, not a hardware timing measurement.
- Motion review: [FIT-MOTION-REVIEW.md](FIT-MOTION-REVIEW.md).


## Connect shoes failure and live reconnection

- The owner reported that Connect shoes immediately returned to “Your shoes are asleep.” The interface used that title for every disconnected state and discarded the actual failure. Connect now shows “Not connected” before an attempt and “Couldn’t connect” with the specific error when it fails.
- Foreground connection now tries a remembered peripheral with an eight-second connection budget, then uses a bounded discovery fallback when appropriate. The complete attempt retains its 20-second deadline. Bluetooth permission/power errors and firmware/authentication failures are preserved. Canceled discovery cannot start a late connection, and a connection that returns after cancellation is discarded.
- Device preferences confirmed two distinct remembered iPhone peripheral identifiers. The private profile contains two identical advertised names. An initial live diagnostic exposed a collision in name-only rediscovery. The final implementation preserves each side's remembered identifier when names are shared; it cannot substitute the other same-named shoe. It also ignores a differing cached CoreBluetooth display name for an already authenticated UUID; the existing key and firmware checks still determine whether that shoe is accepted.
- My shoes includes Connect individually for cases where same-named shoes need their iPhone identities established again. No reset, enrollment, key replacement or actuator operation is added.
- **40 core tests pass**, including nine reconnection tests covering cache recovery, errors, cancellation and same-name identity separation. The final targeted UI run passes connection-error/retry behavior, connecting/cancel, and guided setup. The other existing UI flows passed in the earlier regression run. Signed Debug and unsigned Release builds passed.
- Installed and launched the final correction on the owner's iPhone. After the bounded reconnect attempt, the app's device-local result reported **leftConnected = true, rightConnected = true, failed = false**. Those states are only set after firmware verification, saved-key authentication and successful status reads. This establishes live iPhone connection/authentication/status for both current Auto Max shoes.
- **No motor or light command was sent.** Physical movement, light appearance, haptics, Siri execution and robustness across sleep/radio changes still need their own device checks. Local receipts and sanitized result summaries are under `/tmp/openadapt-connect-identity-*`; private identifiers remain outside this report.


## Natural Siri commands and remembered fit

- Added parameter-free **Tie Shoes** as the first App Shortcut. It restores the last saved mode successfully applied to both shoes through the app or Apply Shoe Mode. Mode identity persists per pair, resolves current values on execution, and survives loosening and restarts. A failed/partial application does not replace it. Deleted modes and first use require applying a saved fit once instead of selecting an arbitrary default.
- Loosen Shoes still defaults to both shoes and keeps the remembered mode. Tie/loosen now give brief success dialogs only after the existing runner confirms completion; detailed partial failures are preserved.
- Added built-in “Tie my shoes with OpenAdapt,” “Lace up my shoes with OpenAdapt,” and “Untie my shoes with OpenAdapt” phrases. Apple requires the app name in app-provided phrases. Bare “Tie my shoes” and “Loosen my shoes” use one-time personal shortcuts; the app does not silently create them.
- Settings includes a native guide with those two everyday phrases, the remembered mode, and three setup steps. Modes labels the remembered fit. The guide gives VoiceOver an explicit left/right percentage value.
- **47 core tests pass**, including seven history tests for persistence, first use, partial completion, latest selection, pair isolation, deleted modes, and pair removal. Signed Debug build passed. Compiled metadata contains **nine actions and nine App Shortcuts**, no parameters for Tie, both-shoes default for Loosen, and background execution plus local authentication for all actions.
- The independent/linked fit and sheets UI regression passed. An initial guide assertion expected the LabeledContent value as separate static text; visual inspection confirmed it was displayed. The final guide supplies a clear combined accessibility element; the targeted UI test now passes its remembered-mode label/value, both everyday phrases, and the complete setup steps. Screenshots: [voice guide](screenshots/siri-voice-setup.png), [setup steps](screenshots/siri-voice-steps.png).
- Installed and launched the update on the owner's iPhone. No motor or light command was issued. Live Siri recognition, personal-shortcut naming, offscreen physical completion, and the initial remembered fit still require owner interaction; automated checks do not establish them.


## Tie Shoes initial default

- At the owner's request, Tie Shoes now uses the first saved fit whenever no remembered mode is available. With the default list this is **Move, left 60% / right 60%**. A subsequently confirmed saved mode still takes precedence. The fallback is resolved from the current list, rather than hard-coded percentages; an empty list still reports that a fit must be saved.
- Modes and the Siri guide show the same effective tie fit. The guide no longer requires an initial mode application. Loosening still preserves the last applied mode.
- **47 core tests and both targeted Siri UI tests pass**: fresh demo → Move 60/60, then confirmed Chill → remembered Chill 30/30. Signed iPhone build passed. No hardware motor or light command was issued.


## Siri “loose” / “lose” recognition report

- The owner reported a general AI answer about misplacing shoes after saying “Can you loose my shoes.” That suggests a voice interpretation or shortcut-routing problem; it does not verify invocation or failure of an OpenAdapt action.
- Confirmed the existing built-in “Untie my shoes with OpenAdapt” and “Loosen my shoes with OpenAdapt” declarations. Added “Can you…” variants for tie, untie and loosen, all retaining Apple's required app-name parameter.
- Updated the native guide to lead with complete built-in phrases. A separate section explains creating personal shortcuts for short names, recommends “Untie my shoes” for releasing, and explains the loose/lose ambiguity. Loosen Shoes remains the same action, preserving existing shortcuts and defaulting to both shoes.
- Signed build and targeted Siri guide UI test passed. Compiled metadata includes the new phrases. No motor or light command was issued during this update; actual Siri recognition remains pending the owner’s phrase check.


## Owner reports Siri release success; tying under investigation

- The owner reports that asking Siri to untie the shoes worked, while tying did not. This is owner-reported success for the release action, not validation of every Siri action or of the failed tying attempt's cause.
- A read-only inspection of device preferences found the default mode list, Move as the remembered mode, two saved iPhone peripheral bindings, and the most recent connection report showing both sides connected without failure. No identifiers or credentials were included in shared output. These stored values do not establish whether the latest spoken tie request invoked an action or moved the shoes.
- The installed build's metadata contains parameter-free Tie Shoes and both-shoes-default Loosen Shoes, with matching background and authentication policies. Requested the exact tie phrase, Siri response, and whether either shoe moved before choosing a corrective change. No motor/light commands or software reinstall were performed during this diagnosis.


## Siri web-answer routing and direct shortcut setup

- The supplied screenshot shows the exact registered phrase “Can you tie my shoes with OpenAdapt” receiving a general web answer about an unrelated desktop AI project. This does not establish that the shoe action ran. The native Simulator Shortcuts editor lists **Tie Shoes**, confirming action discoverability independently of spoken recognition.
- Added the owner's requested **“Make my lace with OpenAdapt”** and the natural variant **“Lace my shoes with OpenAdapt”** to the same parameter-free action. Both appear in the final compiled metadata. Saved-fit selection and Bluetooth execution are unchanged.
- Added a generator for credential-free, distribution-specific personal shortcuts and Settings buttons for **Add “Tie my shoes”** and **Add “Untie my shoes”**. Apple's signing service accepted both files. Signed resources and their bundle-specific manifest are ignored by Git. Builds without matching resources retain manual setup. Apple presents the confirmation; importing does not run a shoe action.
- The signed iPhone build and three targeted Simulator tests passed: Settings guide, initial Move 60/60, and opening Apple's import confirmation then adding the personal shortcut. A read-only check of the isolated Simulator's Shortcuts store confirms a single Tie Shoes action bound to this app. The original import-test attempt encountered two matching native Add Shortcut accessibility elements; terminating the prior Shortcuts session and selecting the first match corrected the test. An earlier exploratory native editor test was stopped after its keyboard animation stalled.
- Installed and launched this update on the owner's iPhone 15 Pro. Full build/test evidence remains under `/tmp/openadapt-lace-siri-*`; installation receipts are local and private. No motor or light action was executed. The owner still needs to confirm Add Shortcut on the iPhone and verify the spoken command. Their earlier untie success is owner-reported; the precise shortcut/app binding used for that attempt has not been established.
- The final import test also opens Apple's workflow preview and verifies the resolved **“Tie my shoes using my last saved fit”** action summary. It passes without installing duplicates or running the action; see [native action preview](screenshots/tie-shortcut-action.png). Earlier inspection attempts encountered a repeat-import confirmation, a failed editor deep link after replacement, and a tap on the outer preview card; targeting the nested More button verifies the actual workflow directly. Final result: `/tmp/openadapt-siri-action-preview-final-ui.xcresult`.

## September 16 source checkpoint

- Reviewed the staged source and scanned it against the local owner's credentials and identifiers. No private profiles, signing configuration, signed shortcut files, proprietary captures, or build products are included.
- Exported only Git's staged source into a fresh directory. The iOS Release Simulator build passed without local owner files; its generic bundle contains no owner profile or distribution-specific personal shortcuts.
- Re-ran all **47 Swift core tests** and the Omarchy Qt Quick suite (**14 passed**). macOS's native Qt control style reports customization warnings; the UI assertions pass.
- CI explicitly selects Xcode 26.3 for the background App Intents declarations. The build guide now distinguishes this SDK requirement from the iOS 17 minimum deployment target.


## September 22 pairing export and Omarchy import

- 97 Swift core tests and 364 Python protocol/backend tests pass.
- Shared synthetic export/import fixture; private backups, idempotence, strict inputs, identity resolution, ambiguity/bond/connection boundaries and unknown-calibration motor guards verified offline. Import never starts a connection.
- Native iPhone export/save-sheet/dismissal UI flow passes. [Developer export screenshot](screenshots/developer-pairing-export.png) uses only synthetic profiles.
- Signed device build passes and installation succeeds. Automatic launch is blocked while the iPhone is locked.
- Omarchy is offline on Tailscale; deployment and its native file dialog remain unverified. Physical post-reset pairing transfer/calibration remain separate owner checks.
- No owner keys were exported/imported or hardware commands issued by this development pass.

See [pairing transfer](PAIRING-TRANSFER.md). Logs: `/tmp/openadapt-pairing-export-core.log`, `/tmp/openadapt-pairing-export-python-final.log`, `/tmp/openadapt-pairing-export-device-final.log`, `/tmp/openadapt-pairing-export-ui-final.xcresult`.

# iOS implementation and verification

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

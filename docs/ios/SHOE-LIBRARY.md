# My shoes and model catalog

September 21, 2026. Native UI based on the owner's reference screens and the 13-second pairing recording. No Nike images or recording frames are bundled in the app.

## Implemented

- My shoes uses one card per saved pair and a full-width + action. Default model names are shown once; a distinct nickname can have the retail model as its subtitle.
- A connected pair opens nickname, shoe color, auto-lace, firmware, gestures, and model information. A disconnected pair opens Connect and Remove. Connect starts both saved-shoe connections together; there is no separate individual-connection action. Calibration is omitted.
- Renaming updates the existing Keychain profile without changing its keys, addresses, calibration, or identity. Appearance is stored separately per pair on the iPhone and never sends an LED command.
- Shoe illustrations reuse OpenAdapt's original silhouette with a few manually selected upper/sole/accent combinations. These are appearance choices, not a complete Nike SKU/colorway database or photographic reproductions.
- Removal uses a native confirmation alert. Persistence succeeds before the UI removes the pair; it clears that pair's app metadata and remembered peripheral bindings. It does not unpair Bluetooth or reset shoes. The alert explains that adding the pair back currently needs its credentials.
- Add shoes keeps one large shoe illustration onscreen with one physical-button instruction at a time. The first verified shoe establishes the next left/right prompt; the second begins only after the first key is saved and authenticated. There are no individual connection cards or model choices. See [first-time pairing](FIRST-PAIRING.md).
- Firmware pages show the revisions read from each connected foot. OTA remains unavailable. First-time enrollment is implemented but needs owner-operated hardware validation; new native pairs lack verified fit calibration.

Simulator previews: [My shoes](screenshots/shoes-cards.png), [connected pair](screenshots/shoe-connected-details.png), [shoe color](screenshots/shoe-colorways.png), [disconnected pair](screenshots/shoe-disconnected-details.png), [removal](screenshots/remove-shoe-confirmation.png), and [first confirmation](screenshots/new-shoes-first-confirmation.png) and [opposite shoe](screenshots/new-shoes-second-confirmation.png). All use synthetic demo state. The current core suite passes 77 tests; sequential pairing and accessibility checks are recorded in verification. It is installed and launched on the owner’s iPhone. Gesture previews: [mixed state](screenshots/gesture-settings-mixed.png) and [both enabled](screenshots/gesture-settings-enabled.png).

## Retail names and Bluetooth identity

The catalog includes **Nike Adapt BB, Nike Adapt BB 2.0, Nike Adapt Huarache, Nike Adapt Auto Max, and Air Jordan 11 Adapt**. Nike's [Adaptive Fit history](https://www.nike.com/gb/launch/t/inside-the-vault-automax-adaptive-fit1) documents the first four; its [Air Jordan 11 Adapt release page](https://www.nike.com/launch/t/air-jordan-11-adapt-dark-powder-blue) identifies the fifth. These are the Adapt app model names, not every colorway or every historical self-lacing Nike shoe.

The recovered product manifest maps `001` → BB, `002` → Huarache, `004` → AutoMax, `005` → BB2, and `006`/`007` → Air Jordan XI Adapt. Prototype `003` is not a retail choice. Manufacturer company `0x0078` and the original physical-side bit establish metadata; signal strength never determines left/right. Detection does not expand the firmware/authentication allowlist: enrollment and control remain Auto Max 2.4.3M only.

## Auto-lace and gestures

The owner's Omarchy report supplies the complete captured auto-lace and gesture envelopes. See [implementation evidence](AUTO-LACE-GESTURE-EVIDENCE.md). Auto-lace requests now match captured proto3 encoding: empty payload for false, field 1 true for enable, and an empty ACK. The single Auto-Lace switch remembers the last preference acknowledged by both shoes, defaulting off when none has been saved. The preference is not live readback; no command runs on page entry.

The Quick Unlace page reads the pair on entry, then provides one native on/off switch for both shoes. Each change requires a successful acknowledgement and matching readback. Shoes already matching the request need no setting write. Unfamiliar or multiple mappings are left unchanged. Off uses the archived GestureOff model; physical behavior still needs verification. Both feature pages omit per-foot controls, redundant introduction headings, and detailed state rows. The Lights page also has no foot selector and applies all choices to both shoes.

Choosing the step-in fit still awaits the preset-write command and percentage mapping. Opcode 2 preset reads do not prove the values are the step-in target. OpenAdapt’s manual/Siri Modes remain separate.

## Motion review — September 22

| Before | After | Why |
| --- | --- | --- |
| Setup enlarged the shoe, added a phone cue, then replaced the illustration with two connection cards. | A single illustration remains throughout first/second confirmation. `apps/ios/OpenAdapt/Views/PairingIllustration.swift:16` | Keeps attention on the physical button and removes unnecessary spatial changes. |
| The shoe lights pulsed throughout discovery. | A low-contrast, two-second opacity cycle runs only while awaiting a button press; it stops for Reduce Motion and inactive scenes. `apps/ios/OpenAdapt/Views/PairingIllustration.swift:11` | This is an explanatory physical-button cue, not a delayed UI transition. Discovery uses the native progress indicator. |
| Several independently changing connection rows. | One instruction and a first-shoe confirmation, with VoiceOver focus moved to the new instruction. `apps/ios/OpenAdapt/Views/PairingView.swift:91` | Sequential guidance is easier to follow; no motion must finish before a button can be pressed. |
| Success changed the page structure. | The same shoe gains a checkmark over 200 ms using the shared strong ease-out; reduced motion uses opacity only over 150 ms. `apps/ios/OpenAdapt/Views/PairingIllustration.swift:24` | Confirms completion without a large scale change or layout animation. |

### Verdict

**Approve — motion implementation.** Animated properties are opacity and a small checkmark scale; the shoe stays stationary. The local timeline is paused outside physical confirmation, in inactive scenes, and with Reduce Motion. Native text scales with Dynamic Type, instructions are explicit for VoiceOver, controls have at least 44-point targets, and the page scrolls when content needs more space. Physical haptics, radio timing, and real pairing still need owner validation.

## Motion review — pair-wide switches

| Before | After | Why |
| --- | --- | --- |
| Separate actions and per-foot state changes. | Native switches with one pair-level progress/error message. `ShoeFeatureView.swift:45` | Uses the system's familiar state feedback without adding custom layout or scale animation. |
| Side selector above light choices. | Color actions apply to both; existing press feedback remains. `Sheets.swift` / `Motion.swift:20` | Removes a UI step. The existing small press effect respects Reduce Motion. |

**Verdict: Approve for this change.** No custom animation was added to the feature pages. Native switch/progress behavior gives feedback without delaying input; the control is unavailable only while the actual request is pending. Simulator screenshots verify layout, not physical haptics or radio timing.

Current screenshots: [Auto-Lace](screenshots/auto-lace-simple.png), [Quick Unlace](screenshots/quick-unlace-simple.png), [Lights](screenshots/lights-pair.png).

## Motion review — three-option sliding glass dock

| Before | After | Why |
| --- | --- | --- |
| Four controls, including Link mode. | Three equal-size Lights, Battery, and Modes controls; independent L/R touch ownership. | Removes a mode and simplifies the primary surface. |
| Tap-only glass highlight. | One native glass lens follows a horizontal drag directly, preserving the finger offset. Release inside the dock opens the nearest option; outside cancels. | Supports scrubbing across the controls without opening intermediate panels. Buttons remain available for tap and VoiceOver. |
| Animated selection changes only. | Direct tracking disables easing; release settles over 250 ms with no bounce. | Keeps glass attached to the finger and gives a short, interruptible settling response. |
| Glass and labels shared a rendering container. | The lens is a background behind the button row. | The first recorded check exposed washed-out selected labels; separating the layers preserves legibility. |
| One material treatment. | Glass sits over a simple tint. Reduce Motion keeps direct tracking but removes settling; Reduce Transparency uses a solid surface. | Retains visible feedback without requiring animation or transparency. |

**Verdict: Approve after the foreground-layer correction.** Targets are 74 × 62 points. The gesture has an eight-point activation threshold and twenty-point release tolerance. There is no animation delay before opening a panel. Offline UI tests exercise drags in both directions and a slide across all three options; hardware touch feel remains an owner check. API guidance: [Apple, Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).

Screenshots: [blue](screenshots/fit-glass-dock-blue.png), [white](screenshots/fit-glass-dock-white.png).

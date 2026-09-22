# New shoes, automatic lacing, and firmware

September 21, 2026. The owner has **not reset the current Auto Max pair**. No reset, enrollment, motor, feature-setting, or firmware-write experiment was performed for this update.

## What the iPhone app can do today

- Reconnect an already saved Auto Max pair using its existing keys and calibrated profile.
- Discover nearby Adapt advertisements and inspect the standard Device Information firmware revision. Additional product families require Nike manufacturer data and a fresh product-format advertisement; their model choice does not enable control. Inspection opens only service `180A`, reads characteristic `2A26`, and disconnects its temporary link. It does not subscribe to the Nike channel or send an application command. An existing open link can supply the revision it already read. CoreBluetooth still controls any system permission or pairing prompts.
- Show untested printable firmware versions without enabling control. The existing control gate still accepts only the observed `2.4.3M` formats: six ASCII bytes or the 20-byte field with trailing zeros.
- Show firmware from authenticated connections under **My shoes → connected pair → Firmware**, with additional details under **Settings → Developer mode → Your shoes** in Debug builds.
- Manage nicknames and local shoe appearance, open separate connected/disconnected detail pages, and remove saved pairs with native confirmation. The model catalog names all five Adapt app models; verified control remains Auto Max 2.4.3M. See [My shoes](SHOE-LIBRARY.md).
- Read the current gesture configuration and turn Quick Unlace on/off for both shoes, requiring acknowledgement plus matching readback. Unknown/multiple mappings are preserved. Off uses the archived GestureOff model and awaits physical validation.
- Request Auto-Lace On/Off on both connected shoes with one switch, remembering the preference only after both acknowledgements. The request/ACK vectors now match the supplied Omarchy report; device behavior remains pending.

The firmware parser is covered by offline tests. Actual inspection of a new shoe through this new UI still needs a device check. Reading a version is not a successful enrollment or proof of compatibility.

## Fresh pairing: implemented, hardware validation pending

The iPhone Add shoes flow now discovers and identifies the pair, connects both supported Auto Max shoes, proves setup readiness, prompts for a physical button press, derives and verifies credentials, and saves a native profile. It has no model picker or JSON import requirement. [First-time pairing](FIRST-PAIRING.md) documents the evidence, Keychain journal, failure boundaries, and offline/Simulator verification.

The flow has **not yet enrolled a reset pair on real hardware**. Candidate authentication after restart and shoe key retention still need an owner-operated test. A lost public response may require another manual reset; setup never automatically repeats a key exchange. Existing owner profiles remain preserved.

New profiles also lack verified fit calibration. They can authenticate for battery/light control, but app/Siri fit commands remain unavailable; use the physical shoe buttons for fit. Existing calibrated profiles keep their controls. Do not copy the current pair’s credentials or maxima to new shoes.

For a new pair, inspect model and firmware first. A factory-fresh shoe should not need an extra reset merely to inspect it. Unknown firmware cannot enroll or control until its compatibility is established. No hardware reset or key-replacement experiment was run by development tools.

## Auto-lace and quick gestures

The owner supplied a sanitized Omarchy report establishing exact auto-lace on/off, double-tap enable, and gesture readback envelopes. [Implementation details and remaining limits](AUTO-LACE-GESTURE-EVIDENCE.md) supersede the earlier summary-only evidence.

Auto-lace opcode 82 uses an empty request for false and field 1 true for enable, with an empty ACK. The iOS page remembers the last preference successfully applied to both shoes, defaulting off when none is saved. No enabled-state getter or shoe-side persistence result is established, and opening the page sends no setting.

The Quick Unlace page reads opcode 179, then sets the captured on mapping or the archived GestureOff mapping through opcode 178. It requires response 3 and a readback matching the requested setting. Shoes already matching the request receive no write; unknown or multiple configurations are not overwritten. The report has no captured disable transaction; its implementation is schema-derived and physical validation remains pending. Gesture physical behavior and power-cycle persistence remain unverified.

The captured preset values are raw 46 left / 48 right. The report does not prove they are the step-in target, establish their displayed percentage mapping, or provide a preset-write path. OpenAdapt’s **Move 60/60** shortcut mode is not an automatic-lacing preset.

## Is 2.4.3M the latest? Can older shoes update?

**2.4.3M is the tested firmware, not a confirmed latest release.** No authoritative final-version catalog or trusted matching update package was found in this investigation. Nike's [retirement notice](https://www.nike.com/gb/en/help/a/adapt-app) says the Adapt app retired on August 6, 2024; it does not establish a latest firmware number.

Do not reject an older pair as unusable merely from its version. Inspect it first, then verify protocol compatibility before changing the explicit supported-version policy. Until that work is done, commands remain blocked for unknown versions.

OTA is not implemented. The research includes image-transfer framing observed for animation assets; that is not a verified firmware-update path. No firmware-upgrade operation is exposed in either client. An updater needs a trusted image matched to the exact hardware/model, validated integrity/signature and version rules, confirmed transfer/install behavior, and interruption/recovery testing. An animation asset or guessed firmware image cannot satisfy those requirements.

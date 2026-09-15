# Original-app action recordings

> Historical research checkpoint. For current capabilities, test totals and remaining work, see [Project status](STATUS.md). Statements below describe the evidence available at the checkpoint date.

**Motor control verified, September 15 07:31 UTC:** OpenAdapt authenticated and laced both owned Auto Max shoes using their current keys, without reset. Both 80% targets have verified completion/readback and clean disconnects; the owner confirmed both physically worked. The combined suite passes **253 tests**. **The owner asked to stop for the night; do not send more shoe commands until they return ready.** Fresh enrollment and Huarache support remain unproven. See [the motor-control report](AUTO-MAX-MOTOR-CONTROL.md). Earlier checkpoints below are historical.

September 13, 2026. Owner-operated Nike Adapt on iPhone, connected to the owner's Auto Max pair. The reference app is 1.29.4/build 24903; this pair previously reported firmware 2.4.3M. These observations do not establish Huarache behavior or successful replacement-controller operation.

## Result

The owner confirmed physical color changes, Pulsing on both shoes, Strobe on both shoes, Gradient described as a much slower flashing effect, and a right-shoe tighten/loosen cycle ending at zero. Corresponding application messages were recovered from USB Bluetooth HCI recordings on Linux. This is evidence of the original app controlling the shoes. Codex only recorded and decoded traffic; it did not open a host BLE connection or issue shoe commands.

The owner clarified that split-color choices display **both colors within each shoe when an effect runs**. Different base-color settings sent separately to the left and right shoes do not describe the full effect behavior. The animation uploads contain separate RGB channels. Their physical LED ordering is not yet independently mapped.

## Completed captures

| Recording | Duration | Complete PacketLogger records | Complete owned-shoe messages | Reassembly problems |
|---|---:|---:|---:|---:|
| Colors | 440.39 s | 11,529 | 789 | 0 |
| Effects and guided right-shoe movement | 581.41 s | 14,333 | 764 | 0 |
| Run, Unlace, battery and Lights Off | 477.82 s | 7,025 | 152 | 0 |
| Custom-mode exploration and recall | 420.37 s | 10,287 | 920 | 0 |
| Four light packs and active Lights Off | 481.76 s | 8,951 | 272 | 0 |
| Right-shoe lacing through displayed 50 | 391.38 s | 5,476 | 56 | 0 |

These recordings ended deliberately or at their bounded deadline, with exit 0 from both logging processes, no partial final PacketLogger record and no unfinished application-message buffer. Connection-identity and action-attribution limits for the later files are detailed below. An earlier attempt collected no HCI packets before the owner reinstalled Apple's logging profile; another short file contains only nine diagnostic records and no action traffic. Neither is action evidence.

Private evidence is under `private/iphone-hci/20260913T224154Z-actions-auto-max/` and `private/iphone-hci/20260913T224915Z-actions-auto-max/`. Their final decode directories end in `224915168211Z` and `225857057878Z`. The original images, owner reports, raw messages, reconstructed animation files, hashes and detailed checks remain ignored and local. No proprietary animation files are included in this document or the source tree intended for publication.

PacketLogger timestamps required a documented **+25,200-second analytical correction** to align with host prompt/report times. Read-only clock checks showed the phone's Unix clock agreeing with the host, with timezone offset −25,200 seconds. Raw times are retained. Prompt/report markers bound interactions; they are not exact tap timestamps. The requested five-second palette spacing was not consistently present in the actual traffic. Initial exploration and later extra selections must not be attributed to the nearest prompt merely because they fall within its interval.

## Base colors

The color recording contains 76 app-to-shoe opcode **222** requests, all with color ID **4**, and 74 ACKs. Two requests on an interrupted right-shoe connection have no captured ACK; later connections contain acknowledged color changes. Do not describe all 76 requests as individually acknowledged.

The request is a protobuf message with unsigned integer fields:

| Field | Meaning |
|---|---|
| 1 | Color ID, observed as 4 |
| 2 | Red output |
| 3 | Green output |
| 4 | Blue output |

Zero-valued components may be omitted. All 12 distinct captured output triples are divisible by 256. The archived Android setter independently corroborates the conversion from 8-bit values by multiplication by 256.

| Screenshot swatch, row order | Output values divided by 256: R, G, B |
|---|---|
| Cyan | 0, 255, 255 |
| Light blue | 0, 60, 255 |
| Blue | 0, 0, 255 |
| Purple | 100, 0, 200 |
| Pink | 255, 10, 80 |
| Red/magenta | 240, 0, 8 |
| Red-orange | 255, 16, 3 |
| Orange | 255, 40, 0 |
| Yellow | 255, 255, 0 |
| Lime | 120, 240, 0 |
| Green | 20, 240, 0 |
| White | 255, 255, 255 |

These are device output values, not screenshot pixels or measurements of emitted light. The owner supplied 11 names for 12 swatches. Preserve that mismatch rather than shifting later names. The archived Android resources include Pink Blast as a candidate missing name; the exact iPhone name-to-swatch list still needs confirmation.

The original app also sends empty opcode **20** Identify events during color previews: 72 such app events occur in the color recording. A future implementation must distinguish setting the saved base color from triggering its visible preview.

## Effects and duration

The owner reported menu order **Pulsing, Strobe, Gradient**, with **5m, 30m and 60m** duration choices. The guided Strobe and Gradient selections were recorded in separate intervals, while the initial Pulsing report followed earlier exploration. Frame content provides additional corroboration of the effect families.

The effects recording contains **26 complete animation uploads, seven distinct byte sequences**. Every reconstructed upload matches its announced length and CRC32, has a matching download-complete message, and is followed by an acknowledged start. All 36 stop requests have captured ACKs. Both shoes acknowledged the final effect stop before the guided motor actions.

Observed upload sequence:

1. App requests animation stop, opcode **237**.
2. App announces an image, opcode **10**. Its image type is **5**, identified as an animation slot by the archived schema.
3. Shoe requests the image with opcode **11**; the app acknowledges.
4. App sends opcode **15 EVENT** data segments. Each payload begins with a little-endian 16-bit segment word: low 15 bits are the index; the high bit marks the final segment. These recordings use up to 508 data bytes per segment.
5. Shoe reports completion with opcode **13**; the app acknowledges.
6. App requests animation start, opcode **236**, with an empty payload, and receives an ACK.

These messages use the same observed Nike command/notification characteristics as other application traffic. The data segments are events, so counting only requests omits them. The archived transfer enum uses firmware-related names for this shared transport; type 5 and the decoded content establish animation transfer here. No opcode 14 firmware-upgrade request occurs in the effects recording.

The recovered animation layout is independently corroborated by the archived Android serializer:

| Offset | Size | Meaning |
|---|---:|---|
| 0 | 2 | Magic bytes DE FA |
| 2 | 2 | Type, little endian |
| 4 | 2 | Animation ID, little endian |
| 6 | 1 | Interruptible flag |
| 7 | 1 | Resumable flag |
| 8 | 2 | Repeat count, little endian |
| 10 | 2 | Repeat delay in milliseconds, little endian |
| 12 | 4 | Declared cycle length in milliseconds, little endian |
| 16 onward | 11 per frame | Three RGB triples of 8-bit output values, then little-endian 16-bit duration |

Each observed sequence ends in an all-zero RGB frame with duration 65,535. Its terminal semantics should not be generalized beyond the observed format without further verification. Individual frame durations are truncated millisecond values and do not sum exactly to the declared cycle length.

| Observed single-color effect at 5m | Bytes | Frames including terminal | Repeat count | Declared cycle |
|---|---:|---:|---:|---:|
| Pulsing | 566 | 50 | 56 | 5,291 ms |
| Strobe | 434 | 38 | 74 | 4,041 ms |
| Gradient | 1,094 | 98 | 47 | 6,291 ms |

Earlier Pulsing uploads differ only at the repeat-count field, with counts 340 and 680. Their declared durations are consistent with 30m and 60m; those particular taps were not separately timestamped by the owner. These are encoded timer observations, not measured full-duration runs. Later additional uploads contain distinct RGB channels consistent with the owner's dual-color effect observation; their exact swatch selections were not separately named.

### Light packs

The owner selected Nike Mag, Color Strike, Breathe and BeTrue. The iPhone app displays 60m for these packs, and the owner reported that it does not offer a duration choice. Eight complete uploads, one per pack per shoe, use the same animation transfer/start protocol. Every upload matches its announced size and CRC32 and has completion and start acknowledgments. Each pair receives identical animation bytes for a given pack.

The completed capture is `private/iphone-hci/20260913T232021Z-actions-auto-max/`, final decode `decode-20260913T232840473479Z`. All 20 recorded stop requests have ACKs. Both shoes acknowledged the final stops and zero-color requests; the owner reported both dark and ready afterward. All four fragment counters continue exactly from the preceding recording. This preserves its identity context, including the earlier right-side gap caveat; it does not establish new authentication. A short Unlace sequence before the end of this file is separate from the following lacing-step recording.

| Pack | Bytes | Frames including terminal | Repeat count | Declared cycle |
|---|---:|---:|---:|---:|
| Nike Mag | 885 | 79 | 550 | 6,541 ms |
| Color Strike | 1,358 | 122 | 595 | 6,041 ms |
| Breathe | 2,469 | 223 | 311 | 11,541 ms |
| BeTrue | 1,963 | 177 | 398 | 9,041 ms |

For all four packs, the captured RGB frames and truncated frame durations exactly match the corresponding archived Android light-pack asset; the captured repeat count differs from each asset's default. Multiplying captured cycle length by repeat count gives approximately one hour. No full-hour run was measured. BeTrue began before the owner's report and therefore falls inside the earlier Breathe prompt interval; its unique complete frame match independently corroborates the pack identity. Do not label uploads solely by the nearest prompt.

The owner clarified that Color Strike kept flashing because they had only waited ten seconds, without pressing an off control. A later controlled Turn Off Lights press made both shoes dark, as detailed below. No detailed physical color/pattern description was supplied for every pack, so the decoded animation data should not be mistaken for an independently verified physical LED layout.

## Guided motor observation

The shoes were empty on the table. The owner used the original app for one right-shoe tighten tap, reported the app scale at 5 out of 100, then used one loosen tap and reported zero.

| Step | Captured original-app request | Captured shoe response |
|---|---|---|
| Tighten | Opcode 0, command field 1 = 8 (Stop); then opcode 3, position field 1 = 3 | ACKs for both requests; opcode 5 completion event with position field 2 = 3 |
| Loosen | Opcode 0, command field 1 = 8 (Stop); then opcode 3 with omitted position field, default zero | ACKs for both requests; opcode 5 completion event with omitted position field, default zero |

Only the right shoe receives these guided commands. The original app uses absolute position requests in this observation, so the UI action cannot simply be equated with the archived Android short-segment enum. The reported UI value of 5 and wire position of 3 remain distinct observations; the per-shoe calibration below provides an explanation. Earlier motor traffic in the color recording lacks controlled action labels and is not a substitute for this sequence. No general force limit or emergency-stop behavior was validated.

### Right-shoe display-step comparison

The owner offered a 0–100 sweep in increments of five. The guided portion reached right 50 while leaving the left at zero, then paused when the owner requested direct computer control. The 55–100 portion and left-shoe sweep were not performed.

| Prompted block | Recorded targets in actual order | Corresponding completion positions |
|---|---|---|
| Right 5, 10, 15, 20, 25 after Unlace | 3, 6, 9, 15, 12, 15 | 3, 7, 10, 16, 11, 16 |
| Right 30, 35, 40, 45, 50 | 18, 24, 21, 27, 30 | 19, 25, 20, 28, 31 |

All 11 requests have ACKs and completion events. The actual order contains extra or reordered adjustments; individual displayed values were not separately reported at every tap. The owner confirmed completing the first block on the right and later confirmed the inferred display of left 0 / right 50. The final right target is 30, with measured position 31. The latest left target was zero in the preceding file; this file contains no fresh left position report.

The initial explanation `round(display × 61 / 100)` fits the low points but is not established as the iPhone's general conversion rule. At the reported 50 endpoint, ordinary half-up rounding would give 31, whereas the captured target is 30. Truncation, tie behavior and current calibration remain to be distinguished. Do not encode that initial explanation as a validated iPhone rule. Keep requested target, completion measurement and rounded display separate.

This recording is `private/iphone-hci/20260913T232823Z-actions-auto-max/`, final decode `decode-20260913T233544365382Z`. It stopped cleanly with no partial record, no reassembly problems and both logger processes exiting 0. Both right-shoe fragment counters continue exactly from the prior capture. There are no left Nike fragments with which to check the inherited left context. One initial right completion precedes this file's first position request and follows the Unlace request in the preceding file; the offline summary preserves it as unassociated within this file, rather than attaching it to a later move.

## Existing modes, Unlace, battery and Lights Off

A third completed recording, `private/iphone-hci/20260913T230141Z-actions-auto-max/`, contains 7,025 complete PacketLogger records / 152 reassembled application messages, with no partial final record or reassembly problem. Both logger processes exited 0. The phone retained its previous connections; no new connection event or authentication exchange occurs in this file. Left/right labels are supported by matching handles and exact continuation of all four fragment sequences from the preceding identified connections. This analytical continuity is documented in private context files; it does not establish a new authenticated session.

### Selecting Run

The owner described an existing Run mode with blue/yellow colors and left/right display values 80/85, then confirmed that its values and colors applied to the empty shoes. The trace shows separate base-color requests, Stop requests and absolute-position requests, followed by color previews. It contains no transferred mode name/ID or opcode 1 preset write for this selection. This observed mode is expanded by the app into per-shoe settings; do not infer that all shoe preset functionality is app-only.

| Side | Base-color output divided by 256 | Requested absolute position | Completion-event position |
|---|---|---:|---:|
| Left | 0, 0, 255 | 46 | 45 |
| Right | 255, 255, 0 | 51 | 50 |

The existing Nike-only backup provides independent calibration evidence. The Auto Max profiles store max-tightness values 56 left / 61 right; the saved Run record contains relative percentages 83 left / 84 right. Rounding `relative / 100 × maxTightness` gives the observed targets 46/51. The archived Android lacing-position model independently implements this relative-to-absolute conversion. The right-shoe manual display value 5 similarly gives `round(5 / 100 × 61) = 3`.

The owner-reported Run display values 80/85, stored values 83/84, requested raw positions 46/51 and final measured positions 45/50 are separate observations. Exact iPhone display rounding and completion tolerance are not yet established. Do not pass display percentages directly to the absolute-position command or overwrite the stored calibrations.

### Unlace

The owner pressed the original app's Unlace button and reported both shoes released at 0/0. The first recorded sequence uses Stop followed by absolute position zero for each shoe; both completion events report zero. Additional Stop/zero requests occur later in the interval. Their count must not be used to infer how many times the owner pressed the button or whether every duplicate is necessary.

The owner also reported the app notification that automatic lacing can resume after 15 seconds if the shoes are worn. This is a recorded UI observation. No worn-shoe test, delayed automatic-lacing event, or separate timer-setting message was established.

### Battery check

The owner reported 100% for both shoes. Two empty opcode **81** requests have ACKs with protobuf battery-percent field **4** equal to **100** for both. The archived schema additionally identifies field 1 as charger status, field 2 as battery voltage, field 3 as a double-precision battery temperature and field 5 as battery state. Their physical units and all enum meanings were not needed to validate the reported percentages. No physical LED indication was confirmed for this button.

### Lights Off

The owner subsequently reported pressing Lights Off. The preceding saved recording contains an opcode **222** request for each shoe with color ID 4 and omitted RGB fields, therefore all-zero outputs; both requests have ACKs. No opcode 237 animation-stop request occurs in that recording. This establishes the zero-color behavior of that press, not what the button does during an actively running effect. The owner's report arrived after the recording segment containing the action, which is another reason not to treat report timestamps as tap timestamps.

A subsequent controlled press while Color Strike was running sent two acknowledged opcode **237** stop requests per shoe, then acknowledged opcode **222** color-ID-4 requests with all RGB components zero. The owner confirmed both shoes went dark. This establishes the active-pack case as well; the repeated stop count is an observation, not a requirement inferred for a replacement.

### Saving and recalling Capture Test

The owner created and saved a custom mode named Capture Test. The requested draft was left 10 / right 15 with White, but after Unlace and selecting the saved mode the owner reported **5/15**. The Save press was not isolated, so the recording cannot distinguish its traffic from editing and preview actions. White's physical return was not explicitly confirmed in that reply.

The corresponding seven-minute recording, `private/iphone-hci/20260913T231239Z-actions-auto-max/`, ended at its deadline with 10,287 complete records / 920 reassembled messages, no partial final record, no reassembly errors and both logger processes exiting 0. It begins during an animation transfer and inherits two connections across a gap with missing fragment sequences; the initial identity assignments are consequently provisional. A later owned connection event revalidates the left shoe within this file. The right label retains the earlier gap caveat.

Near the end, the trace contains Unlace-to-zero commands and zero completion events for both shoes, followed by White color requests and position targets **4 left / 8 right**, with acknowledgments and completion events. Further left adjustments and another selection also occur. The follow-up prompt lacks a live marker, and the owner replied after the deadline, so these sequences are consistent with the reported recall but are not exact tap-time attribution. Preserve the requested draft, observed raw targets, measured positions and reported display values separately; do not claim the mode was saved at 10/15 or that its name was transferred to the shoes.

## Continuation

The temporary Bluetooth logging profile remains installed **by the owner's explicit choice** for future recordings. All computer recordings are stopped. Do not repeat the removal request or start recording again merely because the profile is present.

The owner explicitly requested that Codex set both empty Auto Max shoes to **80/80**. No host motor command was issued: readiness checks still find an unresolved authentication-model mismatch and no registered owned-device bond in the current BlueZ object map. The latest owner-confirmed display remains left 0 / right 50. This explicit control request is retained for continuation; it does not authorize resets, enrollment, key replacement, disruption of the original phone pairing, debugger access or firmware operations.

This turn added ignored offline capture/analysis helpers and curated findings. The controller implementation and its previously passing 37 discovery / 138 enrollment tests were not changed. The current session still rejects the recorded existing-key response at the unexplained four-byte peer-proof prefix; see [key findings](IPHONE-KEY-FINDINGS.md). Resolve that authentication interpretation and local laptop bond readiness before a live replacement attempt. Build original offline action codecs from the documented formats, with controlled validation before exposing hardware writes. No reset, enrollment, key replacement, debugger or firmware experiment follows from these recordings.

Static corroboration used archived Android opcode/serializer definitions (`hc/d.java`, `hc/l.java`, `hc/k0.java`), relevant protobuf schemas (`gc/i.java`, `gc/a.java`, `gc/c.java`, `gc/x.java`, `gc/y.java`, `gc/a0.java`, `gc/l.java`), animation metadata (`oc/b.java`), the lacing-position model (`ea/i.java`) and named light-pack assets. They were consulted read-only and remain private evidence, not replacement source code.

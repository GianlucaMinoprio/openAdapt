# Auto-lace and gesture evidence

September 21, 2026. The owner supplied `OpenAdapt-auto-lace-gesture-report.md` from the Omarchy investigation. This document records how its sanitized findings are used by the iOS implementation. The original captures were not independently opened on this Mac. No shoe setting or actuator command was executed during this implementation.

## Captured vectors transcribed by the report

These are application envelopes, without Bluetooth fragmentation or credentials.

| Operation | Request | ACK |
| --- | --- | --- |
| Auto-lace off | `520000` | `520040` |
| Auto-lace on | `5202000801` | `520040` |
| Double-tap → Unlace | `b206000a0408021002` | `b202400803` |
| Read gestures, enabled result | `b30000` | `b306400a0408021002` |
| Read gestures, disabled result | `b30000` | `b306400a0408011001` |

Auto-lace uses opcode 82, proto3 bool field 1. False omits the field entirely. The earlier implementation's explicit `08 00` was schema-equivalent but not observed; it has been corrected to match the report. The ACK is empty and does not echo a setting. There is still no verified enabled-state getter or auto-lace persistence result.

Opcode 178 sets a repeated configuration group: outer field 1 contains entries with varint field 1 (classification) and varint field 2 (action). Double tap is classification 2, Unlace is action 2. The ACK's response field 1 must equal 3 (`CONFIG_SET`). Values 1 and 2 mean critical battery and active session; missing/unknown values never mean success.

Opcode 179 reads that same repeated group. Exactly one 2/2 entry means Enabled; exactly one 1/1 entry means Disabled. Empty, unknown, training, duplicate, or multiple mappings are not collapsed into a boolean. The parser retains all entries/enum values, bounds payload size, and rejects malformed nesting, duplicate scalar fields, invalid lengths, and noncanonical/overflow varints.

## Implemented behavior — September 22

- Auto-Lace and Quick Unlace each have one native on/off switch for both shoes. Both must be connected and idle before a setting is sent. There are no per-foot selectors or separate enable/disable actions.
- Auto-Lace displays the last preference successfully acknowledged by both shoes, defaulting off when none is saved. This is a local preference, not a shoe-state getter. Reconnection still invalidates session confirmations; loading the preference sends nothing. A partial or failed change never replaces the saved preference.
- Quick Unlace reads both shoes on entry/reconnection. Each change first reads again, skips a write if already in the requested state, and only changes an exact single-entry enabled or disabled configuration. Unfamiliar/multiple mappings remain untouched.
- Both on and off require response 3, then exact readback matching the requested state. Partial, missing, negative, malformed, canceled, or mismatched results cannot become pair-wide success and never replay a write. The UI keeps one updating/error message for the pair.
- No feature-setting operation issues a motor target. Configuration/readback success is not evidence of physical step-in lacing or double-tap release.

## Schema-derived Quick Unlace off

The archived `GestureOff` model supplies classification/action 1/1, serialized through opcode 178 as `b206000a0408011001`. This request is now implemented for the owner's requested off switch. The existing report captures that mapping on readback, but **does not contain a captured disable transaction or its acknowledgement**. The off write therefore remains schema-derived and physically unverified. It uses the same strict acknowledgement and exact readback checks as on; synthetic peer tests do not establish hardware behavior.

Multi-mapping replacement semantics remain unknown. Enabled and disabled mappings each survive a reported left-shoe reconnection, which establishes a connection interruption only, not power-cycle/reset persistence or physical release behavior. The captured enable write was not an established off→on transition.

Opcode 2 reads raw preset values 46/48. The report does not establish the preset-write command, displayed percentage mapping, or prove these are the step-in target. No fit selector is offered on Auto-Lace, and OpenAdapt Modes are not treated as its target.

## Verification

**89 Swift core tests pass**, covering the exact captured vectors, schema-derived off vector, authenticated setting flow, pair-state aggregation, saved-preference defaults/persistence/partial-failure retention, preserved unfamiliar/multiple mappings, already-in-state no-write behavior, negative/missing ACKs, readback failures, cancellation, and no replay. Three targeted Simulator UI flows pass across the final runs: Auto-Lace default-off and on/off, Quick Unlace on/off and entry readback, and pair-wide colors with existing independent/linked fit controls. The signed iPhone build passes. Physical feature behavior is a separate owner-operated check; no feature setting or actuator command was sent by development tools.

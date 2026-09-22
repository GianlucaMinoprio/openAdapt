# First-time iPhone pairing

September 21, 2026. The iOS implementation now discovers and connects both shoes automatically, requests physical button confirmation, verifies new credentials, and saves a native pair. **This flow has passed offline and Simulator checks; a factory-reset pair has not yet been enrolled by OpenAdapt on hardware.**

## User flow — September 22 refinement

The first-time experience is one large shoe illustration and one instruction at a time. It never shows separate connection cards, firmware rows, signal-strength labels, or a model picker.

1. Open **My shoes → + → Start**. Wake the shoes and hold the iPhone beside the shoe to pair first.
2. Discover supported advertisements automatically. Signal strength only chooses the nearest first candidate; physical left/right still comes from manufacturer metadata. More than one candidate for a side is ambiguous and stops setup.
3. Connect and check firmware on the first shoe, then prove setup readiness with the explicit setup credential. Show **Press a light on your shoe** only when the exchange is ready for physical confirmation.
4. Persist and authenticate the first candidate key. Only then identify the completed side on screen and show **Now your right shoe** or **Now your left shoe**. The second shoe never starts enrollment before the first has verified. If the partner was not discovered initially, scan for it at this step.
5. Prompt for the opposite shoe’s illuminated button, verify its key, then publish the complete pair and reconnect it. A failure leaves the first verified record available for retry and never reports the whole pair as complete.

The catalog names Nike Adapt BB, Huarache, AutoMax, BB 2.0, and Air Jordan 11 Adapt. Enrollment and control remain limited to the observed Auto Max `2.4.3M` firmware formats. Unknown firmware cannot enroll or control. Saved-pair **Connect** still connects both shoes together; only first-time enrollment uses sequential confirmation.

## Evidence recovered from Omarchy

Remote access now works through Tailscale SSH. Inspection was read-only; no wireless, reset, key-replacement, motor, or firmware experiment was run. Raw captures, device identifiers, keys, and proprietary source remain private and ignored.

- The original product manifest maps family `001` to Adapt BB, `002` to Huarache, `004` to AutoMax, `005` to BB2, and `006`/`007` to Air Jordan XI Adapt. `003` is a prototype entry and is not enabled as a retail model.
- Manufacturer data uses company `0x0078` and payload prefix `AF28`. The next five bytes form an opaque shoe identity; the following byte's low bit identifies right (1) or left (0). Other bits are not proven reset-state flags. Identities identify individual shoes, not a shared pair.
- No reliable factory-reset advertisement flag was established. The original implementation and original iPhone capture use setup-key authentication (`112/113`) before enrollment (`110/111`). Normal saved-key authentication never falls back to setup credentials.
- The original handler routes the empty `111` event to the button-confirmation screen. Its localized instruction says to press either light on the indicated shoe. The separate `111` ACK carries the peer public value. The owner previously confirmed pressing one unspecified button on each shoe; captures alone do not timestamp the physical press.
- Observed original exchanges used group 2 for one shoe and group 1 for the other. The public ACK arrived about 17.5 and 11.4 seconds after the corresponding public request. A 33-second exchange deadline is retained.
- Primary implementation evidence establishes MODP groups 0–3, generator 2, unsigned public values, prime-width padded shared-secret bytes, and MD5(shared secret) for legacy interoperability. A runtime iPhone private exponent/derivation known answer is not available. Independent synthetic arithmetic vectors are not a substitute for live validation.

See the dated [protocol analysis](../ENROLLMENT-PROTOCOL-VERIFICATION.md) and [Python model](../../spikes/002-local-enrollment/PROTOCOL.md) for earlier evidence.

## Implementation and recovery

Swift Crypto is pinned to **4.5.2** in both package resolution files. `ShoeEnrollmentExchange` uses that release's BoringSSL DH implementation through `CCryptoBoringSSL`; it does not implement custom big-integer arithmetic. The module is an internal dependency surface, so upgrading the pin requires rebuilding and rerunning the interop tests. CryptoKit supplies MD5 for compatibility with this legacy device protocol. These algorithms are not a recommendation for a new protocol.

Enrollment APIs are separate from normal command APIs. A journal in device-only Keychain records the attempt before command 110, and DH private/public state before command 111. A candidate derived from a complete peer response is persisted **before the final receive acknowledgement**. Only successful candidate authentication marks it verified. Profile publication occurs after both verified records are saved; journal cleanup follows profile persistence.

| Interruption point | Next explicit retry |
| --- | --- |
| Before enrollment starts | Retry setup authentication |
| Exchange started, no peer value saved | Stop; explain manual reset is required before another exchange |
| Candidate saved | Authenticate that candidate only; no setup fallback or repeated exchange |
| One foot verified | Preserve it and retry its authentication while completing the partner |
| Both verified, profile save failed | Retry profile publication using the retained records |
| Saved profile committed | Keep the pair even if journal cleanup fails |

“I’ve reset both shoes” acknowledges a user-performed reset; it archives previous attempts instead of deleting their recovery keys. The app never sends a reset command. Cancellation closes temporary links. An unrecoverable lost peer response may require a manual reset: storing our private value cannot recover an unknown peer public value. Shoe-side commit timing and persistence through power cycles remain unverified.

## Native profile and calibration limit

New profiles use CoreBluetooth UUIDs and manufacturer identities, without fabricated Linux MAC addresses or inherited fit calibration. The credential is marked verified only after new-key authentication. Model/side come from verified metadata. The owner’s imported profile remains intact.

No trustworthy fit-calibration read was established. Newly enrolled profiles therefore store an unknown maximum (0); L/R dragging, saved-mode application, and Siri fit commands cannot send fit targets. The app explains this before setup and after saving. Battery and base-light controls can operate after authentication; use the physical shoe buttons for fit. Existing imported calibrated shoes keep their controls. Never copy the owner's measured maxima to another pair or assume 100.

## Verification and next hardware check

The current Swift suite passes **77 tests**, including all four DH groups, invalid peer values, physical-side parsing, enrollment ordering, timeout, cancellation, candidate storage failure, no replay, candidate-only recovery, partial native profile rejection, and unknown calibration. Simulator tests cover sequential confirmation, both possible starting sides, first-step failure without advancing, cancellation, saving a synthetic pair, and reset guidance. Signed iPhone build succeeds. See [verification](VERIFICATION.md) for final build/install evidence.

An owner-operated physical check still needs to establish successful button confirmation, candidate authentication, reconnect after app restart, and shoe power-cycle persistence. No test result claims those have happened. Fit calibration, additional model/firmware support, and OTA remain separate work.

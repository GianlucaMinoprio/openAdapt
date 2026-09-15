# Auto Max enrollment implementation and verification

> Historical research checkpoint. For current capabilities, test totals and remaining work, see [Project status](STATUS.md). Statements below describe the evidence available at the checkpoint date.

**Live Auto Max authentication verified, September 15 07:13 UTC:** OpenAdapt authenticated with both owned shoes using the recovered current keys. Both 12-fragment transcripts independently verify the 112/113 exchange and final shoe ACK; both shoes disconnected cleanly and both laptop bonds remain intact. The observed 20-byte, zero-padded firmware field is now accepted explicitly; **202 tests pass**. The encrypted backup refresh and Nike-only extraction are complete. Fresh enrollment after reset, Huarache authentication and motor control remain unproven. See [the live authentication report](AUTO-MAX-HOST-AUTHENTICATION.md). Earlier dated checkpoints below describe prior states.

September 13 Pacific / September 14 UTC. The owner asked Codex to work through independent enrollment/authentication after completing the original-app new-profile setup. This work uses existing local captures and archived primary APK/DEX evidence. No phone or shoe command was issued during this analysis.

## What is now supported offline

The owner subsequently clarified that Nike Adapt requested a button press to confirm connection, and they pressed **one unspecified button on each shoe**. This supports a physical confirmation step; it does not establish exact event-to-button timing or that every button is interchangeable.

Both recorded initial 112/113 exchanges reproduce AES proofs using the static setup key from the archived app. The final app proofs after enrollment use different, currently unrecovered keys. The public existing-key API continues to reject the setup key and never tries it as a fallback.

The explicit `Session.enroll_auto_max` model now sends setup authentication, 110, 111 with an intermediate event, stores the new candidate, and authenticates with that candidate: **112 / 113 / 110 / 111 / 112 / 113**. Existing-key authentication remains **112 / 113**. The modeled exchange timeout is 33 seconds, corroborated by archived DEX `Lhc/f;.run` and longer than both observed 111 delays (17.528 seconds right, 11.365 seconds left). One empty 111 event is accepted only during the explicit exchange operation. It notifies an immediate observer and does not complete the exchange; a separate ACK is still required. Unknown/nonempty/duplicate events, NAKs, cancellation and timeout remain terminal without replay.

## Peer proof interpretation

With independently matched keys, all 18 available known-key exchanges decrypt opcode 112 field 1 into an opaque four-byte prefix followed by the final twelve bytes of the client's nonce. Those comprise 16 historical saved-key exchanges and two setup-key exchanges. The prefix's meaning remains unknown.

`ProofFormat.AUTO_MAX_2_4_3M` explicitly verifies the 96-bit nonce suffix in constant time after AES decryption. It retains a cryptographic challenge check without asserting a meaning for the four unknown bytes. The client uses a fresh 16-byte CSPRNG nonce. The default `FULL_BLOCK` policy remains unchanged, and no failure selects another proof format or key. This profile is specific to the observed Auto Max firmware, not a claim about Huarache or future firmware.

All 18 actual-session message replays now emit byte-identical original-app authentication requests and accept the captured final ACK. The full-block mode still rejects those same 18. Wrong-key, replayed-nonce and mutated-suffix tests fail before opcode 113. Four post-enrollment exchanges remain outside key validation because their current keys have not been recovered.

## Fragment-level verification

An initial replay exposed two transport differences from the earlier APK-derived model: a received flow packet made the prototype acknowledge data fragment zero, whereas the iPhone acknowledges data fragments 1, 3, 5, etc.; and the prototype allowed only three outstanding fragments after an ACK instead of the four observed in the trace.

`TransportProfile.AUTO_MAX_CAPTURE` implements the observed cadence and counts an ACK as accepting its named fragment. It retains a four-fragment outstanding limit, expected-ACK validation and independent modulo-64 data counters. The earlier `APK_MODEL` remains the default.

Raw replay through the actual revised session core and transport consumes **all 49 right and 40 left recorded fragments** from setup authentication through the 111 ACK. **All 44 outgoing fragments match byte for byte** (24 right, 20 left), including flow ACKs; both ready events and both public-value responses are accepted. The replay uses recorded public values and supplies no private DH exponent or new shared secret. It does not claim to derive the newly enrolled application key. Recorded delays are collapsed; separate tests cover bounded waiting and missing final ACKs.

## Existing-key hardware path prepared

`ExistingKeyLink` accepts an explicit `AUTO_MAX_2_4_3M` profile. Before subscription or Nike writes it requires an owner-confirmed family-004 target, an existing local bond, an explicitly disconnected device, one readable standard firmware characteristic, and an exact live firmware value of `2.4.3M`. It then selects the captured transport/proof formats and writes without response, as observed from iPhone. Unsupported firmware or missing/ambiguous characteristics stop before Nike traffic.

The path still sends only authentication and its flow ACKs, then disconnects with bounded cleanup. It never invokes enrollment, changes keys, pairs automatically, performs post-authentication queries or controls motors. The CLI remains offline-only. This path has synthetic lifecycle validation, including wrong-key rejection, firmware mismatch/read failure/cancellation, and cleanup; it has not authenticated a real shoe.

## Remaining work and required owner help

1. Obtain and offline-validate the current Auto Max application keys saved by the new Nike profile. The old keys remain preserved but do not match the new trace. A packet capture of public DH values alone does not supply the private shared secret.
2. Run a bounded, owner-attended existing-key authentication attempt after the app is closed and a current credential validates. It should preserve the working Nike profile and send no enrollment or actuator commands.
3. Before live replacement enrollment, finish review of candidate crash recovery and establish shoe key-commit/retention behavior. The synthetic DH fixed-width/MD5 tests and primary Android provider evidence do not establish an original iPhone runtime derivation known answer. Host enrollment is not enabled by this progress.

The existing encrypted backup is preserved. A new local reflink clone at `private/iphone-backup/20260914T034321Z/` was prepared and its metadata hashes checked; no source inode is shared for the checked metadata, and the source hashes remained unchanged. **No refresh of the phone has started.** A subsequent authorized continuation attempted USB discovery; no Apple USB device was present, `idevice_id` exited 255 and usbmuxd was inactive. It stopped before backup service access. The owner has been asked to reconnect and unlock the iPhone. No new permission to refresh the encrypted copy is pending; physical USB availability is required. Prepared `refresh_backup.py` requests an incremental encrypted update into that clone without forcing a full backup, changing encryption/password or restoring the phone. The installed backup tool has no Nike-only collection option, so a refresh still collects encrypted phone backup data; subsequent inspection remains limited to Nike. Unlocking the resulting local backup requires the owner to enter their existing backup password in a masked local dialog.

## Test checkpoint

The complete enrollment suite passes **198 tests in 1.49 seconds** at the final implementation checkpoint; the exact elapsed time varies by run. The CLI self-test also passes for the four generic groups and both observed Auto Max groups with the extra setup-authentication and ready-event phases. Discovery source is unchanged; its last recorded 37-test result was not rerun for this change. No hardware success is inferred from these checks.

## Private verification artifacts

- `private/iphone-hci/verify_protocol_revision.py` and `protocol-revision-20260914T034705684890Z/`: 22 complete exchanges; 18 with known matching keys and four unresolved current-key exchanges.
- `private/iphone-hci/replay_enrollment_fragments.py` and `fragment-replay-20260914T034706071677Z/`: all 89 raw fragments consumed and 44 outgoing fragments matched. Earlier failing replay is retained separately.
- `private/iphone-hci/20260914T031052Z-actions-auto-max/owner-button-confirmation.private.json`: retrospective owner clarification, including one button per shoe.

All raw packets, keys, identifiers, proprietary evidence and backup contents remain ignored and local. Nothing has been staged, committed or pushed. The owner's 80/80 request remains unexecuted; the later fit check may have changed calibration, so older values are not a current position reference.

### Key-recovery helper verification

A subsequent offline check exercised the prepared current-key validator with two synthetic per-shoe keys and all four expected post-enrollment exchanges. It accepted the complete pair and rejected swapped side keys and a missing later exchange. This adds no current owner credential or hardware evidence. The iPhone was still absent from USB on the second continuation check, and no backup service or logging process was started. The existing reconnect request remains pending. Private result: `private/continuation/20260914T035200Z-protocol-implementation/current-key-verifier-check.json`.

### USB prerequisite blocked

At September 14 03:54:58 UTC, the third consecutive goal-turn check still found zero Apple USB devices, `idevice_id` exit 255 and inactive usbmuxd. No refresh-started record or refreshed snapshot exists. The goal is blocked on owner reconnection/unlock of the iPhone. Protocol work and local backup preparation are retained; current-key recovery and live authentication remain incomplete. Resume the prepared refresh after USB availability is revalidated.

### Resumed after iPhone update

On September 14 Pacific / September 15 06:44 UTC, the owner returned ready. Read-only USB preflight found the same saved iPhone, valid existing trust, iOS 27.0/build 24A437 and backup encryption still enabled. The prepared incremental refresh started in the isolated clone; the owner entered the requested phone passcode. This verifies access after the update, not backup completion or general iOS compatibility.

The owner confirmed Auto Max nearby and Nike Adapt fully closed for the later existing-key authentication test. A private one-attempt runner uses the existing firmware-gated lifecycle and records bounded characteristic fragments; a separate offline verifier checks the resulting 112/113 exchange. Synthetic checks cover success, wrong-key rejection, missing-bond refusal, truncated transcript rejection and rejection of an extra enrollment command. No production CLI was enabled, no shoe authentication was started, and current keys remain pending until the refreshed backup completes and its Nike database is unlocked. The private checkpoint is `private/continuation/20260915T064400Z-current-key-recovery/`.

### Current Auto Max credentials recovered — September 15

The isolated incremental refresh completed with exit 0, `Backup Successful`, finished encrypted metadata and unchanged original backup metadata. It received 17,080 files in 1,300 seconds. The refreshed snapshot identifies iOS 27.0 and `IsFullBackup: false`. An initial password did not unlock the backup; the owner re-entered it locally and Nike-only extraction then succeeded. No password was retained. Only the 3,077-byte Nike saved-device database was extracted; no keychain or other-app files, and zero temporary decrypted files remain.

Both newly saved Auto Max application keys match every post-enrollment exchange: one right and three left. Each reproduces the app proof, verifies the 96-bit peer challenge and completes the actual-session replay with the captured successful ACK. Together with the earlier 18 known-key replays, all 22 available complete exchanges now have matching credentials. This does not recover DH private exponents or prove replacement enrollment.

Current private evidence: `private/iphone-backup/20260914T034321Z/saved-devices-20260915T070750Z/key-validation-20260915T070844696008Z/`. The first bounded right-shoe live test found no fresh exact-target advertisement and stopped before connecting, with zero characteristic fragments and both local bonds retained. Its evidence is `private/continuation/20260915T070900333846Z-auto-max-right-existing-key-auth/`. The owner has been asked to wake both Auto Max shoes normally while leaving Nike Adapt closed.

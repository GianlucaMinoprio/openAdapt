# Saved iPhone application keys

> Historical research checkpoint. For current capabilities, test totals and remaining work, see [Project status](STATUS.md). Statements below describe the evidence available at the checkpoint date.

**Live Auto Max authentication verified, September 15 07:13 UTC:** OpenAdapt authenticated with both owned shoes using the recovered current keys. Both 12-fragment transcripts independently verify the 112/113 exchange and final shoe ACK; both shoes disconnected cleanly and both laptop bonds remain intact. The observed 20-byte, zero-padded firmware field is now accepted explicitly; **202 tests pass**. The encrypted backup refresh and Nike-only extraction are complete. Fresh enrollment after reset, Huarache authentication and motor control remain unproven. See [the live authentication report](AUTO-MAX-HOST-AUTHENTICATION.md). Earlier dated checkpoints below describe prior states.

**Protocol update, September 14 03:45 UTC:** the explicit Auto Max 2.4.3M proof format now validates the captured 12-byte nonce suffix while treating the four-byte prefix as opaque. All 18 known-key actual-session replays succeed, including 16 old saved-key exchanges and both new setup-key exchanges. The default full-block check remains strict. Four post-enrollment current-key exchanges remain unvalidated; current key recovery is still needed. See [implementation verification](ENROLLMENT-PROTOCOL-VERIFICATION.md).

**Current credential result, September 14 03:20 UTC:** both Auto Max new-profile enrollment exchanges and owner-completed fit check are now captured. All six complete successful original-app authentication exchanges in that trace fail the historical saved-key app-proof comparison, including both exchanges before 110/111. The old files remain historical evidence; no current application key has been recovered. This comparison does not test whether a shoe accepts an old key via another slot/path. It cannot diagnose the earlier four-byte peer-proof mismatch using these now-mismatching keys. See [the completed enrollment capture](ORIGINAL-APP-ENROLLMENT-CAPTURE.md#successful-new-profile-setup-and-fit-check) and private `auth-audit-20260914T032031056933Z/`.

September 13, 2026. The owner authorized completing the encrypted local backup and inspecting only Nike data, then returned and entered the backup password in a masked local dialog. The backup was not repeated.

**Later state change:** the Auto Max keys below remain evidence of historical successful authentication, including three additional exchanges after owner-observed physical green-light reset indicators. A later original-app removal explicitly sent `fw system_reset` to both shoes; current application-key validity after that command is unverified. The owner subsequently requested computer Bluetooth pairing, and both Auto Max laptop bonds are now saved and disconnected. That does not validate or replace the Nike application keys. Huarache's app profile remains saved; its owner-reported new iPhone Bluetooth pairing has not yet supplied a matching captured application-key proof. See [computer pairing](COMPUTER-PAIRING.md) and [the reset/setup trace](ORIGINAL-APP-ENROLLMENT-CAPTURE.md). Earlier no-bond/no-reset statements below are historical.

## Result

Four 16-byte application keys were recovered from Nike Adapt's saved-device JSON database: the left and right Huarache and Auto Max shoes. They remain in ignored owner-only local files. No keychain extraction was needed.

| Pair | Saved keys | Verification |
|---|---|---|
| Auto Max | Left and right | Each exactly reproduces the original app's opcode 113 AES response to its shoe's recorded nonce. Both recorded sessions end with an empty successful opcode 113 ACK. |
| Huarache | Left and right | Extracted from the saved Huarache profile; no matching Huarache HCI exchange has yet validated them. |

The Auto Max keys were checked independently using PyCryptodome and the prototype's `crypto.encrypt`, backed by `cryptography`. The prototype codec separately accepts all four captured handshake envelopes and both response schemas. The left profile matches capture alias `shoe_2`; the right matches `shoe_1`. Those aliases were scan-order labels, not anatomical sides.

This establishes possession of application credentials that match the original Auto Max app's recorded authentication. It does **not** establish successful authentication by the replacement controller, a laptop Bluetooth bond, motor control, or current validity of the Huarache keys. The separately captured BLE link keys are different credentials.

## Concrete prototype blocker

The current session adds a stricter check than the inspected Android client: it expects the first field of the opcode 112 response to equal AES encryption of the entire client nonce. **Both real Auto Max exchanges fail that check even with the now-validated application keys.** Decrypting that field reproduces the final 12 bytes of the client nonce, but its first four bytes differ on both shoes. The transformation or purpose of those four bytes is unresolved. A bounded check of common byte-order transformations did not explain it.

An offline replay used the recorded nonce and response in the actual `Session.authenticate_existing` code. Both replays failed with `peer nonce proof mismatch`, closed the synthetic transport, and sent only opcode 112. The original app continues with a cryptographically matching opcode 113 response and receives its successful ACK.

The earlier generic key scanner required both nonce comparisons and therefore reported zero matches. That was a false negative for these saved keys under an unsupported full-block peer-proof assumption. The saved-key validator instead records the exact app response match and successful original-app ACK, while separately reporting the peer-field mismatch. It does not hide or relax the prototype check.

The default full-block authentication policy remains unchanged. The later explicit Auto Max compatibility profile validates the observed 96-bit nonce suffix; its verification is described in ENROLLMENT-PROTOCOL-VERIFICATION.md. Do not run the current strict session against a shoe expecting it to succeed, and do not infer permission to enroll, replace keys, or bypass Bluetooth bonding from credential recovery.

### Expanded replay after the action recordings

The later owner request to set both shoes to 80/80 prompted a broader offline check. Thirteen complete original-app exchanges across the original HCI and subsequent action captures match the saved application keys: six right and seven left. Every original opcode 113 response is reproduced and every exchange has a successful original-app final ACK. All 13 first response fields preserve the last 12 nonce bytes while changing the first four; all 13 actual strict-session replays fail at that comparison before opcode 113.

The changed prefixes are distinct, nonzero and not explained by a constant XOR/difference, a matching four-byte window from the shoe nonce, the checked CRC32 forms, a monotonic counter or a Cortex-M RAM pointer pattern. These are bounded rejected hypotheses, not an interpretation of the field or permission to discard validation. No shoe firmware image was present in the inspected private evidence. The policy remains unchanged. Private reproducible analysis is under `private/iphone-hci/auth-audit-20260913T233731898935Z/`, generated by `audit_auth_corpus.py` using the locked enrollment runtime.

A read-only BlueZ object-manager query found neither owned shoe registered locally. No bond was created/imported, and no host motor command followed. The owner's requested 80/80 remains unexecuted pending authentication and connection readiness.

## Extraction and private evidence

The completed backup has 66 manifest entries within the three exact Nike app/group domains. The scoped inspector extracted 22 regular files totaling 607,147 bytes. The credential-bearing file is `com.nike.adaptkit.sharedStorage.database.d.v00005`, a JSON database containing both saved pairs. Its profile names and product-family prefixes distinguish Huarache (002) and Auto Max (004).

Two Nike WebKit database files failed the decoder's file-length check and were skipped. The preliminary generic scanner also encountered one WebKit SQLite error. These errors do not affect the successfully decoded saved-device JSON or its cryptographic checks; no broader extraction was attempted to investigate unrelated phone data. The temporary decrypted manifest was removed after extraction.

Private artifacts are under `private/iphone-backup/20260913T205325Z/analysis-20260913T222404Z/`:

- `nike-inventory.private.json`: exact extraction scope and per-file results.
- `saved-shoe-keys.private.json`: all four saved credentials, with separate extracted-only and capture-validated states.
- `recovered-application-keys.private.json`: the two Auto Max keys validated against original-app HCI.
- `application-key-validation-summary.json`: redacted cryptographic checks and actual-session offline replay results.
- `peer-field-difference.private.json` and `peer-prefix-relations.private.json`: scoped follow-up on the differing nonce prefix.

Use `spikes/002-local-enrollment/.venv/bin/python private/iphone-backup/validate_saved_keys.py` for the saved-key validation logic; it writes new artifacts exclusively and must not overwrite an existing run. The initial `find_nike_key.py` scan and its zero dual-proof match count are historical diagnostic results, superseded for credential recovery by the saved-key validation summary.

The owner confirmed profile removal after the original key-recovery step, then reinstalled it for later action recordings and explicitly chose to retain it. Those later computer recordings are now stopped; see [action findings](ORIGINAL-APP-ACTIONS.md). No phone restore, new shoe pairing, local bond import, application-key replacement, enrollment, host actuator command, J-Link open or firmware operation occurred.

### Current Auto Max credentials recovered — September 15

The isolated incremental refresh completed with exit 0, `Backup Successful`, finished encrypted metadata and unchanged original backup metadata. It received 17,080 files in 1,300 seconds. The refreshed snapshot identifies iOS 27.0 and `IsFullBackup: false`. An initial password did not unlock the backup; the owner re-entered it locally and Nike-only extraction then succeeded. No password was retained. Only the 3,077-byte Nike saved-device database was extracted; no keychain or other-app files, and zero temporary decrypted files remain.

Both newly saved Auto Max application keys match every post-enrollment exchange: one right and three left. Each reproduces the app proof, verifies the 96-bit peer challenge and completes the actual-session replay with the captured successful ACK. Together with the earlier 18 known-key replays, all 22 available complete exchanges now have matching credentials. This does not recover DH private exponents or prove replacement enrollment.

Current private evidence: `private/iphone-backup/20260914T034321Z/saved-devices-20260915T070750Z/key-validation-20260915T070844696008Z/`. The first bounded right-shoe live test found no fresh exact-target advertisement and stopped before connecting, with zero characteristic fragments and both local bonds retained. Its evidence is `private/continuation/20260915T070900333846Z-auto-max-right-existing-key-auth/`. The owner has been asked to wake both Auto Max shoes normally while leaving Nike Adapt closed.

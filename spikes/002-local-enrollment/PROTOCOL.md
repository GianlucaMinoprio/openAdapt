# Restricted protocol model and unresolved boundaries

This is original analytical prose about the locally archived APK 1.29.3, not a firmware specification. Fixtures are synthetic. Proprietary code, detailed bytecode and owner captures remain outside the distributable source.

## Model

A message has a one-byte opcode, a little-endian 16-bit word (low 14 bits payload length; high two bits action), and its payload. Actions are request 0, ACK 1, NAK 2, event 3. This client accepts at most 513 payload bytes and only opcodes 110–113. Unknown/duplicate protobuf fields and malformed lengths stop the attempt.

| Opcode | Request | Matching ACK payload |
|---|---|---|
| 110 | Empty enrollment-start payload | Varint field 1: group 0–3; empty payload means proto3 default group 0 |
| 111 | Bytes field 1: DH public value | Bytes field 1: peer public value |
| 112 | Bytes field 1: 16-byte client nonce | Bytes field 1: 16-byte peer field, whose decrypted four-byte prefix differs from the client nonce in captured Auto Max exchanges; field 2: 16-byte device nonce |
| 113 | Bytes field 1: encrypted device nonce | Empty payload |

Groups 0–3 use the standard 768/1024/1536/2048-bit MODP primes and generator 2. The APK strips a leading sign byte from its positive public integer; it interprets received public bytes as unsigned. The application key is MD5 of the Java-provider DH shared-secret bytes. Archived Android provider code pads that secret to the prime width. Synthetic leading-zero tests cover this model, but no original-app runtime known-answer exchange has validated the provider assumption on the owner devices. AES uses one block, ECB, no padding.

The inspected Android app consumes the device nonce without exposing a check of the encrypted client nonce to its caller. The default prototype policy compares the complete proof. An explicit Auto Max 2.4.3M profile instead verifies the recorded 96-bit nonce suffix after AES decryption, with a constant-time comparison; the preceding four bytes remain opaque. This profile is never selected after a failed check and is not a Huarache compatibility claim.

Later Auto Max evidence contradicts the full-block comparison: both recovered application keys reproduce the recorded opcode 113 AES response, but decrypting opcode 112's first field preserves only the final 12 client-nonce bytes. The first four differ in each exchange. The default full-block policy therefore rejects before opcode 113. All 18 known-key actual-session replays pass the explicit Auto Max suffix rule and emit the captured opcode 113 ciphertext. The prefix's meaning is still unresolved; the comparison does not authenticate those four bytes. The two saved Huarache keys have no corresponding runtime validation yet. See `docs/IPHONE-KEY-FINDINGS.md` from the project root.

## Transport

Messages are split into 19-byte data pieces, each prefixed with a six-bit sequence. Bit 7 marks the final piece; bit 6 distinguishes flow control. Sending and receiving maintain independent modulo-64 counters across messages.

Accepted flow ACKs have two bytes: header bits 6+7 set, acknowledged sequence in low bits, second byte zero. The sender starts with window base 0 and expects ACK 1, then 3, 5, etc. It holds a fragment when its distance from the acknowledged base reaches four. ACKs for unsent or unexpected sequences stop the attempt. The APK has a sequence-zero special case; this prototype conservatively applies the same window bound at wraparound. Its synthetic wrap test does not establish firmware compatibility.

Receive ACK cadence follows the inspected APK branches: after the first received packet, incomplete data messages may receive a flow ACK; complete messages are ACKed when their sequence is one beyond the receiver ACK base. Complete envelopes and response schemas are validated before that final flow ACK. Earlier fragments may need ACKs before the complete schema is known.

NAKs, unsupported events, resend/error flow codes, duplicates, out-of-order data, overflow, premature/stale replies and timeout/cancellation close the attempt. The explicit public-key exchange operation permits one empty opcode-111 event while awaiting its separate ACK, with a bounded 33-second timeout. Duplicate/nonempty events remain terminal, and the event never establishes key commitment. They never trigger key deletion, replay, another enrollment, reset, battery/clock/firmware queries, or actuation. A notification callback must run on the owning asyncio loop; the new BlueZ lifecycle fails closed if another callback thread is observed.

The explicit `AUTO_MAX_CAPTURE` transport profile follows the observed iPhone cadence: ACK data fragments 1, 3, 5, etc., independent of received flow packets. After an ACK it allows four outstanding data fragments by counting the named fragment as accepted. The older APK-derived conservative model above remains the default. Raw offline replay consumes all 89 setup fragments and emits 44 byte-identical outgoing fragments for the two owned Auto Max shoes through their 111 ACKs. Separate negative tests preserve the transmit bound and terminal failure behavior.

## Existing-key BLE lifecycle

`ble_link.py` now provides a factory-injected, single-use Linux/BlueZ path for opcodes 112/113. It validates the key before scanning, selects an exact owner-confirmed address/product name from fresh Nike advertisements, and requires both `Paired` and `Bonded` in the local BlueZ device properties before constructing a client. It uses `pair=False`, validates fixed service/characteristic uniqueness and properties, subscribes, and disconnects after the handshake. The explicit Auto Max link profile first reads the standard firmware revision and requires exact `2.4.3M` on a family-004 target before selecting its proof/transport formats and writes without response. Missing keys or bonds never trigger enrollment/pairing. The firmware gate accepts `2.4.3M` unpadded or in the observed 20-byte zero-padded field. In addition to synthetic lifecycle tests, this path has now authenticated both owned Auto Max shoes with successful ACKs, independently verified transcripts and clean disconnects. This does not establish Huarache or cross-platform support; see `docs/AUTO-MAX-HOST-AUTHENTICATION.md`.

The continuation review also requires an explicit `Connected: false` observation before constructing a client. Bleak 2.1.1 otherwise adopts a connection already open on this laptop, and subsequent cleanup would disconnect that existing session. Missing, true or non-boolean connection state stops before client construction. This is a preflight observation, not an exclusive lock: other local clients must stay inactive during a future attempt. The installed backend can internally retry one particular pre-authentication connection-abort condition; the single-use guarantee applies to this client's application handshake and prohibits application-command replay, not every underlying radio connection attempt.

After the owner restored the original iPhone app's Bluetooth permission, the September 13 successful-connection reference recorded writes without response to both Auto Max identities. The earlier GATT inspection advertised both `write` and `write-without-response` on the fixed command characteristic. This runtime observation does not establish that this prototype's use of write-with-response is invalid; it is a concrete interoperability question for an eventual credential-backed comparison. These system logs do not expose a decoded application handshake or recover the application key. See `docs/IPHONE-LOG-FINDINGS.md` from the project root.

A later owner-authorized USB HCI capture on the same date directly reconstructed both original-app opcode 112/113 exchanges, including successful empty final ACKs. The observed nonce/proof field lengths and ACK schemas pass this codec; 134 application envelopes and 75 flow-control packets reconstructed without sequence/length errors. Subsequent Nike-only backup inspection recovered both Auto Max application keys and independently reproduced the recorded opcode 113 responses. This adds a real existing-key wire-format and AES reference, but does not validate the prototype's live lifecycle, DH derivation or enrollment. The separate BLE link keys observed in HCI do not satisfy the application proofs. Raw fragments, proofs and keys stay in ignored private evidence.

## New original-app enrollment reference

The owner-operated Auto Max new-profile capture contains complete 110/111 exchanges on both shoes. Right selects group 2 and exchanges 192-byte public values; left selects group 1 and exchanges 128-byte public values. Both emit an empty opcode-111 event before their public-value ACK, then complete 112/113 with an empty final ACK. The owner confirms pressing one unspecified button on each shoe when Nike Adapt requested confirmation; exact event-to-tap timing is unmeasured.

Before 110/111 the app authenticates with its static setup key. Both captured initial AES responses validate against that key. `Session.enroll_auto_max` explicitly models this sequence, permits the single intermediate event through the dedicated transport operation, derives and saves the candidate, then authenticates with the new key. The public existing-key API still rejects the setup key and never invokes enrollment as a fallback. Synchronous event observers must return promptly; the whole session and each exchange have separate bounded deadlines.

Of six complete authentication exchanges in the new-profile trace, two match the setup key and four use the current per-shoe keys, subsequently recovered from Nike-only backup inspection and validated against all four exchanges. None match the old saved per-shoe application keys. Public values do not supply private DH exponents or current app keys. This trace does not validate our MD5/provider derivation or shoe key persistence. See `docs/ENROLLMENT-PROTOCOL-VERIFICATION.md` for the source anchors, original-app replays and remaining hardware work. All observation was through USB while the owner operated Nike Adapt; no host enrollment or control occurred.

## Persistence and remaining risks

Enrollment saves a derived candidate before authentication, with `UNVERIFIED` status even after a simulated ACK. Existing files and symlinks are never replaced. Failed atomic publication intentionally retains an owner-only `.pending-*` record for recovery; this is private key material. Storage failure or interruption can leave an incomplete or unpublished candidate and requires manual review. There is no automatic promotion or recovery procedure.

Vault preparation syncs the vault's parent directory before any key write, including on retries using an existing directory. A parent-sync failure stops preflight without creating a credential or pending record. This closes a directory-creation durability gap; it does not resolve recovery after an interrupted two-name hard-link publication or the shoe's own key-commit behavior.

The shoe's key commit point, physical-confirmation requirements, number of supported keys, old-key retention and behavior after interrupted exchange are unknown. Saving earlier reduces one local key-loss window; it cannot make enrollment or reset safe. Live enrollment is not ready while these questions and the independent review remain unresolved. The new existing-key lifecycle does not enable enrollment.

## Local primary evidence anchors

Under the original research copy's read-only, ignored `private/apk-analysis/`:

- `disassembly/hc_m0.txt`, `hc_f.txt`, `hc_q.txt`, `hc_i.txt`, `hc_j.txt`, `hc_v.txt`, `gc_c0.txt`, `gc_d0.txt`: envelope, enrollment, nonce fields and crypto calls.
- `decompiled/sources/hc/l.java`, methods `I` and `c`; `hc/e.java`, methods `l` and `p`; `hc/q0.java`: handshake and transport behavior. Critical transmit-window, public-key sign-byte and flow-control paths were also checked against the archived DEX extraction.
- `../enrollment-protocol-audit/dex-check.json`: 91 selected method records with DEX hash/offsets, inspected read-only. The planned final `REPORT.md` does not exist at takeover.
- `../enrollment-build/rfc2409.txt`, `rfc3526.txt`, `Android13-DH.java`: standard group definitions and provider encoding evidence.

The archived APK SHA-256 is recorded in `docs/APK-NOTES.md`. No third-party controller implementation was copied or executed.

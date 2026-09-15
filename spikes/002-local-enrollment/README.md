# Local enrollment research spike

**September 15:** the separate existing-key control path has now laced both owned Auto Max shoes, with verified completion/readback and owner physical confirmation. **253 tests pass.** The public CLI remains offline-only. Hardware tests are paused at the owner's request. See [CONTROL.md](CONTROL.md) and [the live report](../../docs/AUTO-MAX-MOTOR-CONTROL.md).

**Research prototype with verified existing-key authentication on both owned Auto Max shoes. The CLI remains offline-only; fresh enrollment, Huarache authentication and motor control are unproven.**

The original implementation models enrollment and existing-key authentication from locally inspected APK protocol evidence. A synthetic peer exercises all four MODP groups, segmented requests/responses, transport ACKs, candidate-key storage and a fresh existing-key session. Neither its success nor the unit tests demonstrate shoe authentication, safe key replacement, or motor control.

## Run offline

```sh
cd spikes/002-local-enrollment
uv sync --locked --python 3.11
.venv/bin/python -m pytest -q
.venv/bin/python adapt_enrollment.py offline-self-test
```

Create a local virtual environment in this working copy using `uv` and the committed lock file. The CLI accepts only `offline-self-test`; it has no address, real-key import, enrollment, reset, or motor option. Temporary synthetic key records are removed when the self-test finishes. Output never includes keys, nonces, device identifiers or raw frames.

## Components

- `wire.py`: restricted message framing and protobuf schemas for opcodes 110–113.
- `crypto.py`: standard MODP groups, unsigned public values, fixed-width shared-secret hashing and single-block AES. Legacy algorithms are for compatibility research.
- `transport.py`: one outstanding request, bounded notifications/deadlines and modulo-64 sequencing. The explicit Auto Max profile matches recorded flow-ACK cadence and four-fragment windows. Its dedicated public-key exchange accepts one empty 111 event and continues awaiting the ACK. Failures close the transport without retry/replay.
- `keyfile.py`: owner-only directories/files, no symlink traversal or replacement, immutable `UNVERIFIED` candidate records.
- `session.py`: separate existing-key, generic enrollment and explicit Auto Max setup paths. Missing/sentinel keys never select enrollment implicitly. Auto Max setup models the preliminary setup-key authentication and intermediate 111 event; candidate persistence precedes new-key authentication. The explicit Auto Max proof format verifies the 12-byte nonce suffix, while the default retains full-block comparison.
- `simulation.py`: explicitly synthetic in-memory peer; contains no hardware integration.
- `ble_link.py`: single-use existing-key BlueZ lifecycle. Its explicit Auto Max profile checks family 004 and live standard firmware 2.4.3M before any Nike subscription/write, then selects the captured proof/transport behavior. It requires a valid application key, exact fresh owner-confirmed target, existing local bond and an explicitly disconnected target; subscribes for authentication only; then disconnects with bounded cleanup. No automatic pairing, enrollment or post-authentication command. Default factories are limited to Linux/BlueZ.

`Session` accepts an injected transport and does not manage BLE. `ExistingKeyLink` offers a restricted authentication lifecycle but is not exposed by the CLI and has authenticated both owned Auto Max shoes through a private, bounded test runner. It never invokes either enrollment method. The known-key core replays all 18 original-app exchanges for which a key is available; the explicit Auto Max transport reproduces all 44 outgoing fragments through both setup public-key ACKs. Both results are offline evidence. Current Auto Max keys have been recovered and validated against all four post-enrollment recordings. Both live host transcripts also verify; the complete suite now passes 202 tests. The firmware gate accepts `2.4.3M` unpadded or in the observed 20-byte zero-padded field. See [live authentication](../../docs/AUTO-MAX-HOST-AUTHENTICATION.md). Live replacement enrollment and control remain unimplemented; see [the current verification report](../../docs/ENROLLMENT-PROTOCOL-VERIFICATION.md).

See [protocol and limits](PROTOCOL.md), [takeover review](../../docs/CODEX-REVIEW.md), and [verification](../../docs/CODEX-VERIFICATION.md).

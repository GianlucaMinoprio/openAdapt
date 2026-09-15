# Verification checkpoint

September 15, 2026. These results apply to the initial source checkpoint. Earlier detailed working notes are retained locally in ignored publication-preparation backups.

## Offline software

| Check | Result |
|---|---:|
| Discovery suite, `spikes/001-ble-discovery` | 37 passed |
| Protocol and Omarchy backend suites, `spikes/002-local-enrollment/tests` and `apps/omarchy/tests` | 337 passed |
| Qt Quick UI suite, `apps/omarchy/tests/qml` | 14 passed |

The suites were rerun from this working copy with its local environments. The lock files reference public PyPI distribution hosts. The Qt total includes setup and cleanup checks. The native plugin manifest also passed Omarchy validation during app verification.

Coverage includes authentication proof formats, bounded framing/reassembly, sequence wrap, firmware/bond checks, cancellation and cleanup, no command replay, repeated explicit controls on one connection, saved-pair selection, empty state and slider interactions. The local JSON-line backend was checked for startup/status/EOF without radio access.

Commands to reproduce these checks are in the [root guide](../README.md) and [Omarchy guide](../apps/omarchy/README.md). None of the offline suites requires shoes, an iPhone or the Nordic board.

## Hardware evidence

Both owned Auto Max shoes authenticated using their current application keys. Later empty-shoe motor tests each returned successful completion and corroborating position readback; the owner confirmed both shoes physically laced. See the [authentication report](AUTO-MAX-HOST-AUTHENTICATION.md) and [motor report](AUTO-MAX-MOTOR-CONTROL.md).

The persistent Omarchy backend subsequently connected both shoes. Private transcript review established one handshake per shoe, two further battery refreshes, five owner-operated color changes per shoe and one owner-operated left motor target on those connections. The agent's connection check sent connection/status operations only. After the owner selected Disconnect, both devices were independently verified disconnected, paired and bonded. Credentials were unchanged.

The base-light codec also matches 858 original-app message envelopes across seven recordings. Offline envelope matching and live command acknowledgements do not establish physical LED appearance, which awaits owner feedback. Numeric latency improvement was not independently measured.

## Limits

Fresh enrollment by OpenAdapt, key retention/crash recovery, Huarache control, worn-shoe behavior, exact original-app display rounding and broader firmware compatibility remain unvalidated. No new phone capture, backup, radio test, motor operation or Nordic operation was needed for the source-push checks.

## Source review

The initial source review excludes raw captures, credentials, identifiers, proprietary APK/decompiled code, downloaded tools and historical root reports. Local research paths and internal conversation-location details were removed from the working handoff. The original notes remain ignored and local. Repository visibility is handled separately from the code's MIT license.

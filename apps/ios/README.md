# OpenAdapt for iPhone

An original native SwiftUI/CoreBluetooth client for Nike Adapt Auto Max. iOS 17 or later. MIT licensed under the repository's [license](../../LICENSE). No account, server, analytics, third-party runtime dependency, or Nike assets.

<p><img src="../../docs/ios/screenshots/fit.png" width="220" alt="Independent fit controls in the labeled simulator demo"> <img src="../../docs/ios/screenshots/fit-blue.png" width="220" alt="Background follows the selected blue shoe lights"> <img src="../../docs/ios/screenshots/fit-lights-off.png" width="220" alt="White background with lights switched off"></p>

**Development build, not yet a public download.** This iOS port is built and tested offline and in Simulator, and both current Auto Max shoes have authenticated and returned status on the owner’s iPhone. Physical iPhone shoe movement, LED appearance, Siri execution, and haptic feel still require hardware validation. The desktop implementation's successful shoe tests do not verify this new CoreBluetooth implementation.

## Experience

- Oversized L/R controls with independent simultaneous touch tracking or linked adjustment.
- Direct finger tracking, fit steps of 5%, haptic selection ticks, release feedback, and confirmed-completion feedback.
- During a drag, a target bar follows its L/R control immediately. On release, the letter and a faint target bar hold the selected level while a second, solid bar advances from the last measured position. The estimate takes 2.8 seconds, one second slower than the earlier version; there is no progress caption. Progress during movement is **estimated**, capped short of the destination; only a successful shoe completion event and position readback confirm the final position.
- Native sheets for My shoes, Lights, Battery, Modes, and Settings.
- Nine background [Siri and Shortcuts actions](../../docs/ios/SIRI.md): tie, fit, loosen, saved modes, colors, lights off, battery, connect and disconnect. Tie restores the last successfully applied saved mode without asking for parameters, defaulting to the first saved fit (initially Move at 60% / 60%). Settings offers ready-made “Tie my shoes” and “Untie my shoes” shortcuts when signed resources are present, plus a manual setup guide.
- Twelve base colors, left/both/right selection, lights off, battery refresh, and editable local fit presets.
- The main background follows the acknowledged shoe-light color, with black or white controls for contrast. Lights off or unknown color uses white. If the shoes have different colors, the most recently chosen active color sets the background.
- A black sneaker with two blue lights on white is the app icon, using the [shared original vector drawing](../../assets/brand/README.md) that also supplies Omarchy’s theme-aware bar and panel mark.
- VoiceOver adjustable controls, reduced-motion support, system typography, and an optional haptic switch.
- Guided Add shoes, wake-up instructions, nearby discovery, and connection/reset help; no JSON-import screen.
- Optional private owner defaults for local Debug builds; credentials persist in the device-only Keychain.
- Quiet disabled L/R state while asleep; Connecting status during an actual reconnect attempt, with cancellation and bounded discovery.

The app supports the explicitly allowlisted **Auto Max 2.4.3M** protocol and requires valid existing per-shoe application keys and current fit maxima. It does not enroll fresh/reset shoes, write calibration, change auto-lace settings, upload effects, update firmware, or enable Huarache control.

## Open and build

Use Xcode 26 or newer (this implementation was verified locally with Xcode 27; CI selects Xcode 26.3). The SDK requirement comes from the background App Intents declarations; the app still targets iOS 17 or later. Open `OpenAdapt.xcodeproj`, select the **OpenAdapt** scheme, and run on an iPhone Simulator. The generated project is checked in; XcodeGen is only needed after changing `project.yml` or adding files.

```sh
# From the repository root:
swift test --package-path apps/ios
xcodebuild -project apps/ios/OpenAdapt.xcodeproj -scheme OpenAdapt \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# Optional project regeneration:
cd apps/ios
xcodegen generate
```

For a real iPhone, select your own signing team in **Signing & Capabilities**, use a bundle identifier registered to that team, and run on the connected device with Developer Mode enabled. No signing certificate, team ID, profile, or shoe key is checked in.

### Optional ready-made Siri shortcuts

Before building for distribution, generate the two signed shortcut files for your bundle ID and signing team:

```sh
python3 apps/ios/scripts/make-siri-shortcuts.py --bundle-id YOUR_BUNDLE_ID --team-id YOUR_TEAM
```

Apple's signing service validates the credential-free workflows. The generated files are ignored by Git; see [resource setup](Config/SiriShortcuts/README.md). Builds without matching resources keep the manual guide. The optional import UI test skips when these files are absent.

### Simulator interaction demo

A **Debug-only** `--demo` launch argument supplies sample shoes. It never constructs a Bluetooth connection and prominently labels the screen as a demo. Release builds ignore this argument. There is no fake connection fallback in the real-shoe flow.

In Xcode, Edit Scheme → Run → Arguments → add `--demo`. Remove it for real use. Alternatively, after installing a Debug build in a booted simulator:

```sh
xcrun simctl launch booted org.openadapt.ios --demo
```

UI tests bypass owner defaults and exercise independent dragging, linked fit, modes, lights, battery, guided setup/reset help, connecting/cancel, disabled controls, and the reduced-motion path. Run **Product → Test** or use `xcodebuild test` with an available simulator destination. Protocol tests use entirely synthetic keys and identifiers.

## Guided setup

The public interface starts at **Add shoes**. It explains waking the shoes, provides nearby discovery, and includes connection help. Fresh enrollment is still unavailable; the guide clearly states that before its reset instructions. Seeing an advertisement does not complete pairing. The manual instructions link to [Nike’s official system-reset guide](https://www.nike.com/my/help/a/adapt-troubleshooting); the app never sends a reset command.

For a saved owner pair, Connect shoes searches for the exact left/right names already present in its profile, authenticates the existing keys, and reads status. Only successful authentication saves a CoreBluetooth identifier. Opening the app automatically reconnects the last selected pair. Cached identifiers are tried first; missing or unreachable ones trigger a foreground search. Shoes sharing the same advertised name keep their separate remembered identifiers. If those identities need to be established again, My shoes → Connect individually provides the one-shoe-at-a-time flow. The complete attempt has a 20-second limit, and Cancel stops it. Bluetooth, firmware, authentication and discovery failures are shown as their actual errors rather than describing every disconnected shoe as asleep. Siri can reconnect those same shoes and complete an action without opening the app. Background actions have a 25-second app deadline and also stop if iOS expires their execution time. Ordinary temporary connections close after a background action; an explicit Connect shortcut retains idle connections. A dropped connection never replays an adjustment. UI-only sessions still disconnect on backgrounding.

### Local owner build (developer setup)

This is a private development convenience, separate from public setup. Copy an existing Omarchy v1/v2 profile to `OpenAdapt/Storage/OwnerPairing.private.json`, then create `Config/Owner.private.xcconfig`:

```xcconfig
OPENADAPT_OWNER_PROFILE_PATH = $(SRCROOT)/OpenAdapt/Storage/OwnerPairing.private.json
OPENADAPT_INCLUDE_OWNER_PAIRING = YES
```

Both files are ignored by Git. The sandboxed build phase reads only its declared input and includes it in **Debug only**. The normal first launch validates and saves it in the device-only Keychain, selecting that pair by default. Existing Keychain pairs are never overwritten, and removing a pair does not trigger automatic reimport. UI tests and demo launches skip both the private seed and Keychain. A clean checkout builds without private files. Release removes the resource even when local owner configuration exists; only Debug binaries built with this option contain the private resource and must stay private.

Linux MAC addresses cannot be passed to CoreBluetooth. CoreBluetooth manages system pairing and may present an iOS dialog. Existing-key authentication and status reads are verified on the owner’s iPhone; preservation and operation of an older phone’s separate Bluetooth bond are not established by those checks.

## Implementation

| Path | Responsibility |
| --- | --- |
| `Sources/OpenAdaptCore/` | Validated profiles, calibrated targets, strict protobuf envelopes, fragmentation, flow control, AES challenge proofs, persistent status/control lifecycle |
| `OpenAdapt/Bluetooth/` | Bounded CoreBluetooth discovery, firmware/characteristic checks, notifications, backpressure, connection cleanup |
| `OpenAdapt/Storage/` | Keychain-only private profile persistence |
| `OpenAdapt/AppStore.swift` | Per-shoe state, explicit commands, cancellation, haptics, modes, estimated progress |
| `OpenAdapt/Views/` | SwiftUI screens plus a UIKit multitouch/VoiceOver control surface |
| `Tests/` | Synthetic Swift protocol/import tests |
| `OpenAdaptUITests/` | Simulator interaction tests |

Wire behavior is ported from this repository's original Python implementation under `spikes/002-local-enrollment`. It accepts only the verified existing-key authentication, status, Stop/position, and base-light commands. Firmware must match exactly the observed unpadded revision or 20-byte zero-padded revision before notifications or Nike writes begin.

Fit requests read battery and position, require the shoe off its charger with at least 20% battery, and bound targets by imported calibration. An acknowledged Stop precedes each target. Success requires opcode-3 acknowledgement, opcode-5 completion, and corroborating opcode-4 readback with the observed one-raw-unit tolerance. An in-flight command is never replaced or queued. During protocol failure, the channel may attempt one best-effort Stop on the existing link; delivery is not guaranteed. A radio loss or background disconnect cannot establish physical stopping.

No physical shoe commands were used to develop or verify this port. See [verification and release status](../../docs/ios/VERIFICATION.md).

## Distribution

The source and local build instructions allow owners to build the app. A broadly downloadable iPhone release still needs signing, physical-device validation, and a distribution channel. Apple's [TestFlight](https://developer.apple.com/testflight/) supports public beta invitations after external beta review; a durable App Store release requires its own submission and approval. Open source alone does not make an unsigned `.ipa` installable on arbitrary iPhones.

Fresh enrollment is a separate requirement before the app can serve owners who no longer have their original saved keys. The local owner build can use existing keys; the public setup flow does not yet solve that remaining protocol work.

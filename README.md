# openAdapt

An original, MIT-licensed controller for Nike Adapt shoes, starting with a native Omarchy desktop panel. It is not affiliated with or endorsed by Nike.

**OpenAdapt has authenticated and physically laced both shoes of one owner's Auto Max pair.** The Omarchy V0 keeps authenticated Bluetooth connections open so controls reuse the connection. This is an experimental, existing-key controller: **new or factory-reset shoes cannot yet be enrolled through OpenAdapt.** Huarache control remains future work. A native iPhone client is now available as an experimental source build; its CoreBluetooth port still needs physical-device validation.

## iPhone client

The [native iOS client](apps/ios/README.md) includes independent/linked L/R fit controls, haptics, target-versus-progress feedback, battery, base colors, saved modes, guided shoe setup, and private local owner defaults stored in the iPhone Keychain. Open `apps/ios/OpenAdapt.xcodeproj` to build for iOS 17 or later.

This is an existing-key Auto Max client, not fresh enrollment. Both owned shoes have authenticated and returned status through the iPhone client. Physical motor/light behavior and Siri command completion still need device validation; no public TestFlight/App Store download exists yet. See the [iOS verification and release status](docs/ios/VERIFICATION.md).

## Omarchy V0

- A top-right panel with an original side-profile sneaker icon that follows the desktop theme.
- Independent left/right lacing sliders, from 0 to 100 in steps of 5.
- Twelve base colors, left/both/right selection, battery readings and Lights off.
- Saved-pair selection, explicit Connect/Disconnect and persistent authenticated connections.
- A New shoes entry that explains the pending enrollment work.

The slider percentage is a target relative to each shoe's saved fit calibration, not a measurement of force. Support is currently restricted to the verified Auto Max firmware `2.4.3M`. A prepared local profile with valid existing application keys, fit calibration and existing laptop Bluetooth bonds is required. Credentials and proprietary software are not included.

See the [Omarchy installation and usage guide](apps/omarchy/README.md). Opening the panel does not scan or connect automatically. Controls send real commands after an explicit connection; a failed or lost connection never queues commands for replay.

## Evidence and limits

Both initial motor tests have matching protocol completion/readback and explicit owner confirmation of physical lacing on empty shoes. The persistent app later authenticated both shoes and reused those sessions for battery refreshes and owner-operated controls. Color commands have shoe acknowledgements; independent confirmation of their physical appearance is still pending.

Fresh enrollment, key retention/recovery, Huarache support, worn-shoe behavior, exact Nike iPhone slider rounding and animation uploads remain unvalidated. Read [current status](docs/STATUS.md), [host authentication](docs/AUTO-MAX-HOST-AUTHENTICATION.md), and [motor control results](docs/AUTO-MAX-MOTOR-CONTROL.md). Historical research reports describe the evidence available at their stated dates.

## Source and offline checks

- [`apps/ios`](apps/ios): native SwiftUI/CoreBluetooth client and synthetic Swift/UI tests.
- [`apps/omarchy`](apps/omarchy): native QML panel, local controller, installer and UI/backend tests.
- [`spikes/001-ble-discovery`](spikes/001-ble-discovery): bounded BLE discovery and allowlisted standard reads.
- [`spikes/002-local-enrollment`](spikes/002-local-enrollment): original protocol implementation, existing-key authentication/control and offline enrollment model. Its enrollment CLI is offline-only.

From the repository root, with Python 3.11 and `uv` installed:

```sh
cd spikes/001-ble-discovery
uv sync --locked --python 3.11
.venv/bin/python -m pytest -q
cd ../002-local-enrollment
uv sync --locked --python 3.11
.venv/bin/python -m pytest -q tests ../../apps/omarchy/tests
cd ../..
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input apps/omarchy/tests/qml -o -,txt
```

The September 15 checkpoint passes **374 Python tests and 14 Qt test results**. Offline tests exercise the implementation; they do not establish new hardware compatibility or successful fresh enrollment. See [verification](docs/CODEX-VERIFICATION.md).

## Research boundaries

Keep working phone profiles, shoe keys and bonds intact while investigating compatibility. Discovery or log collection does not authorize resets, enrollment, actuator commands or firmware operations. Raw phone/radio captures, identifiers, credentials, downloaded tooling and proprietary artifacts remain local and ignored. Only original source, synthetic tests and curated findings belong in this repository.

## License

Original source is [MIT licensed](LICENSE). The license does not cover Nike software, firmware, trademarks, APKs, third-party research code or privately retained captures.

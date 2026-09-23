# OpenAdapt

Keep your Nike Adapt shoes connected, and build new ways to use them.

OpenAdapt is an original, MIT-licensed project with native iPhone and Omarchy clients for controlling Nike Adapt shoes over Bluetooth. It is independent of Nike and is not affiliated with or endorsed by Nike.

## Choose your client

| Client | What it offers | Get started |
| --- | --- | --- |
| **[iOS · iPhone](apps/ios/README.md)** | Guided shoe setup, simultaneous L/R fit controls, haptics, lights, battery, saved fits, Auto-Lace, Quick Unlace, and Siri/Shortcuts. | [Build and install with Xcode](apps/ios/README.md#open-and-build) · [Pairing guide](docs/ios/FIRST-PAIRING.md) |
| **[Omarchy · Linux](apps/omarchy/README.md)** | A native desktop extension with linked or independent 5% fit bars, Tie/Untie, lights, battery, and saved fits. Both shoes connect and receive commands concurrently. | [Install the extension](apps/omarchy/README.md#install-or-update-locally) · [Import your iPhone pairing](docs/ios/PAIRING-TRANSFER.md) |

The iPhone client is currently a source build; there is no public App Store or TestFlight download yet. See [release status](docs/ios/VERIFICATION.md).

## Start on iPhone, continue on Omarchy

Omarchy acts as a companion to shoes already configured on iPhone. The iOS app can export a private pairing file containing both shoes' identities and secret application keys. Omarchy uses those identities to find the shoes and those keys to authenticate its communication with them. You do not need to enter the keys by hand.

1. Save a complete pair in **OpenAdapt on iPhone**.
2. Open **Settings → Developer mode → Your shoes → Export pairing file**. Developer mode is currently available in Debug builds.
3. Transfer the file privately to your Omarchy computer and [install the extension](apps/omarchy/README.md#install-or-update-locally).
4. In the panel, open **Shoes → New shoes → Import pairing file**.
5. Disconnect the iPhone controller, wake both shoes, and press **Connect** on Omarchy.

The export contains secrets that allow control of your shoes. Keep it private and out of Git. Importing it does not copy the iPhone's system Bluetooth bond: Omarchy also needs its own local Bluetooth pairing. This is a manual transfer, with no account or sync server; fit modes and later changes are not synchronized. Use one client connection at a time until simultaneous multi-client support is established.

**Fresh-pairing status:** the iPhone's first-time setup flow is implemented and tested offline and in Simulator, but factory-reset enrollment and subsequent transfer still need hardware validation. Fit calibration is a future feature. New pairs have unknown fit calibration, so app lacing stays disabled until calibration is verified; battery and lights are available after authentication. Existing calibrated profiles retain their fit controls. See the [transfer guide](docs/ios/PAIRING-TRANSFER.md) for the full flow and current limits.

## Build your own client

Have an iPad, an Android phone, or another device you wish could control your shoes? Build a client! The protocol implementation and both existing apps are here to learn from, reuse, and extend under the [MIT license](LICENSE).

A few things we would love to see:

- **iPad and Android apps:** bring the everyday fit, light, and battery controls to more devices.
- **Smart glasses and spatial controls:** imagine a client for Meta/Ray-Ban AR glasses, Snap's Specs, or Apple Vision Pro. A pinch-and-move gesture could adjust fit like a volume control: right hand for the right shoe, left hand for the left. These are concepts to explore where platform APIs permit, not existing integrations.
- **A horror-game companion:** let a tense moment gently tighten the shoes within a player-selected comfort range, with an immediate Untie action. Make the effect opt-in and keep the existing fit limits.
- **A drum game played with your feet:** map shoe taps to kick drums, snares, or other sounds. Different feet, different instruments.

### Motion and IMU experiments

Our protocol research identified a candidate stream for accelerometer and gyroscope data—the motion sensors commonly called an **IMU** (inertial measurement unit). That could make foot-driven music, games, and custom gesture recognition possible.

**Live IMU reading is not implemented or verified in OpenAdapt yet.** Receiving samples, establishing their units and axes, and measuring latency and sample rate are the next steps before promising a playable drum controller. A game can also send fit commands in response to its own events without needing shoe motion data. All of these experiments are future projects, separate from the current clients.

Start with the [Swift protocol core](apps/ios/Sources/OpenAdaptCore), [Python Bluetooth implementation](spikes/002-local-enrollment), and [control protocol notes](spikes/002-local-enrollment/CONTROL.md). These are working implementations rather than a packaged cross-platform SDK. Contributions are welcome: new clients, original protocol documentation, synthetic tests, accessibility improvements, and hardware compatibility reports. Share what you build through [issues](https://github.com/GianlucaMinoprio/openAdapt/issues) or a pull request, keeping credentials and raw private captures out of both.

## What works today

- Verified control is currently limited to **Nike Adapt Auto Max firmware `2.4.3M`**. Displaying other Adapt model names in the app does not establish Bluetooth compatibility with them.
- OpenAdapt has authenticated and physically laced both shoes of the development Auto Max pair through the desktop implementation. Both shoes also authenticate and return status through the iPhone client. Detailed platform-specific validation is recorded in [current status](docs/STATUS.md).
- Omarchy opens on Fit for the last fully connected pair without automatically connecting. One **Connect** action attempts both shoes and can retry a missing partner. Paired controls run concurrently, with separate results for each shoe; exact physical synchronization is not guaranteed.
- Fit percentages are targets relative to each shoe's verified calibration, not measurements of force. Battery, charging, and fit-limit checks remain in place. Failed or disconnected commands are never queued for automatic replay.
- Huarache control, fresh-pairing recovery and calibration, live IMU streaming, firmware updates, and broad hardware compatibility remain work in progress. There is no OTA updater in either client.

See [iOS verification](docs/ios/VERIFICATION.md), [Omarchy verification](docs/omarchy/PANEL-POLISH.md), [host authentication](docs/AUTO-MAX-HOST-AUTHENTICATION.md), and [motor results](docs/AUTO-MAX-MOTOR-CONTROL.md). Historical reports describe the evidence available at their stated dates.

## Source and offline checks

- [`apps/ios`](apps/ios): native SwiftUI/CoreBluetooth app, Swift protocol core, and synthetic Swift/UI tests.
- [`apps/omarchy`](apps/omarchy): native QML extension, local controller, installer, and UI/backend tests.
- [`spikes/001-ble-discovery`](spikes/001-ble-discovery): bounded BLE discovery and allowlisted standard reads.
- [`spikes/002-local-enrollment`](spikes/002-local-enrollment): original Python protocol implementation, existing-key authentication/control, and an offline enrollment model. Its enrollment CLI is offline-only; iPhone setup is implemented separately.

From the repository root, with Python 3.11 and `uv` installed:

```sh
cd spikes/001-ble-discovery
uv sync --locked --python 3.11
.venv/bin/python -m pytest -q
cd ../002-local-enrollment
uv sync --locked --python 3.11
.venv/bin/python -m pytest -q tests ../../apps/omarchy/tests
cd ../..
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner \
  -import apps/omarchy/tests/qml/imports -input apps/omarchy/tests/qml -o -,txt
```

For the Swift core on macOS:

```sh
swift test --package-path apps/ios
```

The latest recorded checks pass **97 Swift core tests, 37 discovery tests, 410 Python protocol/backend tests, and 33 Qt test results**. The 410-test suite also passes on Omarchy. These checks do not establish new hardware compatibility or successful fresh enrollment. See the client guides for build requirements and UI testing.

## Research and contributions

Keep working phone profiles, shoe keys, and Bluetooth bonds intact while investigating compatibility. Raw phone/radio captures, identifiers, credentials, downloaded tooling, and proprietary artifacts stay local and ignored. Contribute original source, synthetic test data, and curated findings. Begin motion experiments with visible detection feedback before connecting them to automatic lacing.

## License

Original source is [MIT licensed](LICENSE). The license does not cover Nike software, firmware, trademarks, APKs, third-party research code, or privately retained captures.

# Android APK inspection

> Historical research checkpoint. For current capabilities, test totals and remaining work, see [Project status](STATUS.md). Statements below describe the evidence available at the checkpoint date.

Updated 2026-09-12 (PDT). This document describes static APK evidence. Separately, Hermes installed this sample on the owner-authorized Motorola and the owner signed in; those events did not establish shoe authentication.

## Sample and provenance

The downloaded sample identifies itself as **Nike Adapt**, package `com.nike.adapt`, version **1.29.3**, version code **2017062198**. Source: [APKPure download page](https://apkpure.net/nike-adapt/com.nike.adapt/download). This is a third-party mirror, not a Nike-hosted download.

- File size: 70,796,937 bytes.
- SHA-256: `b81d62fb0edc4a4f0fbd0c2c7976a88e589b2bb75b0ba097753a1bc919ab28cf`.
- APK ZIP CRC test passed; 1,726 entries, two DEX files, no packaged native `.so` libraries.
- Android `apksigner verify --verbose --print-certs` exited 0 and verified APK Signature Schemes v2 and v3.
- Signer certificate SHA-256: `25512576dacc619bd925d1ea05a3e140311d31b0b853183abe1d9da8fd3f240f`.
- **Trusted Nike signer identity remains unverified.** A valid signature proves integrity under the included certificate, not that the certificate belongs to Nike. The prior owner-authorized installation does not resolve that provenance gap.

The parent independently rehashed the actual APK, tested the ZIP and reran signature verification. Raw APK, downloaded analysis tools, decompiled text and detailed evidence stay in the original research copy's ignored `private/apk-analysis/` directory, never in GitHub.

## Initial findings

1. Manifest: minimum SDK 24, target SDK 33, Bluetooth scan/connect permissions, custom `nikeadapt` callbacks. `allowBackup=false` is set; do not assume generic ADB backup will yield app keys.
2. Decompiled `ea/b.java` (labelled `AdaptKitDevice.kt`, constructor lines 51–64) models **scanningKey**, **deviceId**, **connectionAddress** and **authenticationKey** as distinct values. A visible BLE address or scanning key must not be substituted for the authentication key.
3. `v9/h1.java` returns the marker **AuthKeyUpdatedResult**. This is evidence of a key-update result type, not proof of when the shoe or local state is changed.
4. `ab/b.java` (labelled `AdaptKitPairedDevicesRepository.kt`) references both local repository storage and paired-device API updates. This does not establish that the current owner can recover keys or that Nike services still work.

JADX produced readable output but ended with **51 decompilation errors**. Decompiled control flow is not authoritative by itself; critical paths require DEX/disassembly cross-checking and ultimately controlled hardware evidence. No replacement authentication implementation is validated yet.

## Protocol analysis since the initial snapshot

Critical framing, enrollment and authentication paths were subsequently checked against DEX. The client distinguishes a stored application key from a sentinel that selects new DH enrollment; an address or scanning key cannot replace that credential. Authentication uses a nonce exchange and AES challenge. The original connection flow also performs post-authentication writes, so it is unsuitable as a passive listener.

Codex reviewed the imported evidence and extended the original offline prototype. See its [protocol model](../spikes/002-local-enrollment/PROTOCOL.md) for exact fields, source anchors, conservative deviations and unresolved firmware assumptions. No live replacement authentication or motor control has been validated.

Remaining investigation includes independent signer provenance, legitimate access to existing owner credentials, and Huarache confirmation/key-commit behavior. Keep the installed iPhone app and pairing intact while collecting scoped logs.

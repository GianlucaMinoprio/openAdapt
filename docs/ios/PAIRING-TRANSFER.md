# Use an iPhone pairing on Omarchy

OpenAdapt can export a completed saved pair from iPhone Developer mode and import it into the Omarchy client. This is a manual, local transfer; there is no sync server.

## Owner flow

1. Finish pairing **both** reset shoes in OpenAdapt on iPhone. Select the newly saved pair in My shoes.
2. Open **Settings → Developer mode → Your shoes → Export pairing file**. Save `OpenAdapt-pairing.private.json` using Apple's Files picker. Developer mode is currently in Debug builds only.
3. Transfer the file privately to Omarchy. It contains application keys; do not post it, commit it, or send it to a public service.
4. In Omarchy, disconnect any shoe session, then open **New shoes → Import pairing file**.
5. Wake both shoes, disconnect the iPhone controller, and choose **Connect** for the imported pair. If Omarchy reports missing Bluetooth pairing, establish its local system Bluetooth pairing first. Importing application keys does not copy an iPhone Bluetooth bond or reset/enroll the shoes again.

Other saved pairs are preserved. Importing the same pair ID updates that entry after an owner-only backup. A newly enrolled pair has a new ID, so the pre-reset entry remains separately; export the new pair, not the old entry. Reimporting the same file does not create a duplicate. Fit modes, appearance choices, and later changes are not synchronized.

Newly enrolled iOS profiles have **unknown fit calibration** (`fit_maximum: 0`). Omarchy can authenticate, read battery/status, and use lights; percentage lacing stays disabled in the UI and backend until calibration is verified. It never copies a maximum from a pre-reset profile. Use the physical shoe buttons for fit in the meantime.

Shared credentials do not establish simultaneous multi-client BLE support. For now, disconnect one controller before connecting the other.

## Format and storage

- Version 2 JSON with exactly one completed saved `ShoePair`. No enrollment journal, private exponent or recovery secrets are exported.
- Native profiles retain their CoreBluetooth UUID for round trips and include six bytes of manufacturer identity, base64 encoded. Linux matches the five identity bytes plus side bit, Nike manufacturer prefix and exact advertised name. It never treats an iPhone UUID as a Linux MAC or selects solely by a shared model name. Ambiguous matches fail before connecting.
- Legacy profiles keep their Linux addresses and verified calibration.
- Import accepts a user-selected local regular file owned by the user, without group/world write access, up to 256 KiB. Links, duplicate JSON fields, partial pairs, setup keys, unknown firmware profiles and malformed values are rejected.
- The catalog and backups use mode 0600 inside mode 0700 directories. Public QML state never includes keys, hardware identities or source paths. Import/export does not access the radio.
- Existing firmware checks, local-bond requirement, authenticated proof, connection ownership and no-replay behavior still apply.

## Verification — September 22, 2026

97 Swift core tests and 364 Python protocol/backend tests pass. A shared synthetic fixture checks Swift's exact export against Python's import, including side identities and unknown calibration. Tests cover backup/idempotence, rejected inputs, import without radio access, import blocked during a session, public-state redaction, Linux identity resolution and ambiguity, bond/connection boundaries, status/lights without calibration and blocked lacing. The signed iPhone build succeeds. The native export/save-sheet/dismissal UI test passes with a synthetic pair, and its screenshots were visually checked. The update is installed on the owner’s iPhone; automatic launch was blocked by the locked device.

Physical post-reset transfer remains to be tested. Omarchy became reachable later on September 22 and the update is installed; its native import dialog and owner-operated transfer remain to be checked. No owner keys were exported/imported by tools and no reset, enrollment, bonding, motor, light or setting command was sent.

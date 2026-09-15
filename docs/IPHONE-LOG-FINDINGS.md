# iPhone Connecting investigation

> Historical research checkpoint. For current capabilities, test totals and remaining work, see [Project status](STATUS.md). Statements below describe the evidence available at the checkpoint date.

September 12–13, 2026 (Pacific). The owner requested iPhone logs, explicitly approved installing usbmuxd, and then requested a Nordic advertising check while waking the shoes.

## Result

**September 13 afternoon update: the Auto Max app connection was restored by enabling Nike Adapt's iPhone Bluetooth permission.** A capture spanning a full app restart recorded iOS sending `Unauthorized` to both Nike Adapt Core Bluetooth central sessions. The owner checked Settings, confirmed the permission had been off, enabled it and reported that the shoe controls appeared. This identifies an app Bluetooth-permission blocker for the observed Auto Max spinner. It does not demonstrate authentication or control by the replacement prototype, nor establish that every earlier Huarache symptom had the same cause.

**A synchronized Bluetooth Settings attempt established an encrypted connection to EARL Right, followed by a remotely initiated disconnect about 10 seconds later.** The owner confirmed “Connected, then disconnected.” The log reports `isPairing=0` when encryption succeeds and retains the paired-device database after disconnect. This supports a usable existing Bluetooth security relationship for this attempt; it does not establish Nike application authentication or explain why the shoe terminated the link.

Earlier, both owned shoes were broadcasting while the owner reported the iPhone app on Connecting. The simultaneous app log did not expose a Bluetooth/authentication error or enough protocol detail to diagnose that stall.

## What was collected

Existing USB trust validated successfully after installing/starting usbmuxd and reconnecting the cable. No new pairing/trust command, app reinstall, account change, key access, backup or logging profile was used. An initial command-line option conflict exited immediately and collected no phone log; the corrected process filter then worked.

| Capture | UTC window on September 13 | Result |
|---|---|---|
| Adapt-only log 1 | 06:56:11 to about 06:56:56 | 45.07 seconds; 318,957 bytes; 1,961 lines |
| Adapt-only log 2 | 06:59:53 to about 07:00:38 | 45.06 seconds; 282,030 bytes; 1,595 lines |
| Nordic serial advertising, simultaneous with log 2 | 06:59:53 to about 07:00:38 | 45-second limit; 9,809 frames; 7,232 CRC-valid frames; 181 CRC-valid frames containing owned advertising addresses |

The 181 owned-address frames comprise **178 Nike advertisements (85 from shoe 1; 93 from shoe 2)**, two scan responses and one scan request. Both shoes' advertisements were seen on channels 37, 38 and 39. The labels identify the two previously owner-confirmed addresses privately; left/right mapping is not inferred.

An independent readback of the filtered PCAP confirmed 181 CRC-valid owned-address frames. A bare Wireshark boolean field filter initially included one bad-CRC packet; the saved filter was corrected to `nordic_ble.crcok == 1` before reporting results. No connection following or application decryption was attempted. The serial port had no holder after capture stopped.

## What the app logs show

- Both windows contain app/media/network activity; the process was producing logs.
- Neither window contains explicit Error/Fault/Critical severity entries or matches for the inspected Bluetooth/CoreBluetooth/CoreRF/authentication markers.
- Each window includes one observed network task returning HTTP 200. The requested resource and its relationship to shoe connection were not established; this is not evidence that login, paired-device retrieval or a shoe backend worked.
- Most output is framework/media activity. “No Bluetooth log messages” does not mean “no Bluetooth traffic.” This process-filtered system log can omit private framework/device details, activity from other processes, or initialization that happened before capture.

## Next useful observation

The requested fresh app launch has now identified the permission blocker for Auto Max. Preserve the recovered original app and use an owner-attended ordinary connection as a reference for further protocol work. The previous Huarache Settings capture remains separate evidence. Any broader system trace, HCI logging or credential recovery still requires an appropriate concrete scope; no reset or enrollment is needed to fix this permission problem.

No evidence here authorizes enrollment/reset or establishes a recovered key, authenticated shoe session, or actuator control.

## Saved EARL Right reconnect follow-up

The owner subsequently reported that tapping the saved EARL Right entry moved it toward the top of Bluetooth settings without a connection error, then it showed disconnected again. The two earlier captures had already stopped; that original attempt was not recorded by Codex. No successful application authentication or pairing validity is inferred from the UI observation.

A new 45.03-second capture on September 13 at 07:06:23–07:07:08 UTC included only the `Adapt` and `bluetoothd` processes. It retained 1,396,571 bytes / 8,294 lines and stopped cleanly with exit 0. Of those, 8,173 lines identify `bluetoothd`; there are no `Adapt` process lines or EARL/Nike name matches. No known owned-shoe address or Nike manufacturer-data match was found, and no attributable shoe connection/disconnection sequence was identified. This does not prove that the shoes were absent or that no link attempt happened.

The capture contains 35 explicit Bluetooth-service error entries, mostly relay destination and connection RSSI-state messages. They lack a verified association with either shoe and must not be treated as an EARL failure diagnosis. Existing USB trust validated; no pairing, reset, key or phone setting was changed by Codex. Whether the owner repeated the tap during this exact window remains unconfirmed.

Private evidence for that inconclusive window is in `private/iphone-logs/20260913T070623Z/`, including raw log, bounded-run summary and aggregate analysis. The synchronized repeat below resolved the timing uncertainty for a later attempt.

## Synchronized EARL Right result

After the owner said ready, recording began before the instruction to tap the saved EARL Right entry. The 90.03-second window ran September 13, 07:08:52–07:10:22 UTC (00:08:52–00:10:22 Pacific), collected 3,358,866 bytes / 20,069 lines, and stopped at its deadline with exit 0. There are 16,615 explicitly prefixed `bluetoothd` lines and no `Adapt` process lines. EARL Right's logged name was joined to its device UUID and address privately to attribute the sequence.

| Pacific time | Observed event | Raw log line |
|---|---|---|
| 00:09:04.595675 | Connection requested by `com.apple.Preferences` (Settings) | 3334 |
| 00:09:04.668352 | Outgoing LE connection complete, status 0 | 3512 |
| 00:09:04.900878–00:09:04.900996 | Encryption callback status 0, `isPairing=0`; encryption enabled | 3636–3637 |
| 00:09:05.005175–00:09:05.005735 | EARL RIGHT device ready and Settings app ready, result 0 | 3807, 3827 |
| 00:09:15.011169 | Link disconnected; Apple reason value 719 | 6290 |
| 00:09:15.013435 | Stack explicitly labels disconnect `remotely-initiated` | 6314 |
| 00:09:15.067112 | Stack keeps database for the paired device | 6842 |

The link lasted **10.343 seconds from connection complete**, or **10.006 seconds from device ready**. An earlier remotely initiated disconnect at 00:09:01 is also present, but its connection establishment predates the recorded sequence and cannot be reconstructed here.

For this attempt, the evidence points to the remote shoe terminating an already encrypted link, rather than failure to establish Bluetooth security. The requesting client is Settings; no Nike app handshake or recovered application key is demonstrated. An application-session/idle timeout could explain the roughly ten-second duration, but the firmware's actual reason remains unknown. The Apple numeric reason is retained as an opaque value, not mapped speculatively to an HCI error.

Temporary security-key cleanup messages follow disconnect, but the paired-device database is explicitly retained. They are not evidence that the phone forgot the shoe. The owner's connection causes routine OS cache updates; Codex collected logs and did not initiate a pairing reset or key replacement. These findings provide no reason to clear the saved entries.

## September 13 afternoon: Auto Max permission diagnosis

The owner selected the saved Auto Max profile corresponding to the two shoes near the computer and reported an infinite Connecting spinner. A new local BLE advertising scan matched both previously owner-confirmed Auto Max identities. Initial USB attachment failed in usbmuxd; reconnecting the unlocked iPhone restored access and validated its existing USB trust without creating a new trust relationship.

The first 90.03-second capture (20:30:50 UTC) recorded the old Adapt process resuming: 23,215 lines / 3,767,541 bytes, including 8,897 explicitly prefixed Adapt lines. It contained app session state and network/media errors, but no attributable Nike shoe connection request. A second capture began at 20:32:26 UTC and spanned a full app restart, verified by the process ID changing. It stopped cleanly at the 4 MiB limit after 81.60 seconds, with 26,266 lines and 5,842 explicitly prefixed Adapt lines.

| Pacific time | App-specific Bluetooth finding | Second capture line |
|---|---|---|
| 13:33:16.069581 | First new Nike Adapt central session receives `Unauthorized` | 15316 |
| 13:33:16.075895 | Second new Nike Adapt central session receives `Unauthorized` | 15500 |

Apple defines this state as the application lacking authorization for the Bluetooth LE role; it is not a rejected shoe application-key proof. The setting is under Settings → Privacy & Security → Bluetooth. See [Apple's state definition](https://developer.apple.com/documentation/corebluetooth/cbmanagerstate/unauthorized) and [Bluetooth permission instructions](https://support.apple.com/en-us/102267).

The owner confirmed “it was off,” then reported “It now connect!” and “The shoe controls appeared” after enabling access and reopening Auto Max. After another ordinary app reopen, the owner confirmed both shoes connected. This is recovery of the installed Nike app. No replacement-controller hardware authentication, extracted key or motor test is established by that result.

The raw first and second recordings, hashes, aggregate analysis and redacted authorization events are in ignored owner-only `private/iphone-logs/20260913T203050Z/` and `private/iphone-logs/20260913T203226Z/`. Later captures use the same two-process filter and 90-second deadline with an 8 MiB cap because the app's initialization reached the earlier 4 MiB cap.

### Working connection reference

The third capture ran 20:34:24–20:35:54 UTC for 90.02 seconds, stopped at its deadline with exit 0, and retained 41,076 lines / 6,715,894 bytes. It includes the requested ordinary app restart. Both logged shoe addresses privately match the two Auto Max identities from the earlier local scan.

| Pacific time | Observation | Third capture line |
|---|---|---|
| 13:35:18.821120 / .830569 | Both new Nike Adapt central sessions receive state `On` | 23422 / 23621 |
| 13:35:19.086908 / .119530 | Left/right encryption succeeds with `status=0`, `isPairing=0` | 26194 / 26679 |
| 13:35:19.198321 / .230002 | Nike Adapt's left/right connections report ready, result 0 | 27013 / 27580 |
| 13:35:19.399542 | Reopened Nike app sends a characteristic-write request | 30501 |
| 13:35:27.117024 | Right shoe disconnects, opaque Apple result 307 | 33126 |
| 13:35:28.455070 / .541777 | Right re-encrypts with `isPairing=0` and returns to app-ready | 34198 / 34419 |

The capture contains service/characteristic discovery, subscriptions, writes and delivered indications. It contains 298 writes without response to the owned shoe identities and no writes with response in that set. This is a useful observed difference from the prototype's explicit write-with-response policy; it does not yet establish that the prototype policy fails, and it was not changed based on this observation alone. Message payloads/application keys were not recovered or decoded. The one right-shoe reconnect prevents treating the recording as proof of a continuously stable session, although the owner's final observation was both shoes connected. No new Bluetooth pairing was needed for the three recorded encryption completions.

Private raw evidence, source hash, aggregate analysis and redacted connection events are in `private/iphone-logs/20260913T203424Z/`. Captures are complete; no phone log process remains running after verification.

### App export availability

A subsequent read-only installation-metadata lookup was restricted to `com.nike.adapt` using the existing USB trust. The installed iPhone app is version **1.29.4**, build **24903**, distinct from the archived Android APK 1.29.3. Its returned metadata does not declare `UIFileSharingEnabled` or `LSSupportsOpeningDocumentsInPlace`, so this check did not identify an advertised USB Documents export for the saved credential. Absence of those entries is not proof that every legitimate recovery route is unavailable. No app-container files, keychain data or whole-phone backup were collected. Exact app metadata remains owner-only in ignored `private/iphone-logs/20260913T203936Z/`.

## Authorized HCI capture and backup investigation

After discussing Linux USB HCI capture and an encrypted local backup, the owner asked to execute the proposed steps. `idevicebtlogger`, `idevicebackup2` and `tshark` are installed locally. Existing USB trust and iOS 26.6.2 were confirmed; `WillEncrypt` was initially false. The phone reported approximately 76 GB used and the host had more than 800 GB free. Linux USB HCI capture succeeded; the later Nike-only backup inspection recovered the application credentials as described below.

The owner confirmed installing [Apple's official iOS Bluetooth logging profile](https://developer.apple.com/services-account/download?path=/iOS/iOS_Logs/iOSBluetoothLogging.mobileconfig), linked from [Profiles and Logs](https://developer.apple.com/feedback-assistant/profiles-and-logs/), following [Apple's profile guide](https://support.apple.com/en-us/102400). The profile download and Bluetooth instructions PDF require Apple sign-in; their contents have not been retrieved or reviewed locally.

The private capture at **2026-09-13 20:49:47 UTC** ran for 90.27 seconds and stopped both children cleanly. The owner reopened the saved Auto Max pair and confirmed both shoes connected. `bluetooth.pklg` contains **67,196 bytes / 1,706 complete records**, no trailing partial record, and SHA-256 `2830046e3f3cec62b95d890f618fffb09d20fd28ee1cfd3a8199e23ec5d27fbc`. Wireshark's decoder read all records successfully. Companion filtered system logs contain 5,115,502 diagnostic bytes. Everything is ignored under `private/iphone-hci/20260913T204947Z/`.

Offline analysis matched connection-complete device addresses to the two owner-confirmed Auto Max scan identities and tracked connection handles through disconnects. Four HCI LE Start Encryption commands contain a consistent nonzero 16-byte link key per shoe. **Both BLE link keys were recovered privately.** Neither key, in either byte order, satisfies the recorded Nike application AES proofs, so these keys cannot substitute for the application credentials.

The trace contains 248 ATT packets, including 114 writes without response and 118 notifications. Restricting to the known Nike command/notification handles produced 232 fragments and 134 complete application messages plus 75 flow-control packets, with no sequence or envelope-length errors in the offline reconstruction. Both shoes show the full existing-key exchange: opcode 112 request with a 16-byte client nonce, matching ACK with two 16-byte fields, opcode 113 request with a 16-byte proof, and empty successful ACK. These captured response schemas pass the prototype's decoder. Enrollment opcodes 110/111 are absent. This is direct **original-app authentication evidence**, not execution or proof of the replacement controller. The later recovered application keys independently reproduce both opcode 113 proofs; the first opcode 112 response field reveals a separate prototype mismatch, described in the key findings.

The owner entered a new backup password through masked computer dialogs. Encryption was enabled successfully and `WillEncrypt: true` read back. The password was not saved by the helper or placed in chat. The first backup attempt (`private/iphone-backup/20260913T205125Z/`) stopped after 36 seconds during protocol-version negotiation and produced no completed snapshot. A second attempt (`20260913T205325Z/`) negotiated version 2.1 and completed after the owner's iPhone passcode approval. The final result is **exit 0, 349,283 files received in 2,452 seconds**, with `Backup Successful`, `SnapshotState: finished`, and `IsEncrypted: true`. The helper's final summary confirms the snapshot is complete and encrypted. Encrypted computer backups remain enabled using the owner's chosen password. No restore, password reset, shoe enrollment or control operation was performed.

Before extraction, keychain restrictions were an unresolved possibility: [Apple's keychain protections](https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web) can prevent recovery of device-bound credentials. The completed Nike-only inspection found the saved shoe keys directly in the app's JSON database, so no keychain extraction was needed.

The owner asked why a whole-phone backup was being made. The limitation of the selected USB backup CLI and the narrower Nike-only analysis scope were explained; the owner explicitly chose to continue the encrypted full-device backup and inspect only Nike data. A subsequent existing-trust House Arrest probe requested only `com.nike.adapt`: both `VendDocuments` and `VendContainer` returned `InstallationLookupFailed`. No application file was read or modified by the probe. This verifies rejection of these two direct export methods rather than assuming it from metadata alone. Private responses are under `private/iphone-backup/nike-export-probe-20260913T211500Z/`.

After returning, the owner entered the backup password in a new local masked dialog. The inspector extracted 22 files / 607,147 bytes from the three exact Nike domains and found four saved application keys: both Huaraches and both Auto Max shoes. Both Auto Max keys reproduce the recorded app AES responses, independently checked by two crypto implementations; the Huarache keys await matching runtime evidence. The current prototype rejects both captured Auto Max exchanges because its added full-block client-nonce proof comparison disagrees in the first four bytes. The check was not relaxed. See [saved-key findings](IPHONE-KEY-FINDINGS.md) for validation and the concrete next blocker. The owner confirmed removing the temporary Bluetooth logging profile, and all phone capture/backup/dialog processes have finished.

## Private artifacts

Raw data stays in ignored owner-only directories:

- `private/iphone-logs/20260913T065611Z/`: first successful capture and summary.
- `private/iphone-logs/20260913T065953Z/`: simultaneous app capture, summary and aggregate analysis.
- `private/iphone-logs/20260913T070623Z/`: inconclusive Bluetooth-service window and aggregate analysis.
- `private/iphone-logs/20260913T070852Z/`: synchronized Settings attempt, summary, aggregate analysis with source hash, and redacted event extract.
- `private/nordic-captures/20260913T065953Z/`: bounded raw capture, corrected owned-only PCAPNG and aggregate analysis.

Only this curated report belongs in the distributable source; device identifiers, raw logs and captures do not.

# Computer Bluetooth pairing

> Historical research checkpoint. For current capabilities, test totals and remaining work, see [Project status](STATUS.md). Statements below describe the evidence available at the checkpoint date.

September 13, 2026 Pacific / September 14 UTC. The owner asked **“Can you try to pair?”** while the original iPhone setup remained on its hold-phone-near-shoes screen. The owner then confirmed Nike Adapt was fully closed. This authorizes the computer Bluetooth bond attempts described here; it does not establish Nike application authentication.

## Observed result

BlueZ 5.87 successfully completed one `Device1.Pair` call for each of the two previously tracked family-004 radios. Fresh scans required each exact prior address, Nike manufacturer data and the privately saved Auto Max name (family 004). Immediately before each attempt, Paired, Bonded, Connected, Trusted and Blocked were all false.

| Target alias from previous Auto Max recordings | Pair completed UTC | After pairing | After cleanup |
|---|---|---|---|
| Right / shoe_1 | 00:47:07.938 | Paired and Bonded true; services resolved | Disconnected; bond retained |
| Left / shoe_2 | 00:47:24.454 | Paired and Bonded true; services resolved | Disconnected; bond retained |

A separate read-only check at 00:47:58.900 UTC confirmed both bonds remained saved and both devices were disconnected. Trusted remained false. Both attempts had no cleanup errors. The one-shot private helper used a caller-specific NoInputNoOutput pairing agent without replacing the desktop default agent. It did not send Nike characteristic writes, enroll an application key, unpair/reset a shoe, change trust, or issue a motor/light command.

## Physical identity clarification

After these attempts, the owner corrected the description, saying the observed right-shoe pairing was Huarache, not Auto Max. Further connections were paused. The earlier iPhone pairing had already been identified by the owner as Huarache, but the owner did not clearly distinguish that event from the later computer attempts. Do not resolve this solely from names.

Read-only comparison found neither newly bonded address in any of the four earlier Huarache discovery/inspection references. Those older references advertise family 002. The owner was then asked to switch off both Huaraches and leave both Auto Max shoes powered on for a bounded advertising-only identification scan. The owner confirmed **“Huaraches off; Auto Max on.”**

The 75-second scan completed cleanly at 00:50:52.559 UTC. After that owner report, the newly bonded targets produced **51 and 48 fresh advertisements**, both identified as Auto Max (family 004). Neither historical Huarache address appeared. Together with the distinct historical addresses and family mapping, this corroborates that the two new computer bonds belong to Auto Max. Keep the earlier owner-reported **iPhone Huarache pairing** separate. The left/right aliases come from the earlier app/key capture, rather than from this pair-level power-off check. No physical motor/light identification command was sent.

## Remaining work

The iPhone Auto Max setup is not yet restored. Its last USB capture received both family-004 advertisements but no fresh connection events for those addresses. Earlier original-app removal sent `fw system_reset` to both shoes; two subsequent iPhone connections failed with Bluetooth status 0x06 before Nike enrollment. The owner then forgot phone bonds and successfully re-paired a Huarache shoe. See [the original-app experiment](ORIGINAL-APP-ENROLLMENT-CAPTURE.md).

Recovered Auto Max application keys remain validated against historical exchanges, including three after the physical green-light indications but before the app's explicit system reset. Their current validity after that command is unverified. The prototype's four-byte peer-proof mismatch is still unresolved. A saved computer Bluetooth bond does not establish application authentication, fresh Nike enrollment, or control. The owner's 80/80 request remains unexecuted.

## Private evidence

- `private/continuation/20260914T004659Z-auto-max-right-bluetooth-pair/`
- `private/continuation/20260914T004716Z-auto-max-left-bluetooth-pair/`, including the independent both-bond check and owner's identity correction
- `private/continuation/20260914T004937Z-physical-pair-identification/`
- `private/continuation/pair_owned_auto_max.py`, an ignored one-shot bond helper; the production enrollment prototype remains unchanged

No Bluetooth secrets were exported, no files staged, and no commit or push performed.

# Project status

Updated September 15, 2026.

**The Omarchy controller now uses real, persistent connections.** Opening it while disconnected shows the saved-pair list. Connect authenticates the selected pair and reads battery/position; subsequent controls reuse the session. New shoes appears below saved pairs, or centered when none exist. Preview was removed at the owner's request. Fresh enrollment remains unavailable, with an explanation on the New shoes page. See [the app guide](../apps/omarchy/README.md).

## Verified results

- OpenAdapt previously authenticated and laced both owned Auto Max shoes with their current keys. Both 80% operations have verified completion/readback, clean disconnects and explicit owner confirmation of physical lacing. Current fit maxima are 65 right / 61 left. See [the motor report](AUTO-MAX-MOTOR-CONTROL.md).
- The owner subsequently requested real app connections and confirmed both shoes awake with Nike Adapt closed. Both shoes authenticated in the new persistent backend. Two additional battery refreshes reused those sessions. Transcript review found one handshake per shoe, five owner-operated color updates per shoe and one owner-operated left motor target during the same connections. The agent's check sent connection/status operations only.
- The owner selected Disconnect. Both local BlueZ devices were independently verified disconnected, paired and bonded. The panel returned to the saved-pair list. Credentials remained unchanged. No automatic reconnect or queued command is scheduled.
- **337 Python tests and 14 Qt test results pass.** Coverage includes persistent connection lifetime, repeated reads across sequence wrap, repeated explicit motor commands, idle movement observation, failure without replay, cancellation, saved-pair selection, empty state and slider interaction. The native UI and its local JSON-line process were also checked.
- The base-light codec matches 858 original-app message envelopes offline. Live color commands now have shoe acknowledgements; physical LED appearance and perceived latency await owner feedback. The original-app animation studies remain separate from this V0's base-color controls.
- The side-profile sneaker and controls follow the desktop theme. The bar icon uses the theme foreground; the panel sneaker/fills use the same accent as the bar's selected-panel underline. At the owner's request, the Razer accent was changed to deeper green `#36ab23`, with theme backups retained.

## Remaining work

1. Establish shoe key-commit/retention and candidate crash-recovery behavior before a concrete fresh-enrollment experiment. The offline 110/111 model does not establish successful replacement enrollment. No new reset or key-changing experiment is enabled by the existing-key result.
2. Validate Huarache credentials against corresponding runtime evidence. The Auto Max firmware policy is not automatically transferable.
3. Collect owner feedback on physical LED appearance and perceived response time. Broader effects, exact Nike iPhone display rounding and worn-shoe behavior remain unvalidated.
4. Build eventual iPhone/Shortcuts support. The first source push includes original code, synthetic tests and curated findings; raw evidence and credentials stay local. Public visibility is separate from the existing MIT license and the current private-repository instruction.

## Preservation and evidence

The completed encrypted iPhone backup refresh and Nike-only extraction recovered the current Auto Max credentials; all 22 complete known-key original-app authentication exchanges now validate. The backup password was not retained, and no keychain or other-app extraction was performed. See [the authentication report](AUTO-MAX-HOST-AUTHENTICATION.md) for the earlier recovery and live protocol evidence.

No new phone capture, backup or Nordic operation ran during the app connection work. Existing phone profiles and shoe keys remain intact. Phone operation after host control has not been independently retested. Raw captures, identifiers, credentials and proprietary evidence remain local and ignored. Development stays in this Codex copy; Hermes evidence is read-only.

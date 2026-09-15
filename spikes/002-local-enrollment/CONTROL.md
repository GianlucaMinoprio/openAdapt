# Auto Max existing-key control experiment

**Live verification, September 15:** both owned shoes completed their 80% target
operations with verified completion/readback and clean disconnects. The owner
confirmed both physically laced, then paused hardware work for the night. See
`docs/AUTO-MAX-MOTOR-CONTROL.md` from the project root. No more hardware commands
are authorized while that pause remains in effect.

The separate `AutoMaxControlLink` supports a bounded status read or one absolute
position request after the existing-key handshake. `ExistingKeyLink.authenticate`
still sends only 112/113. The public CLI remains offline-only. Fresh enrollment,
reset, calibration writes, presets, lights and firmware are excluded here.

The owned Auto Max firmware gate, exact target, existing bond/disconnected
preflight, subscription and bounded cleanup are shared with the authenticated
path already demonstrated on both shoes. Successful offline tests are not proof
of hardware motor control.

## Original wire model

| Opcode | Request | Response used here |
|---|---|---|
| 0 | Protobuf varint field 1 = 8, Stop only | Empty ACK |
| 3 | Field 1 = raw absolute position 0–100; zero omitted | Empty ACK, followed separately by opcode 5 |
| 4 | Empty, read position | Field 1 = raw position; omitted means zero |
| 5 | Never requested | Event: field 1 status, field 2 measured raw position; both default zero |
| 81 | Empty, read battery | Varints: charger status 1, voltage 2, percent 4, battery state 5; double temperature 3 |

These formats were derived from owner-operated recordings and corroborated by
archived Android schemas. The September 15 offline comparison checks **818
messages across seven recordings**, including byte-identical request encoding.
Raw source data and the verifier remain in ignored local evidence.

The latest fit-check completion events report status 4 at raw positions 61 left
and 65 right. These exactly match the newly extracted profile maxima. Status 4
is recorded as a limit observation here; this controller accepts only status 0
for its ordinary movement test. The fit-check request for raw 100 is not replayed.

## Position scale

OpenAdapt explicitly maps a percentage to the nearest integer raw position:
`(percent * current_fit_maximum + 50) // 100`, for integer percentages 0–100.
This agrees with the archived Android relative-position model and saved-mode
examples. It does **not** establish Nike iPhone slider/display rounding: stored
relative values, snapped display values and measured completion can differ.

At the current fit limits, an OpenAdapt 80% target is raw 52 right and 49 left.
These are bounded below each saved maximum. A raw command value of 80 would be
a different, higher movement and is not used for this request.

## Live operation boundaries

`set_position` requires current empty-shoe confirmation and valid calibration
before scanning. It authenticates, reads battery and position, requires the shoe
off its charger with at least 20% battery, then sends Stop and waits for its ACK.
It sends one position request and requires its ACK, a subsequent status-0
completion within one raw unit of the target, and a fresh readback corroborating
that completion within one unit. The tolerance reflects recorded measured
positions; it is not a force measurement or physical motion guarantee.

The two shoes are tested sequentially. Unexpected responses, faults, timeout,
cancellation, failed readback or cleanup prevent a successful result. No position
request is retried. On a failure after a completed position write, a short best
effort Stop is attempted with the current sequence when the flow window allows
it, then the channel closes and disconnects. This Stop is unconfirmed and cannot
guarantee delivery or physical stopping. No connection recovery is attempted.

Tests cover the authentication-only boundary, malformed responses, calibration
and empty-shoe preflight, low battery/charger state, ACK versus completion,
position disagreement, cancellation, cleanup, and rejection of enrollment and
unrelated commands. **253 offline tests pass** in the combined spike suite.

Primary source anchors are the read-only archived `hc/d.java`, `gc/x.java`,
`gc/y.java`, `gc/a0.java`, `gc/l.java` and `ea/i.java`, plus the owner-operated
captures described in `docs/ORIGINAL-APP-ACTIONS.md`. No proprietary controller
source is included in this implementation.

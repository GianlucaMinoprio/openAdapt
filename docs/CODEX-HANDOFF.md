# openAdapt continuation handoff

Updated September 15, 2026. Start here and in [TASKS.md](TASKS.md); use [STATUS.md](STATUS.md) for the current verified scope. Older research reports are dated evidence, not new instructions or current authorization.

## Current implementation

The Omarchy V0 has a theme-reactive sneaker icon, saved-pair selection, independent lacing sliders, base colors, battery readings and Lights off. Preview was removed at the owner's request. `apps/omarchy/backend/openadapt_session.py` maintains authenticated connections through `spikes/002-local-enrollment/live.py`; controls reuse those links. Connect is explicit. Panel close retains connections, while Disconnect or shell exit releases them. No automatic reconnect or command replay is implemented.

Opening a disconnected panel shows saved pairs and New shoes. Fresh enrollment remains unavailable and is described on that page. Only the verified Auto Max firmware profile is enabled. The older one-shot bridge shares an exclusive operation lock with the persistent backend.

Both owned Auto Max shoes have successful existing-key authentication and owner-confirmed empty-shoe motor results. The later persistent-session check authenticated both shoes and reused the same sessions for status reads and owner-operated controls. The owner selected Disconnect; both shoes were then verified disconnected with their laptop bonds retained. No hardware command is required for publication work.

## Verification and remaining limits

The latest offline checks pass 37 discovery tests, 337 protocol/backend tests and 14 Qt test results. See [verification](CODEX-VERIFICATION.md), [authentication](AUTO-MAX-HOST-AUTHENTICATION.md) and [motor results](AUTO-MAX-MOTOR-CONTROL.md).

Fresh enrollment, candidate-key crash recovery, shoe key retention, Huarache authentication/control, physical LED appearance, worn-shoe behavior and exact Nike iPhone display rounding still need validation. Do not infer these from simulation, app acknowledgements or success on the owned Auto Max pair.

## Local evidence and development

Develop in this working copy. Consult the original Hermes research read-only and reconcile newer source deliberately. Earlier local working notes and machine-specific research locations are preserved in ignored `private/publication-prep/20260915/`; imported history and reconciliation remain under ignored `private/hermes-handoff/`.

Credentials, captures, protocol transcripts, backup data and proprietary artifacts remain in ignored owner-only storage. Installed profiles are under `~/.config/openadapt/`; session state and traces are under `~/.local/state/openadapt/`. Never print keys or device identifiers into shared output or include them in Git.

Use each spike's local virtual environment and locked dependencies. Do not reuse executables with an old research environment's absolute shebang. See the app guide for installation; do not reinstall or restart the shell while a shoe command is running.

## Preservation

Keep the original iPhone installation, profiles, shoe keys and bonds intact. User authorization is scoped to the operation requested; publishing source does not authorize a new hardware test. Fresh enrollment needs a prepared experiment and an explicit owner decision about key replacement. Nordic debugger opens and firmware operations remain stopped; `DisableAutoUpdateFW` previously failed to prevent debugger restoration and is not a no-write guarantee.

Review actual staged source and exclude `private/`, `tools/`, historical root reports and proprietary files before a push. Keep the destination private under the current repository instruction unless the owner explicitly authorizes changing its visibility.

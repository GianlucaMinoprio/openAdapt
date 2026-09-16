# OpenAdapt for Omarchy

A native Quickshell panel for the owner's verified Auto Max pair. The side-profile sneaker sits beside the AI widget in the top-right bar. The bar icon follows the bar foreground; the panel sneaker, slider fills and selection accents follow `Color.accent`, the same theme role as the bar's open-panel underline. Omarchy theme changes update these bindings automatically.

The sneaker artwork is shared with the iPhone app: minimal laceless silhouette and two solid blue dots. See the [editable vector and asset-generation guide](../../assets/brand/README.md). The theme-aware mark preserves its proportions in rectangular containers; the green/accent version has white dots, while the bar’s white mark and desktop launcher keep blue dots.

At the owner's request, the installed Razer theme's blue accent was changed to the deeper green `#36ab23`. Both its source palette and active palette were updated, with the originals saved in `~/.config/openadapt/backups/`. This desktop customization is separate from the app installer; the plugin uses each theme's accent rather than hardcoding green.

## Controls

- Separate left and right vertical lacing sliders, 0–100% in steps of 5. A drag sends one target when released; arrow keys and the wheel also move in 5% steps. Closing the panel cancels an unfinished drag.
- Twelve base colors, applied to the left shoe, right shoe or both.
- Battery readings for each shoe, with the actual reading time in the tooltip.
- Lights off, which stops a running effect and sets the base color to zero.
- Pair shoes, with current-pair connection controls and an explanation of the remaining new-shoe setup work.

The percentage is a target relative to each shoe's saved fit maximum, not a measurement of force. The controller maps it to a raw position with explicit nearest-integer rounding. Exact Nike iPhone display rounding remains unresolved.

## Saved shoes and live connections

Opening the panel shows the saved-pair list when no shoes are connected. Choose **Connect** beside the pair to use. **New shoes** appears below saved pairs, or in the center when the list is empty. It currently explains the pending fresh-enrollment validation; it does not reset or enroll shoes.

Connect performs one bounded discovery/authentication attempt per shoe and reads battery and position. The connections then stay open while using or closing the panel. Sliders, colors and Battery reuse those authenticated links, avoiding the previous five-second scan, reconnect and handshake on every click. **Disconnect** releases both owned connections and returns to the list. If only one shoe connects, its controls work independently and **Connect missing shoe** retries only the missing side when selected.

Preview and its enable-live switch have been removed. Opening the panel or starting its local backend does not scan or connect automatically. Connection state comes from the running BLE links, never a persisted connection flag. A lost connection returns to the list when both shoes are gone. Requests made while disconnected are rejected rather than saved for later; there is no automatic reconnect or command replay.

The native shell owns a local process with JSON-line stdin/stdout. It keeps credentials private and serializes operations. Closing the shell or its input cancels the current action and runs the existing disconnect cleanup. The older one-shot command bridge remains for compatibility and is excluded by the shared operation lock while the new backend runs.

**September 15 live checkpoint:** the owner requested real connections, confirmed both shoes awake and Nike Adapt closed, and then operated the UI. Both shoes authenticated and remained connected; two further battery refreshes reused the same sessions. Trace review also found five owner-operated color changes per shoe and one left motor target in those sessions, with one handshake per shoe. The owner subsequently selected Disconnect and the UI returned to the saved-pair list. No agent motor or LED command was sent during this connection check. Physical color appearance and perceived response time await owner feedback. Fresh enrollment, Huarache control, animation uploads and worn-shoe behavior remain unvalidated.

## Install or update locally

Requires the installed Omarchy shell, Qt Quick Controls, Python and the enrollment spike's locked virtual environment. From the repository root:

```sh
cd spikes/002-local-enrollment
uv sync --locked
cd ../..
python apps/omarchy/install.py
```

The installer copies the original plugin into `~/.config/omarchy/plugins/io.github.gianlucaminoprio.openadapt`, creates `~/.local/bin/openadapt-session`, the older `openadapt-control` bridge and an OpenAdapt application entry, and places the widget immediately after `gianluk.agents` when present. Existing shell configuration and plugin files are backed up in `~/.config/openadapt/backups/`. Other widgets retain their placement.

The launcher points to this working copy and its virtual environment. Re-run the installer if the project moves. Disconnect the shoes and let any operation finish before updating. The installer requests a plugin rescan. This Omarchy build sometimes retains older QML in memory after a rescan; `omarchy restart shell` applies the copied version when that occurs.

An installation can import a prepared, verified local profile with `--profile /absolute/path/profiles.private.json` and optional `--state /absolute/path/state.json`. Imports require owner-only files and do not overwrite existing profile or state files. Missing profiles keep live controls unavailable.

Private storage:

- `~/.config/openadapt/profiles.private.json`: current credentials and calibration, mode 0600 inside a 0700 directory.
- `~/.local/state/openadapt/readings.json`: current per-pair readings. The original `state.json` is read as a migration source and retained. Connection state is never restored from either file.
- `~/.local/state/openadapt/backend.private.log`: private failure details. UI responses omit addresses, identifiers and keys.
- `~/.local/state/openadapt/sessions/`: bounded private protocol transcripts, owner-only.

Do not commit or share these files. The original phone profile and source credential evidence remain unchanged.

To open the panel from a terminal:

```sh
omarchy-shell io.github.gianlucaminoprio.openadapt open
```

To remove the widget, remove only its entry from the bar layout, then its installed plugin directory, launcher and desktop entry. Keep the private profile and backups unless their deletion is explicitly intended. Do not restore an old whole-shell backup over unrelated later customizations.

## Verification

```sh
cd spikes/002-local-enrollment
.venv/bin/python -m pytest -q tests ../../apps/omarchy/tests
cd ../..
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input apps/omarchy/tests/qml -o -,txt
omarchy plugin validate apps/omarchy/plugin
```

Recorded result: **337 Python tests passed; 14 Qt test results passed**. Coverage includes the existing authentication/control lifecycle, persistent connections beyond the handshake deadline, repeated reads across sequence-number wraparound, two explicit movements on one connection, idle movement notifications, disconnect/cancellation, command failure without replay, profile selection, multiple saved pairs and startup without radio access. Qt tests exercise slider behavior, empty-list button placement, selection routing and busy state. A separate real-process stdin/status/EOF check completed without radio access.

The installed panel successfully connected both owned Auto Max shoes. Private transcript review verified one existing-key handshake per shoe and reuse for further battery, color and owner-requested motor operations. No new key or bond was created. The new session traces replace the previous Preview-only verification as the latest app checkpoint.

The light codec independently matches **858 original-app messages** across seven recordings: 208 color requests/201 acknowledgements, 157 preview events/156 acknowledgements, and 68 stop requests/68 acknowledgements. These are envelope comparisons; unequal counts do not establish complete exchanges. This offline comparison is separate from the later live UI command acknowledgements and owner-visible LED confirmation.

## Source layout

- `plugin/`: native QML UI, saved-shoe list and theme-reactive sneaker drawing.
- `backend/openadapt_session.py`: persistent local controller and sanitized connection state.
- `backend/openadapt_app.py`: shared private-storage helpers and older one-shot bridge.
- `../../spikes/002-local-enrollment/live.py`: persistent authenticated sessions with explicit serialized controls.
- `../../spikes/002-local-enrollment/control.py`: existing-key status and motor operations.
- `../../spikes/002-local-enrollment/lights.py`: separate allowlisted base-color/preview and lights-off operations.

The original authentication-only path and offline enrollment CLI retain their earlier limits. The light path cannot issue motor, enrollment, reset, upload or firmware commands.

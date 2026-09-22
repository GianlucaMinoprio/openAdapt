# OpenAdapt for Omarchy

A native Quickshell panel for the owner's verified Auto Max pair. The side-profile sneaker sits beside the AI widget in the top-right bar. The bar icon follows the bar foreground; the panel sneaker, slider fills and selection accents follow `Color.accent`, the same theme role as the bar's open-panel underline. Omarchy theme changes update these bindings automatically.

The sneaker artwork is shared with the iPhone app: minimal laceless silhouette and two solid blue dots. See the [editable vector and asset-generation guide](../../assets/brand/README.md). The theme-aware mark preserves its proportions in rectangular containers; the green/accent version has white dots, while the bar’s white mark and desktop launcher keep blue dots.

At the owner's request, the installed Razer theme's blue accent was changed to the deeper green `#36ab23`. Both its source palette and active palette were updated, with the originals saved in `~/.config/openadapt/backups/`. This desktop customization is separate from the app installer; the plugin uses each theme's accent rather than hardcoding green.

## Controls

The compact panel has **Fit / Lights / Battery / Modes** tabs. Opening it selects the last fully connected pair but never starts Bluetooth discovery or authentication.

- **Fit:** the original rounded vertical bars, with a tick at every 5%. The chain-link icon sits vertically centered between the bars and is highlighted while linked. Link fit starts on: dragging either bar previews both shoes and releases one paired command. Turn it off for independent control. Battery information appears only in the Battery tab.
- **Progress:** the target marker follows input immediately. The stronger fill catches up over a 2.8-second estimate, stopping at 90% of the journey until completion and readback. A queued shoe does not animate before its own movement starts.
- **Tie / Untie:** Tie uses the last saved fit successfully applied to both shoes, or the first mode initially (Move 60/60). Untie requests 0/0 without replacing that remembered mode.
- **Lights:** twelve colors and Lights off, always targeting both shoes.
- **Battery:** read-only battery silhouettes with terminal caps, percentage and reading age. They have no fit ticks or drag handles. Refresh reads connected shoes only.
- **Modes:** save the current confirmed left/right fit, apply, rename and remove. Each pair starts with Move 60/60 and Chill 30/30; up to 20 modes with 40-character names are supported. These modes stay on this computer and are not included in credential exports.
- **Shoes:** opens Your shoes directly. The selector contains Connect, Disconnect and New shoes/import; no intermediate menu.

Mouse release commits once. Arrow keys and focused-wheel input debounce for 180 ms; Escape or leaving Fit cancels uncommitted changes. Closing the panel keeps existing shoe connections, but does not send unfinished input. Buttons, spacing, fonts and colors use the installed Omarchy shell's native controls and theme values.

The optional `reduceMotion: true` setting in this widget's `settings` object disables the animated movement estimate and settling. The selected target remains visible and the fill changes with confirmed readings. Native shell control feedback remains theme-owned.

The percentage is a target relative to each shoe's saved fit maximum, not a measurement of force. The controller maps it to a raw position with explicit nearest-integer rounding. Exact Nike iPhone display rounding remains unresolved.

## Saved shoes and live connections

Opening the panel shows Fit for the last pair that completed authentication and status reads on **both** shoes. Before any such connection, the first saved pair is the default. Temporary selection and failed/partial attempts do not change the remembered pair. Existing live connections are preserved when reopening. **Shoes** selects an alternative pair, and **New shoes** imports a completed iPhone pairing; it does not reset or enroll shoes.

**Connect** shares one fresh Bluetooth scan, then connects and authenticates both shoes concurrently. It makes one bounded attempt per shoe and retains an already authenticated partner when retrying. A partial connection keeps individual controls available with Link fit off, while paired fit and light actions require both shoes. **Disconnect** in Your shoes releases both links concurrently. No automatic reconnect or command replay is implemented.

Cached readings never restore connection state. Freshly imported pairs with unknown fit calibration can use battery/lights after connecting, but cannot issue fit commands. Existing calibration, charging, battery and fit-limit checks remain in force.

The native shell owns a local process with JSON-line stdin/stdout. It keeps credentials private and accepts one user action at a time. Within that action, Tie, Untie, linked fit, modes, lights and battery reads run concurrently across the shoes. Each shoe retains its own ordered protocol channel and safety checks. A failed side does not discard the other side's confirmed result; the panel waits for both outcomes and reports partial completion. Cancellation drains both tasks before another action is accepted. Closing the shell or its input runs the same disconnect cleanup. The older one-shot command bridge is excluded by the shared operation lock while the new backend runs.

**September 15 live checkpoint:** the owner requested real connections, confirmed both shoes awake and Nike Adapt closed, and then operated the UI. Both shoes authenticated and remained connected; two further battery refreshes reused the same sessions. Trace review also found five owner-operated color changes per shoe and one left motor target in those sessions, with one handshake per shoe. The owner subsequently selected Disconnect and the UI returned to the saved-pair list. No agent motor or LED command was sent during this connection check. Physical color appearance and perceived response time await owner feedback. Fresh enrollment, Huarache control, animation uploads and worn-shoe behavior remain unvalidated.

## Install or update locally

Requires the installed Omarchy shell, Qt Quick Controls and Dialogs, Python and the enrollment spike's locked virtual environment. From the repository root:

```sh
cd spikes/002-local-enrollment
uv sync --locked
cd ../..
python apps/omarchy/install.py
```

The installer copies the original plugin into `~/.config/omarchy/plugins/io.github.gianlucaminoprio.openadapt`, creates `~/.local/bin/openadapt-session`, the older `openadapt-control` bridge and an OpenAdapt application entry, and places the widget immediately after `gianluk.agents` when present. Existing shell configuration and plugin files are backed up in `~/.config/openadapt/backups/`. Other widgets retain their placement.

The launcher points to this working copy and its virtual environment. Re-run the installer if the project moves. Disconnect the shoes and let any operation finish before updating. The installer requests a plugin rescan. This Omarchy build sometimes retains older QML in memory after a rescan; `omarchy restart shell` applies the copied version when that occurs.

An installation can import a prepared, verified local profile with `--profile /absolute/path/profiles.private.json` and optional `--state /absolute/path/state.json`. Imports require owner-only files and do not overwrite existing profile or state files. Missing profiles keep live controls unavailable.

### Import a pairing from iPhone

After saving both shoes on iPhone, use **Settings → Developer mode → Your shoes → Export pairing file**. Transfer it privately, then use Omarchy's **New shoes → Import pairing file** with shoe sessions disconnected. Import keeps other pairs and backs up an existing entry before updating it. It never connects or enrolls automatically. Native iPhone profiles use advertised shoe identities to discover Linux devices; a local Bluetooth bond is still required. New pairs have unknown calibration, so percentage lacing remains disabled while battery/lights can work after authentication. See [pairing transfer](../../docs/ios/PAIRING-TRANSFER.md) for validation limits.

Private storage:

- `~/.config/openadapt/profiles.private.json`: current credentials and calibration, mode 0600 inside a 0700 directory.
- `~/.local/state/openadapt/readings.json`: current per-pair readings. The original `state.json` is read as a migration source and retained. Connection state is never restored from either file.
- `~/.local/state/openadapt/panel-preferences.json`: preferred pair and per-pair saved modes; separate from credentials.
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
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner \
  -import apps/omarchy/tests/qml/imports -input apps/omarchy/tests/qml -o -,txt
omarchy plugin validate apps/omarchy/plugin
```

The September 22 concurrent-pair revision passes **410 Python tests**. These include overlapping connections/controls, independent protocol frames, partial results, cancellation and shared-scan cleanup. UI checks and native verification are recorded in [panel polish](../../docs/omarchy/PANEL-POLISH.md). The QtTest imports are explicitly test-only adapters: standalone QtTest cannot load Quickshell’s statically linked plugin. The actual shell supplies the production controls.

The earlier V0 checkpoint passed 337 Python tests and 14 Qt results. Coverage includes the existing authentication/control lifecycle, persistent connections beyond the handshake deadline, repeated reads across sequence-number wraparound, two explicit movements on one connection, idle movement notifications, disconnect/cancellation, command failure without replay, profile selection, multiple saved pairs and startup without radio access. Qt tests exercise slider behavior, empty-list button placement, selection routing and busy state. A separate real-process stdin/status/EOF check completed without radio access.

The installed panel successfully connected both owned Auto Max shoes. Private transcript review verified one existing-key handshake per shoe and reuse for further battery, color and owner-requested motor operations. No new key or bond was created. The new session traces replace the previous Preview-only verification as the latest app checkpoint.

The light codec independently matches **858 original-app messages** across seven recordings: 208 color requests/201 acknowledgements, 157 preview events/156 acknowledgements, and 68 stop requests/68 acknowledgements. These are envelope comparisons; unequal counts do not establish complete exchanges. This offline comparison is separate from the later live UI command acknowledgements and owner-visible LED confirmation.

## Source layout

- `plugin/`: native QML UI, saved-shoe list and theme-reactive sneaker drawing.
- `backend/openadapt_session.py`: persistent local controller and sanitized connection state.
- `backend/panel_preferences.py`: local saved modes and successful-pair history.
- `backend/openadapt_app.py`: shared private-storage helpers and older one-shot bridge.
- `../../spikes/002-local-enrollment/live.py`: persistent authenticated sessions, ordered independently within each shoe.
- `../../spikes/002-local-enrollment/ble_link.py`: one shared discovery scan and independent authenticated connections.
- `../../spikes/002-local-enrollment/control.py`: existing-key status and motor operations.
- `../../spikes/002-local-enrollment/lights.py`: separate allowlisted base-color/preview and lights-off operations.

The original authentication-only path and offline enrollment CLI retain their earlier limits. The light path cannot issue motor, enrollment, reset, upload or firmware commands.

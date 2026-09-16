# Siri & Shortcuts

OpenAdapt provides nine native App Intents and App Shortcuts. They operate on the pair currently selected in the app; that selection persists across launches. They run without bringing OpenAdapt onscreen. Local device authentication is still required: unlock the iPhone when Siri asks. Keys retain their existing when-unlocked, device-only Keychain protection. First connect each requested shoe in the app so its authenticated CoreBluetooth identifier is remembered.

## Everyday voice control

The two primary actions are **Tie Shoes** and **Loosen Shoes**. Tie Shoes has no parameters: it applies the last saved mode successfully used on both shoes, including distinct left/right values. Until a mode has been applied, it uses the first saved fit—Move at 60% left / 60% right with the default mode list. Loosen Shoes defaults to both shoes at zero and leaves that remembered mode intact. After confirmed completion, Siri gives a short response: “Your shoes are tied” or “Your shoes are loosened.” Errors and partial completion remain explicit.

### One-time setup for the shortest phrases

1. Tie Shoes starts with your first saved fit, normally **Move · 60% / 60%**. The active tie fit is labeled **Used by Tie Shoes** in Modes. Applying another saved mode changes the fit used next time; no initial mode application is required.
2. In **OpenAdapt → Settings → Siri & Shortcuts → Say “Tie my shoes”**, tap **Add “Tie my shoes”**, then confirm **Add Shortcut** on Apple's screen. This installs a single action bound to this OpenAdapt app. It does not run it during setup.
3. Return to OpenAdapt and repeat with **Add “Untie my shoes”**. It uses **Loosen Shoes → Both shoes**, without asking which shoe each time.
4. Say **“Siri, tie my shoes”** or **“Siri, untie my shoes.”** No app name, mode choice, percentage, or separate Connect step is needed after initial setup. The shoes must be awake and nearby; unlock the iPhone if Siri asks.

The Add buttons require bundle-specific signed shortcut resources. For builds without them, the guide includes manual setup: create a shortcut in Apple Shortcuts, search for OpenAdapt, add **Tie Shoes**, and rename it **Tie my shoes**. Repeat with **Loosen Shoes → Both shoes**, named **Untie my shoes**. **Loosen my shoes** is also a suitable personal-shortcut name. Distributors can generate the resources using [the signing script](../../apps/ios/Config/SiriShortcuts/README.md).

Apple runs personal shortcuts by their saved names. App-provided activation phrases must include the app name, so OpenAdapt cannot automatically claim a bare “Tie my shoes” phrase. The short names need this one-time setup in Shortcuts. See [Apple’s Siri shortcut guide](https://support.apple.com/guide/shortcuts/run-shortcuts-with-siri-apd07c25bb38/ios) and [App Shortcut phrase requirements](https://developer.apple.com/videos/play/wwdc2022/10170/).

### If Siri answers about losing your shoes

A reply about losing or misplacing shoes suggests Siri interpreted “loose” as “lose” and gave a general answer rather than matching a shortcut. It does not establish an OpenAdapt or Bluetooth failure.

- First try **“Siri, untie my shoes with OpenAdapt.”** That complete phrase is registered by the app. **“Siri, loosen my shoes with OpenAdapt”** is also registered.
- To leave out OpenAdapt, create a personal shortcut with **Loosen Shoes → Both shoes**, named **Untie my shoes**, then say **“Siri, untie my shoes.”** Use the saved name directly while diagnosing recognition; arbitrary conversational variations are not guaranteed.
- The app also declares **“Can you untie my shoes with OpenAdapt,” “Can you loosen my shoes with OpenAdapt,”** and **“Can you tie my shoes with OpenAdapt.”** These still include the app name. Adding app phrases cannot create personal shortcuts or guarantee Siri's voice routing.
- If Siri still gives a general answer to the complete phrase, verify that the OpenAdapt actions appear in Shortcuts. On-device phrase recognition needs a separate check; compiled metadata only verifies that the app supplies the phrases.

### If Siri describes an unrelated OpenAdapt project

The owner supplied a screenshot of Siri answering “Can you tie my shoes with OpenAdapt” with a web response about an unrelated desktop AI project. That phrase was already registered; adding it again cannot guarantee routing. The ready-made personal shortcut explicitly references this installed app's Tie Shoes action. Apple still controls voice recognition, so verify the saved shortcut name on the iPhone.

The app also registers **“Lace my shoes with OpenAdapt”** and the owner's requested **“Make my lace with OpenAdapt.”** Both invoke the same saved-fit action. They do not change the selected fit or require another parameter.

### Remembered fit

- A mode becomes the remembered fit only when both shoes confirm its application, through Modes or Apply Shoe Mode. Failed, canceled, or partial applications preserve the previous mode.
- The mode identity persists across launches and is separate for each saved pair. Its current values are resolved when Tie Shoes runs.
- Loosening, direct percentage commands, and dragging the controls do not replace the last saved mode.
- If no remembered mode is available, Tie Shoes uses the first saved mode in the current list. It only asks for a saved fit when the list is empty. Removing a pair clears its history; deleting a mode cannot replay its stale percentages.
- This release starts recording that history when installed; an older build’s unrecorded mode cannot be reconstructed, so the first saved mode supplies the initial default.

## Built-in Siri phrases

- “Tie my shoes with OpenAdapt.” Uses the last confirmed saved mode, or the first saved fit initially, without a follow-up question. Aliases include “Lace up my shoes with OpenAdapt,” “Lace my shoes with OpenAdapt,” and “Make my lace with OpenAdapt.”

- “Set my shoe fit with OpenAdapt.” Siri asks for the percentage.
- “Loosen my shoes with OpenAdapt.” Requests zero percent fit. “Untie my shoes with OpenAdapt” is an alias.
- “Apply Chill with OpenAdapt.” Uses the saved mode’s current values.
- “Set my shoe lights to blue with OpenAdapt.”
- “Turn my shoe lights off with OpenAdapt.”
- “Check my shoe battery with OpenAdapt.” Reads the shoes now.
- “Connect my shoes with OpenAdapt.”
- “Disconnect my shoes with OpenAdapt.” Preserves the saved pair.

These are the app’s declared English trigger phrases. On-device recognition, Siri permissions and indexing still need hands-on verification. Find the actions in **Shortcuts → App Shortcuts → OpenAdapt** or through **OpenAdapt → Settings → Siri & Shortcuts**. Shortcuts can specify left, right, or both shoes for fit, loosen, lights, connection and battery. Saved modes always apply their two stored percentages. A custom shortcut can have a shorter name and combine these actions with other apps.

## Behavior

- First connect each shoe in OpenAdapt once. Later shortcuts retrieve the authenticated CoreBluetooth identifiers directly, without a discovery scan. If iOS no longer knows the identifier, reconnect that shoe in the app.
- All nine actions stay offscreen. Active actions use a finite UIKit background task and the `bluetooth-central` background mode. OpenAdapt caps each request at 25 seconds; iOS may end its execution window sooner. Cancellation or expiration closes pending connections and rejects late results. No deferred action is saved or replayed.
- Ordinary background actions release temporary connections after completion. An explicit **Connect Shoes** retains idle Bluetooth connections until Disconnect, radio loss, or system termination. No indefinitely running CPU task or restoration queue is used.
- Opening OpenAdapt automatically reconnects the last selected pair. It tries saved identifiers first, then performs a foreground search if one is missing or unreachable. When both shoes share an advertised name, discovery requires the remembered identifier for each side; it never substitutes the first same-named shoe. My shoes → Connect individually can establish each identity again. A 20-second limit ends an unsuccessful attempt; the L/R controls remain disabled until each shoe is authenticated. Cancel stops the attempt. This foreground search also establishes the first iPhone connection for an existing-key profile. Background Siri actions still require those remembered identifiers and do not discover unbound shoes.
- Fit accepts 0–100 percent and rounds to the UI’s 5-percent steps. Both requested shoes pass current battery, charger and calibration checks before either motor starts. Each shoe then uses the existing authenticated `ShoeSession.setFit` implementation, which repeats its preflight and requires protocol completion plus readback.
- Both-shoe commands may partially complete if a link fails after execution starts. Siri reports which shoe confirmed and which failed. It never reports overall success or automatically retries.
- Lights use the existing acknowledged base-color commands; lights off sends zero RGB without preview.
- Battery returns fresh readings as spoken text and a Shortcuts string output. Cached battery values are not returned as fresh measurements.
- Only one shortcut runs at a time; controls cannot issue a competing command. The interface displays a cancelable running indicator.
- Mode entities contain names and percentages, never shoe addresses or keys. Execution re-resolves the mode so deleted modes, changed pairs and stale cached percentages cannot trigger an old fit.
- Default mode identifiers are stable across app launches. Editing the mode list refreshes shortcut parameters.
- The demo cannot execute these actions. Tests use a separate in-memory controller and synthetic protocol data, never real shoes.

## Implementation and verification

- `OpenAdapt/Intents/ShoeIntents.swift`: nine action types, shoe/color enums, current-pair mode entities, Siri phrases.
- `Sources/OpenAdaptCore/SavedFitHistory.swift`: per-pair remembered mode IDs, confirmed-both-shoes recording, persistence and deleted-mode handling. Seven tests cover these rules.
- `Sources/OpenAdaptCore/ShoeShortcuts.swift`: awaitable command orchestration and explicit partial results.
- `OpenAdapt/AppStore.swift`: shared UI/intent instance, direct remembered-peripheral reconnection, authenticated session adapter and cleanup.
- `Sources/OpenAdaptCore/ShortcutExecution.swift`: one-action reservation, 25-second deadline, system/caller cancellation and rejection of late success.
- `OpenAdapt/Intents/ShortcutBackgroundLease.swift`: finite UIKit background execution assertion.
- Ten additional core tests cover range validation, both-shoe preflight, partial completion without retry, setup failure, stale context, cancellation, fresh side-specific battery, side-specific lights, and waiting for completion. Six execution tests additionally cover deadline expiry, system expiry, cleanup, overlap, caller cancellation and already-canceled requests. The core suite totals 47 tests.
- Xcode successfully extracted nine actions, nine App Shortcuts, the two parameter enums, the saved-mode entity, background execution (`openAppWhenRun = false`, `.background`) and local authentication policies.
- The owner reports that Siri can untie the shoes, while a tying attempt did not work. The exact tie phrase and Siri response are needed to distinguish routing from execution failure; other voice actions are not yet validated. No motor or light commands were sent by the development tools during this diagnosis.

Apple references: [App Intent](https://developer.apple.com/documentation/appintents/appintent), [App Shortcuts provider](https://developer.apple.com/documentation/appintents/appshortcutsprovider), [execution modes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes), [local device authentication](https://developer.apple.com/documentation/appintents/intentauthenticationpolicy/requireslocaldeviceauthentication). The implementation retains `openAppWhenRun` for iOS 17–25 and declares `.background` execution on iOS 26 and later.

Bluetooth and lifecycle references: [Apple background Bluetooth guide](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html), [retrieve known peripherals](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/retrieveperipherals(withidentifiers:)), [finite background execution](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time).

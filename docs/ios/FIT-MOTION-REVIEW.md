# Fit animation review

Reference: the owner's recording at 0:15–0:20. Selection follows the finger; after release the selected level holds while a separate lacing marker moves toward it. The owner requested one additional second for the estimate and removal of its caption.

| Before | After | Why |
| --- | --- | --- |
| One bar stayed at the measured position during the drag. | A target bar follows the letter directly, then holds the selected level; a separate solid bar catches up. | Makes the requested fit and shoe movement distinct. `apps/ios/OpenAdapt/Views/FitControlView.swift:29` |
| 1.8-second estimate. | 2.8-second linear estimate, with a short final settle after confirmation. | Applies the owner's timing request to motor feedback while preserving immediate drag response. `apps/ios/OpenAdapt/Views/FitControlView.swift:67` |
| “LACING / ESTIMATED PROGRESS” appeared below the controls. | The caption stays hidden during movement; the layout stays stable. | The bars convey the action without additional text. `apps/ios/OpenAdapt/Views/RootView.swift:71` |
| Idle-position notifications could replace a target during lacing. | Target updates from those notifications are suppressed while lacing. | Keeps the selected level fixed until completion. `apps/ios/OpenAdapt/AppStore.swift:271` |

## Verdict

### Interruptibility and timing

Drag movement has no interpolation. Release uses the existing 200 ms strong ease-out (`0.23, 1, 0.32, 1`) for snapping to the 5% grid; the 2.8-second motion represents estimated physical movement rather than a delayed UI response. Upward, downward, independent and linked adjustments share the same model. A result must still be confirmed before progress reaches the destination; the estimate waits at 90% if needed.

### Performance

Only the small progress marker uses a timeline; there are no per-frame store writes. Bars move through offsets, with fixed dimensions. No additional library or animation loop is introduced.

### Accessibility

Reduced Motion pauses interpolated motor progress and suppresses the settle transition. The adjustable controls still announce their requested value and lacing state. The hidden caption is also hidden from accessibility.

**Approve** for the changed motion: drag feedback remains immediate, the requested slower estimate has a physical purpose, layout stays fixed, and reduced motion is preserved. Simulator verification and physical-device installation are recorded in [VERIFICATION.md](VERIFICATION.md); real motor timing is still unmeasured.

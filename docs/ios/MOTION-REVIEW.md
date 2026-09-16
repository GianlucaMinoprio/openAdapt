# Native motion review

September 15, 2026. Reviewed the SwiftUI/UIKit implementation using `review-animations` and its `STANDARDS.md`, supported by the animation, Apple design, design foundations, touch/accessibility, and UI polish skills. Web-specific implementation rules were translated to native transforms, SwiftUI transactions, and system components. No animation library was added.

## Findings

| Before | After | Why |
| --- | --- | --- |
| Dragged letters moved only when the requested percentage crossed a 5% step. | Continuous finger position drives each letter; only the requested fit and haptic ticks snap to 5%. `apps/ios/OpenAdapt/Views/FitControlView.swift:17` | Direct manipulation should remain attached to the finger. No easing runs during the drag. |
| Target changes used a 350 ms spring on changing layout positions. | A fixed origin plus a vertical transform, with a 200 ms strong ease-out settle. `apps/ios/OpenAdapt/Views/FitControlView.swift:36` | Avoid animating layout and overshooting a physical fit target. The curve is `(0.23, 1, 0.32, 1)` from the review standards; duration is below the 300 ms UI ceiling. |
| The app published progress changes every 30 ms, invalidating the whole controller. | Only the side marker reads a local animation timeline. `apps/ios/OpenAdapt/Views/FitControlView.swift:52` | Confine per-frame updates to the changing element. The 1.8-second motion is explicitly an estimate of a motor operation and remains capped at 90% pending actual completion/readback. |
| Custom toolbar and color buttons had no shared tactile press response. | Scale to 0.97 during touch, 160 ms press / 100 ms release, using the shared strong ease-out curve. `apps/ios/OpenAdapt/Views/Motion.swift:19` | Feedback acknowledges the touch; the system response is faster than the deliberate press. SwiftUI retargets the current transition when released early. |
| Reduced Motion omitted the letter spring but still advanced the progress marker continuously. | Disable positional settling, press scaling, and continuous marker motion. Retain brief opacity feedback and the actual final position. `apps/ios/OpenAdapt/Views/FitControlView.swift:58`, `apps/ios/OpenAdapt/Views/Motion.swift:20` | Preserve comprehensible state feedback without unnecessary movement. Accessibility adjustments also bypass target animation. |
| The disconnected controller exposed irrelevant fit values and inactive actions. | Subdued L/R letters, a fixed-height connection area, cancellation, and no hidden dock controls in the accessibility tree. `apps/ios/OpenAdapt/Views/RootView.swift:55` | The connection state is legible without a whole-screen entrance, moving placeholders, or inaccessible hidden controls. |

## Verdict

### Performance

Letter motion uses an offset from a fixed position. The two markers use local timelines only while lacing; idle and reduced-motion timelines pause. Shadow animation and broad per-frame store mutations were removed. Native sheets retain their system transitions. No device frame-rate claim is made from source inspection alone.

### Interruptibility & timing

The press response is asymmetric and retargetable. Direct dragging is immediate, while release settles in 200 ms. The motor estimate is the justified long-running exception: it represents an operation, remains visibly labeled as estimated, and stops on completion, error, disconnect, or backgrounding. There is no momentum projection that could tighten a shoe past the released value.

### Accessibility

Reduced-motion behavior is part of the implementation, with a Debug test override for exercising that path. Independent fit elements retain VoiceOver adjustment and disabled states. Hidden disconnected controls are removed from the view hierarchy. Dynamic labels use stable numeric widths; setup and help remain native scrolling screens.

### Deliberately omitted motion

- No bouncing or pulsing disconnected letters: an indefinite wait does not justify a large looping animation.
- No staggered toolbar entrance: these daily controls should become available together.
- No inertial overshoot or elastic fit values: the number is a physical shoe command, so predictable bounds win.
- No logo entrance on every launch: it conveys no state change.

**Approve — native UI motion implementation.** No remaining feel-breaking code findings in the reviewed motion. Simulator interaction checks and screenshot review support the UI result; physical-device haptic feel, simultaneous fingers, Bluetooth timing, and motor duration remain to be validated on the owner’s iPhone and shoes.

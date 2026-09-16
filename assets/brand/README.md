# OpenAdapt sneaker

The shared original mark has a minimal laceless silhouette and two solid blue dots inspired by the owner’s shoe reference. The upper follows the surrounding ink color: black on white, white on dark surfaces, or Omarchy’s theme accent. The two dots are blue on the black and white versions, and white on Omarchy’s green/accent version.

`sneaker.svg` is the editable source, licensed under the repository’s MIT license. Its 128-unit view box includes the same optical spacing on both platforms. The layered paths use absolute `M`, `L`, `C`, and `Z` commands. The silhouette is one closed shape; a second path contains the two blue dots.

Regenerate the checked-in platform assets on macOS from the repository root:

```sh
swift apps/ios/scripts/make-icon.swift
```

This produces:

- The opaque 1024 px iOS app icon, black with blue lamps on white.
- Separate vector PDFs for the tintable silhouette and original-color lamps, composed by `SneakerMark` in iOS toolbars, sheets, and onboarding.
- Omarchy’s `ShoeMark.qml`, preserving its `ink` binding and aspect ratio, with a separate `lampInk` binding for the dots.
- Omarchy’s desktop launcher SVG, black with blue lamps on white.

The checked-in assets let either app build without running the generator. `preview.png` shows the rendered QML mark at app-icon size and at 24, 32 and 64 px in two theme colors, including a rectangular container to check aspect ratio.
